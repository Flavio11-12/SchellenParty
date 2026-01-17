extends Node

# =========================
# UI Nodes
# =========================
@onready var connect_node: Control = $"Connect"
@onready var game_node: Control = $"Game"

@onready var playerlist: Label = $"Game/PlayerList"
@onready var nameinput: LineEdit = $"Connect/VBoxContainer/NamenEingabe"
@onready var messagebox: TextEdit = $"Game/VBoxContainer/Messages"
@onready var messageinput: LineEdit = $"Game/VBoxContainer/HBoxContainer/Message"
@onready var ready_button: Button = $"Game/ReadyB"
@onready var ready_label: Label = $"Game/ReadyL"
@onready var punkt_label: Label = $"Game/PunkteL"
@onready var word_input: LineEdit = $"Game/HBoxContainer/Text"
@onready var check_button: Button = $"Game/HBoxContainer/Button"
@onready var result_label: Label = $"Game/Resultlabel"
@onready var silben_label: Label = $"Game/SilbenLabel"

# =========================
# Networking
const IP_ADDRESS: String = "localhost"
const PORT: int = 42069
const SERVER_ID: int = 1
var peer: WebSocketMultiplayerPeer

# =========================
# Client State
var username: String = ""
var players: Array[int] = []
var used_words: Array[String] = []
var scores: Dictionary = {}
var current_player_id: int = 0
var game_started: bool = false
var names: Dictionary = {}
var current_syllable: String = ""

func _ready() -> void:
	game_node.hide()
	connect_node.show()
	check_button.pressed.connect(_on_check_button_pressed)
	word_input.text_submitted.connect(_on_word_submitted)
	ready_button.pressed.connect(_on_ready_pressed)
	_set_connected_ui(false)
	ready_label.text = "Noch nicht verbunden."
	result_label.text = "Verbinde dich mit dem Server..."

func _on_client_pressed() -> void:
	peer = WebSocketMultiplayerPeer.new()
	var url: String = "ws://%s:%d" % [IP_ADDRESS, PORT]
	var err: int = peer.create_client(url)
	if err != OK:
		result_label.text = "Verbindung fehlgeschlagen."
		return
	var sm: SceneMultiplayer = SceneMultiplayer.new()
	sm.multiplayer_peer = peer
	get_tree().set_multiplayer(sm)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	result_label.text = "Verbinde…"

func _on_connected_to_server() -> void:
	connect_node.hide()
	game_node.show()
	username = nameinput.text.strip_edges()
	if username == "":
		username = "Player"
	rpc_id(SERVER_ID, "register_player_rpc", username)
	ready_label.text = "Verbunden als %s" % username
	result_label.text = "Warte auf Spielstart..."

func _on_connection_failed() -> void:
	result_label.text = "Server nicht erreichbar."
	game_node.hide()
	connect_node.show()

func _on_server_disconnected() -> void:
	result_label.text = "Server getrennt."
	game_node.hide()
	connect_node.show()

# ------------------- UI -------------------
func _set_connected_ui(connected: bool) -> void:
	check_button.disabled = true

func _set_my_turn(is_my_turn: bool) -> void:
	word_input.editable = is_my_turn
	check_button.disabled = not is_my_turn
	ready_label.text = "Du bist am Zug!" if is_my_turn else "Warte auf Spieler %d" % current_player_id

func _on_send_pressed() -> void:
	var msg: String = messageinput.text.strip_edges()
	if msg == "":
		return
	rpc_id(SERVER_ID, "send_chat_rpc", msg)
	messageinput.clear()

func _on_ready_pressed() -> void:
	result_label.text = "Spiel startet…"
	rpc_id(SERVER_ID, "start_game_rpc")
	ready_button.hide()

func _on_check_button_pressed() -> void:
	_submit_word()
func _on_word_submitted(_t: String) -> void:
	_submit_word()
func _submit_word() -> void:
	if multiplayer.get_unique_id() != current_player_id:
		result_label.text = "Nicht dein Zug."
		return
	var w: String = word_input.text.strip_edges()
	if w == "":
		return
	rpc_id(SERVER_ID, "submit_word_rpc", w)
	word_input.clear()

# ------------------- RPCs -------------------
@rpc("authority", "call_remote")
func state_sync_rpc(state: Dictionary) -> void:
	players = state.get("players", [])
	names = state.get("names", {})
	scores = state.get("scores", {})
	used_words = state.get("used_words", [])
	current_player_id = int(state.get("current_player_id", 0))
	game_started = bool(state.get("game_started", false))
	current_syllable = str(state.get("current_syllable", ""))
	playerlist.text = ""
	for pid in players:
		var pname: String = str(names.get(pid, "Player %d" % pid))
		var score: int = int(scores.get(pid, 0))
		playerlist.text += "%s – Punkte: %d\n" % [pname, score]
	punkt_label.text = "Deine Punkte: %d" % int(scores.get(multiplayer.get_unique_id(), 0))
	if game_started:
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
	result_label.text = "✅ %s: %s" % [by_name, word]

@rpc("authority", "call_remote")
func word_result_rpc(ok: bool, word: String, reason: String) -> void:
	result_label.text = "✅ \"%s\" akzeptiert" % word if ok else "❌ %s" % reason

@rpc("authority", "call_remote")
func chat_broadcast_rpc(sender: String, msg: String) -> void:
	messagebox.text += "%s: %s\n" % [sender, msg]
	messagebox.scroll_vertical = INF

@rpc("authority", "call_remote")
func new_syllable_rpc(syllable: String) -> void:
	current_syllable = syllable
	silben_label.text = "Silbe: %s" % current_syllable  # <-- hier SilbenLabel nutzen
	word_input.clear()
	word_input.editable = true
	check_button.disabled = false

@rpc("authority", "call_remote")
func game_over_rpc(winner_id: int, winner_name: String, final_scores: Dictionary, final_names: Dictionary) -> void:
	game_started = false
	scores = final_scores
	names = final_names
	word_input.editable = false
	check_button.disabled = true
	ready_button.show()
	if multiplayer.get_unique_id() == winner_id:
		result_label.text = "🏆 DU HAST GEWONNEN!"
	else:
		result_label.text = "🏆 %s hat gewonnen!" % winner_name
	playerlist.text = ""
	for pid in scores.keys():
		var pname: String = str(names.get(pid, "Player %d" % pid))
		playerlist.text += "%s – Punkte: %d\n" % [pname, int(scores[pid])]
	punkt_label.text = "Deine Punkte: %d" % int(scores.get(multiplayer.get_unique_id(), 0))

# ------------------- Client → Server Stubs -------------------
# Client → Server Stubs
@rpc("any_peer")
func send_chat_rpc(_m: String) -> void:
	pass

@rpc("any_peer")
func register_player_rpc(_n: String) -> void:
	pass

@rpc("any_peer")
func start_game_rpc() -> void:
	pass

@rpc("any_peer")
func submit_word_rpc(_w: String) -> void:
	pass
