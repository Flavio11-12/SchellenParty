extends Node

# =========================
# UI Nodes
# =========================
@onready var connect_node: Control = $"Connect"
@onready var game_node: Control = $"Game"

@onready var playerlist: Label = $"Game/PlayerList"
@onready var nameinput: LineEdit = $"Connect/VBoxContainer/NameEdit"

@onready var messagebox: TextEdit = $"Game/VBoxContainer/Messages"
@onready var messageinput: LineEdit = $"Game/VBoxContainer/HBoxContainer/Message"

@onready var ready_button: Button = $"Game/ReadyB"
@onready var ready_label: Label = $"Game/ReadyL"

@onready var word_input: LineEdit = $"Game/HBoxContainer/Text"
@onready var check_button: Button = $"Game/HBoxContainer/Button"
@onready var result_label: Label = $"Game/Resultlabel"


# =========================
# Networking Config
# =========================
const IP_ADDRESS: String = "localhost"  # später im Web: domain / IP vom Server
const PORT: int = 42069

var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()

# Server ist im High-Level Multiplayer normalerweise peer_id = 1
const SERVER_ID: int = 1

# =========================
# Client-side cached state (vom Server)
# =========================
var username: String = ""
var players: Array = []                 # peer ids
var used_words: Array = []              # words (Array vom Server)
var current_player_id: int = 0
var game_started: bool = false


# =========================
# Lifecycle
# =========================
func _ready() -> void:
	# initial UI state
	game_node.hide()
	connect_node.show()

	# UI wiring
	check_button.pressed.connect(_on_check_button_pressed)
	word_input.text_submitted.connect(_on_word_submitted)
	ready_button.pressed.connect(_on_ready_pressed)

	# Chat send (falls du einen Send-Button hast, callt der diese Methode)
	# -> _on_send_pressed() per Button verbinden im Editor oder hier connecten, wenn du einen Button hast.

	_set_connected_ui(false)

	ready_label.text = "Noch nicht verbunden."
	result_label.text = "Verbinde dich mit dem Server."


# =========================
# Connect Button
# =========================
func _on_client_pressed() -> void:
	# Falls schon verbunden/versucht wird, neu initialisieren:
	peer = WebSocketMultiplayerPeer.new()

	var url: String = "ws://%s:%d" % [IP_ADDRESS, PORT]
	var err: int = peer.create_client(url)
	if err != OK:
		push_error("WebSocket connect error: %s" % str(err))
		ready_label.text = "Verbindung fehlgeschlagen (create_client)."
		return

	var sm: SceneMultiplayer = SceneMultiplayer.new()
	sm.multiplayer_peer = peer
	get_tree().set_multiplayer(sm)

	# Signale (ohne Lambdas)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	ready_label.text = "Verbinde… " + url
	result_label.text = "Verbinde…"
	print("[Client] Connecting to:", url)


# =========================
# Multiplayer Callbacks
# =========================
func _on_connected_to_server() -> void:
	print("[Client] ✅ connected_to_server. My ID:", multiplayer.get_unique_id())

	# UI umschalten
	connect_node.hide()
	game_node.show()

	_set_connected_ui(true)

	# Username ermitteln + registrieren
	username = nameinput.text.strip_edges()
	if username == "":
		username = "Player"

	# Registrierung beim ServerMain
	rpc_id(SERVER_ID, "register_player_rpc", username)

	ready_label.text = "Verbunden als %s. Warte auf Start…" % username
	result_label.text = "Gib ein Wort ein (wenn du am Zug bist)."


func _on_connection_failed() -> void:
	print("[Client] ❌ connection_failed")
	ready_label.text = "Verbindung fehlgeschlagen."
	result_label.text = "Server nicht erreichbar?"
	_set_connected_ui(false)

	connect_node.show()
	game_node.hide()


