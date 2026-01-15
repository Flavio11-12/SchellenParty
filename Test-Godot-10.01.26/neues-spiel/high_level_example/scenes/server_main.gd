extends Node
class_name ServerMain

# ========= Server Config =========
const PORT: int = 42069
const WORDLIST_PATH: String = "res://high_level_example/scenes/wortliste.txt"

# ========= Game State (authoritative) =========
var valid_words: PackedStringArray = PackedStringArray()
var used_words: Dictionary = {} # used_words[word] = true

var players: Array[int] = []
var names: Dictionary = {} # peer_id -> username
var current_turn_index: int = 0
var current_player_id: int = 0
var game_started: bool = false

# ========= Networking =========
var peer: WebSocketMultiplayerPeer
var sm: SceneMultiplayer



func _ready() -> void:
	print("[Server] Booting…")
	_load_wordlist()
	_start_server()

	# Multiplayer signals (join/leave)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	print("[Server] Ready. Listening on port %d" % PORT)


func _start_server() -> void:
	peer = WebSocketMultiplayerPeer.new()

	var err: int = peer.create_server(PORT)
	if err != OK:
		push_error("[Server] Failed to start WebSocket server. Error=%s" % str(err))
		return

	sm = SceneMultiplayer.new()
	sm.multiplayer_peer = peer
	get_tree().set_multiplayer(sm)


func _load_wordlist() -> void:
	valid_words = PackedStringArray()
	used_words.clear()

	var f: FileAccess = FileAccess.open(WORDLIST_PATH, FileAccess.READ)
	if f == null:
		push_error("[Server] Wordlist not found: %s" % WORDLIST_PATH)
		return

	while not f.eof_reached():
		var w: String = f.get_line().strip_edges().to_lower()
		if w != "":
			valid_words.append(w)

	f.close()
	print("[Server] Loaded words: %d" % valid_words.size())


# ---------------------------
# Peer connect/disconnect
# ---------------------------
func _on_peer_connected(id: int) -> void:
	print("[Server] Peer connected:", id)
	# Spieler wird erst "richtig" aufgenommen, wenn er register_player_rpc aufruft.


func _on_peer_disconnected(id: int) -> void:
	print("[Server] Peer disconnected:", id)

	# remove from lists
	names.erase(id)

	var idx: int = players.find(id)
	if idx != -1:
		players.remove_at(idx)

	# Turn korrigieren, falls nötig
	if players.is_empty():
		current_turn_index = 0
		current_player_id = 0
		game_started = false
		rpc("state_sync_rpc", _make_public_state())
		return

	# Wenn der aktuelle Spieler raus ist, turn weitergeben
	if id == current_player_id:
		if current_turn_index >= players.size():
			current_turn_index = 0
		current_player_id = players[current_turn_index]
		rpc("sync_turn_rpc", current_player_id)

	# Alle updaten
	rpc("state_sync_rpc", _make_public_state())


# ---------------------------
# Public State helper
# ---------------------------
func _make_public_state() -> Dictionary:
	# used_words als Array exportieren (Dictionary ist als Set intern)
	var used_arr: Array[String] = []
	used_arr.resize(used_words.size())

	var i: int = 0
	for k in used_words.keys():
		used_arr[i] = str(k)
		i += 1

	# players + names
	var name_map: Dictionary = {}
	for pid: int in players:
		name_map[pid] = names.get(pid, "Player %d" % pid)

	return {
		"players": players.duplicate(),
		"names": name_map,
		"current_player_id": current_player_id,
		"game_started": game_started,
		"used_words": used_arr,
		"word_count": used_arr.size()
	}


# ============================================================
# RPC API (Clients call these; Server is authoritative)
# ============================================================

# Client calls this immediately after connected
@rpc("any_peer")
func register_player_rpc(username: String) -> void:
	if not multiplayer.is_server():
		return

	var sender: int = multiplayer.get_remote_sender_id()
	var clean_name: String = username.strip_edges()
	if clean_name == "":
		clean_name = "Player %d" % sender

	if players.has(sender) == false:
		players.append(sender)
	names[sender] = clean_name

	print("[Server] Registered:", sender, clean_name)
	rpc("state_sync_rpc", _make_public_state())

	# Wenn Spiel noch nicht gestartet, setze "current player" auf ersten Spieler
	if not game_started and players.size() >= 1 and current_player_id == 0:
		current_turn_index = 0
		current_player_id = players[0]
		rpc("sync_turn_rpc", current_player_id)


