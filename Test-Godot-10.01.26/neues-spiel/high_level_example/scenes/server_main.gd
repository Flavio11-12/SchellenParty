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
var scores: Dictionary = {} # peer_id -> Punkte
const WIN_SCORE: int = 15

# Silben für die Runde
var silben: Array[String] = [
	"ab", "an", "ar", "be", "bi", "da", "di", "do",
	"el", "en", "er", "ge", "ha", "he", "hi", "ho",
	"im", "in", "ka", "ko", "la", "le", "li", "lo",
	"ma", "me", "mi", "mo", "na", "ne", "ni", "no",
	"ob", "or", "pa", "pe", "pi", "po", "ra", "re",
	"ri", "ro", "sa", "se", "si", "so", "ta", "te",
	"ti", "to", "ul", "un", "ur", "va", "ve", "vi",
	"vo", "wa", "we", "wi", "wo", "za", "ze", "zi"
]
var current_syllable: String = ""

# ========= Networking =========
var peer: WebSocketMultiplayerPeer
var sm: SceneMultiplayer

# ========= Turn Timer =========
const TURN_TIME: float = 15.0
var turn_timer: Timer


func _ready() -> void:
	print("[Server] Booting…")
	_load_wordlist()
	_start_server()

	# Timer initialisieren
	turn_timer = Timer.new()
	turn_timer.one_shot = true
	turn_timer.wait_time = TURN_TIME
	turn_timer.timeout.connect(_on_turn_timeout)
	add_child(turn_timer)

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


func _on_peer_disconnected(id: int) -> void:
	print("[Server] Peer disconnected:", id)

	names.erase(id)
	scores.erase(id)

	var idx: int = players.find(id)
	if idx != -1:
		players.remove_at(idx)

	if players.is_empty():
		current_turn_index = 0
		current_player_id = 0
		game_started = false
		rpc("state_sync_rpc", _make_public_state())
		return

	if id == current_player_id:
		if current_turn_index >= players.size():
			current_turn_index = 0
		current_player_id = players[current_turn_index]
		rpc("sync_turn_rpc", current_player_id)

	rpc("state_sync_rpc", _make_public_state())


# ---------------------------
# Public State helper
# ---------------------------
func _make_public_state() -> Dictionary:
	var used_arr: Array[String] = []
	for k in used_words.keys():
		used_arr.append(str(k))

	var name_map: Dictionary[int, String] = {}
	for pid: int in players:
		name_map[pid] = names.get(pid, "Player %d" % pid)

	return {
		"players": players.duplicate(),
		"names": name_map,
		"current_player_id": current_player_id,
		"game_started": game_started,
		"used_words": used_arr,
		"word_count": used_arr.size(),
		"scores": scores.duplicate(),
		"current_syllable": current_syllable
	}


# ============================================================
# RPC API (Clients call these; Server is authoritative)
# ============================================================

@rpc("any_peer")
func register_player_rpc(username: String) -> void:
	if not multiplayer.is_server():
		return

	var sender: int = multiplayer.get_remote_sender_id()
	var clean_name: String = username.strip_edges()
	if clean_name == "":
		clean_name = "Player %d" % sender

	if not players.has(sender):
		players.append(sender)
		scores[sender] = 0

	names[sender] = clean_name

	print("[Server] Registered:", sender, clean_name)
	rpc("state_sync_rpc", _make_public_state())

	if not game_started and players.size() >= 1 and current_player_id == 0:
		current_turn_index = 0
		current_player_id = players[0]
		_start_turn()


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


@rpc("any_peer")
func start_game_rpc() -> void:
	if not multiplayer.is_server():
		return

	if players.is_empty():
		return

	game_started = true
	current_player_id = players[0]
	current_turn_index = 0
	_start_turn()
	_next_syllable()

	print("[Server] Game started. First player:", current_player_id)
	rpc("state_sync_rpc", _make_public_state())
	rpc("sync_turn_rpc", current_player_id)


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

	if not valid_words.has(w):
		rpc_id(sender, "word_result_rpc", false, w, "Nicht in der Liste.")
		return

	# Silbe prüfen
	if not w.contains(current_syllable):
		rpc_id(sender, "word_result_rpc", false, w, "Wort enthält nicht die Silbe '%s'!" % current_syllable)
		return

	# akzeptiert
	used_words[w] = true
	turn_timer.stop()
	scores[sender] = scores.get(sender, 0) + 1

	# Sieg prüfen
	if scores[sender] >= WIN_SCORE:
		game_started = false
		var winner_name: String = str(names.get(sender, "Player %d" % sender))
		rpc("game_over_rpc", sender, winner_name, scores.duplicate())
		return

	var uname: String = str(names.get(sender, "Player %d" % sender))
	rpc("word_accepted_rpc", w, sender, uname)
	rpc("state_sync_rpc", _make_public_state())

	# neue Silbe für nächsten Spieler
	_next_syllable()
	_advance_turn()


# ============================================================
# Turn logic (server-only)
# ============================================================
func _start_turn() -> void:
	if current_player_id == 0:
		return

	print("[Server] ▶ Turn für Spieler", current_player_id)
	turn_timer.stop()
	turn_timer.wait_time = TURN_TIME
	turn_timer.start()
	rpc("sync_turn_rpc", current_player_id)


func _advance_turn() -> void:
	if players.is_empty():
		current_turn_index = 0
		current_player_id = 0
		game_started = false
		rpc("state_sync_rpc", _make_public_state())
		return

	current_turn_index = (current_turn_index + 1) % players.size()
	current_player_id = players[current_turn_index]
	_start_turn()


func _next_syllable() -> void:
	current_syllable = silben[randi() % silben.size()]
	rpc("new_syllable_rpc", current_syllable)
	print("[Server] Neue Silbe:", current_syllable)


# ============================================================
# RPCs the server sends to clients (clients implement diese)
# ============================================================
@rpc("authority", "call_remote") func state_sync_rpc(state: Dictionary) -> void: pass
@rpc("authority", "call_remote") func sync_turn_rpc(active_player_id: int) -> void: pass
@rpc("authority", "call_remote") func word_accepted_rpc(word: String, by_peer_id: int, by_name: String) -> void: pass
@rpc("authority", "call_remote") func word_result_rpc(ok: bool, word: String, reason: String) -> void: pass
@rpc("authority", "call_remote") func chat_broadcast_rpc(username: String, message: String) -> void: pass
@rpc("authority", "call_remote") func game_over_rpc(winner_id: int, winner_name: String, scores: Dictionary) -> void: pass
@rpc("authority", "call_remote") func new_syllable_rpc(syllable: String) -> void: pass


# ============================================================
# Timer Callback
# ============================================================
func _on_turn_timeout() -> void:
	if not game_started:
		return

	print("[Server] 💥 Zeit abgelaufen für:", current_player_id)
	rpc("word_result_rpc", false, "", "💥 Zeit abgelaufen!")
	_next_syllable()
	_advance_turn()