func _on_server_disconnected() -> void:
	print("[Client] ⚠️ server_disconnected")
	ready_label.text = "Server getrennt."
	result_label.text = "Verbindung verloren."
	_set_connected_ui(false)

	connect_node.show()
	game_node.hide()


# =========================
# UI Helpers
# =========================
func _set_connected_ui(is_connected: bool) -> void:
	# Chat
	messageinput.editable = is_connected

	# Wort UI (Turn-basiert gesteuert)
	word_input.editable = false
	check_button.disabled = not is_connected

	# Chatbox nur Anzeige
	messagebox.editable = false



func _set_my_turn(is_my_turn: bool) -> void:
	word_input.editable = is_my_turn
	check_button.disabled = not is_my_turn
	if is_my_turn:
		ready_label.text = "Du bist am Zug!"
	else:
		ready_label.text = "Warte auf Spieler " + str(current_player_id)


# =========================
# Chat
# =========================
func _on_send_pressed() -> void:
	var msg: String = messageinput.text.strip_edges()
	if msg == "":
		return

	rpc_id(SERVER_ID, "send_chat_rpc", msg)
	messageinput.text = ""


# =========================
# Game Start (Ready button)
# =========================
func _on_ready_pressed() -> void:
	# Start-Request an Server (du kannst serverseitig einschränken, wer starten darf)
	rpc_id(SERVER_ID, "start_game_rpc")
	ready_button.hide()


# =========================
# Word submit
# =========================
func _on_check_button_pressed() -> void:
	_submit_word()

func _on_word_submitted(_new_text: String) -> void:
	_submit_word()

func _submit_word() -> void:
	if not multiplayer.has_multiplayer_peer():
		result_label.text = "Nicht verbunden."
		return

	var w: String = word_input.text.strip_edges()
	if w == "":
		result_label.text = "Bitte ein Wort eingeben."
		return

	# Client-side guard (Server prüft sowieso nochmal)
	if multiplayer.get_unique_id() != current_player_id:
		result_label.text = "Nicht dein Zug."
		return

	rpc_id(SERVER_ID, "submit_word_rpc", w)
	word_input.clear()


# ============================================================
# RPCs: Server -> Client (müssen exakt so heißen wie in ServerMain)
# ============================================================

@rpc("authority", "call_remote")
func state_sync_rpc(state: Dictionary) -> void:
	players = state.get("players", [])
	var names_map: Dictionary = state.get("names", {})
	used_words = state.get("used_words", [])
	current_player_id = int(state.get("current_player_id", 0))
	game_started = bool(state.get("game_started", false))

	# Playerliste UI
	playerlist.text = ""
	for pid in players:
		var n = names_map.get(pid, "Player %d" % pid)
		playerlist.text += "%s (%s)\n" % [str(n), str(pid)]

	# Turn UI (falls schon gestartet)
	if game_started and current_player_id != 0:
		_set_my_turn(multiplayer.get_unique_id() == current_player_id)
	else:
		word_input.editable = false
		check_button.disabled = true
		ready_label.text = "Warte auf Start…"


@rpc("authority", "call_remote")
func sync_turn_rpc(active_player_id: int) -> void:
	current_player_id = active_player_id
	_set_my_turn(multiplayer.get_unique_id() == current_player_id)


@rpc("authority", "call_remote")
func word_accepted_rpc(word: String, by_peer_id: int, by_name: String) -> void:
	if word not in used_words:
		used_words.append(word)

	result_label.text = "✅ %s: %s" % [by_name, word]


@rpc("authority", "call_remote")
func word_result_rpc(ok: bool, word: String, reason: String) -> void:
	if ok:
		result_label.text = "✅ \"%s\" akzeptiert." % word
	else:
		result_label.text = "❌ \"%s\": %s" % [word, reason]


@rpc("authority", "call_remote")
func chat_broadcast_rpc(sender_name: String, message: String) -> void:
	messagebox.text += "%s: %s\n" % [sender_name, message]
	messagebox.scroll_vertical = INF