# Optional: simple chat relay (authoritative relay)
@rpc("any_peer")
func send_chat_rpc(message: String) -> void:
	if not multiplayer.is_server():
		return

	var sender: int = multiplayer.get_remote_sender_id()
	var msg: String = message.strip_edges()
	if msg == "":
		return

	var uname: String = str(names.get(sender, "Player %d" % sender))
	rpc("chat_broadcast_rpc", uname, msg)


# Start game (host / any player) - you can restrict if you want
@rpc("any_peer")
func start_game_rpc() -> void:
	if not multiplayer.is_server():
		return

	if players.size() < 1:
		return

	game_started = true
	current_turn_index = 0
	current_player_id = players[0]

	print("[Server] Game started. First player:", current_player_id)
	rpc("state_sync_rpc", _make_public_state())
	rpc("sync_turn_rpc", current_player_id)


# Client submits a word; server validates
@rpc("any_peer")
func submit_word_rpc(word: String) -> void:
	if not multiplayer.is_server():
		return

	if not game_started:
		var s: int = multiplayer.get_remote_sender_id()
		rpc_id(s, "word_result_rpc", false, word, "Spiel hat noch nicht gestartet.")
		return

	var sender: int = multiplayer.get_remote_sender_id()
	var w: String = word.strip_edges().to_lower()

	if sender != current_player_id:
		rpc_id(sender, "word_result_rpc", false, w, "Nicht dein Zug.")
		return

	if w == "":
		rpc_id(sender, "word_result_rpc", false, w, "Bitte ein Wort eingeben.")
		return

	if valid_words.is_empty():
		rpc_id(sender, "word_result_rpc", false, w, "Wortliste nicht geladen (Server).")
		return

	if used_words.has(w):
		rpc_id(sender, "word_result_rpc", false, w, "Schon benutzt.")
		return

	# Validierung
	if not valid_words.has(w):
		rpc_id(sender, "word_result_rpc", false, w, "Nicht in der Liste.")
		return

	# akzeptiert
	used_words[w] = true

	# Informiere alle Clients, dass Wort akzeptiert wurde
	var uname: String = str(names.get(sender, "Player %d" % sender))
	rpc("word_accepted_rpc", w, sender, uname)

	# Turn weitergeben
	_advance_turn()

	# optional: state sync, falls du komplett deterministisch halten willst
	# rpc("state_sync_rpc", _make_public_state())


# ============================================================
# Turn logic (server-only)
# ============================================================
func _advance_turn() -> void:
	if players.is_empty():
		current_turn_index = 0
		current_player_id = 0
		game_started = false
		rpc("state_sync_rpc", _make_public_state())
		return

	current_turn_index = (current_turn_index + 1) % players.size()
	current_player_id = players[current_turn_index]

	print("[Server] Next turn:", current_player_id)
	rpc("sync_turn_rpc", current_player_id)


# ============================================================
# RPCs the server sends to clients (clients implement these)
# (We still declare them here so you see the contract.)
# ============================================================

@rpc("authority", "call_remote")
func state_sync_rpc(state: Dictionary) -> void:
	# Implement on client
	pass


@rpc("authority", "call_remote")
func sync_turn_rpc(active_player_id: int) -> void:
	# Implement on client
	pass


@rpc("authority", "call_remote")
func word_accepted_rpc(word: String, by_peer_id: int, by_name: String) -> void:
	# Implement on client
	pass


@rpc("authority", "call_remote")
func word_result_rpc(ok: bool, word: String, reason: String) -> void:
	# Implement on client (rejections / feedback for sender)
	pass


@rpc("authority", "call_remote")
func chat_broadcast_rpc(username: String, message: String) -> void:
	# Implement on client
	pass
