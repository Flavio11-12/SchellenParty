extends Node

@onready var connect_node = $"Connect"
@onready var game_node = $"Game"
@onready var playerlist = $"Game/PlayerList"
@onready var nameinput = $"Connect/VBoxContainer/NameEdit"
@onready var messagebox = $"Game/VBoxContainer/Messages"
@onready var messageinput = $"Game/VBoxContainer/HBoxContainer/Message"
@onready var hand = $"Game/TextureRect"
@onready var ready_button = $"Game/ReadyB"
@onready var ready_label = $"Game/ReadyL"
@onready var word_input: LineEdit = $Game/HBoxContainer/Text
@onready var check_button: Button = $Game/HBoxContainer/Button
@onready var result_label: Label = $Game/Resultlabel
#@onready var http: HTTPRequest = HTTPRequest.new()

#var valid_words: Array[String] = []
var used_words: Array[String] = []
const IP_ADDRESS := "localhost"
const PORT:  int = 42069

var peer := WebSocketMultiplayerPeer.new()
var username : String
var players := []               # Liste aller Spieler (peer_id)
var current_turn_index := 0     # index der Spieler am Zug
var current_player_id := 0


#func _on_server_pressed() -> void:
#	peer.create_server(PORT)
#
#	var sm = SceneMultiplayer.new()
#	sm.multiplayer_peer = peer
#	get_tree().set_multiplayer(sm)
#
#	joined()  # Server kann direkt joinen
#
func _on_client_pressed() -> void:
	var url: String = "ws://%s:%d" % [IP_ADDRESS, PORT]
	var err: int = peer.create_client(url)
	if err != OK:
		push_error("WebSocket connect error: %s" % str(err))
		return

	var sm: SceneMultiplayer = SceneMultiplayer.new()
	sm.multiplayer_peer = peer
	get_tree().set_multiplayer(sm)

	# Signale sauber verbinden (keine Lambdas!)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	print("Connecting to:", url)

#Funktionen für Connection
func _on_connected_to_server() -> void:
	print("✅ Client verbunden! Peer ID:", multiplayer.get_unique_id())
	joined()

func _on_connection_failed() -> void:
	print("❌ Verbindung zum Server fehlgeschlagen")

func _on_server_disconnected() -> void:
	print("⚠️ Verbindung zum Server getrennt")



func _on_send_pressed() -> void:
	var msg := messageinput.text.strip_edges()
	if msg == "":
		return

	rpc_id(1, "send_chat_rpc", msg)
	messageinput.text = ""


func _on_connected_to_server():
	print("Client verbunden zum Server!")
	joined()  # Jetzt darfst du RPCs senden

#@rpc("any_peer", "call_local")
#func msg_rpc(username, data):
#	messagebox.text += str(username, ": ", data, "\n")
#	messagebox.scroll_vertical = INF

func joined():
	connect_node.hide()
	game_node.show()

	username = nameinput.text.strip_edges()
	if username == "":
		username = "Player"
	if multiplayer.is_server():
		register_player_rpc(username)  # wenn Client, nimm 1 wenn Server ruf direkt auf
	else:
		rpc_id(1, "register_player_rpc", username)
	
#func _ready() -> void:
#	add_child(http)
#	http.connect("request_completed", Callable(self, "_on_request_completed"))
#
#	check_button.pressed.connect(_on_check_button_pressed)
#	word_input.text_submitted.connect(_on_word_submitted)
#
#	result_label.text = "Wörter werden geladen..."
#
#	http.request("https://raw.githubusercontent.com/Flavio11-12/SchellenParty/main/wortliste.txt")

func _ready() -> void:
	check_button.pressed.connect(_on_check_button_pressed)
	word_input.text_submitted.connect(_on_word_submitted)

	check_button.disabled = false
	result_label.text = "Gib ein Wort ein."


#func _on_request_completed(result, response_code, headers, body) -> void:
#	if response_code == 200:
#		var text: String = body.get_string_from_utf8()
#		valid_words.clear()
#		used_words.clear()
#
#		for line in text.split("\n", false):
#			var word := line.strip_edges()
#			if word != "":
#				valid_words.append(word.to_lower())
#
#		result_label.text = "Wörter geladen! Gib ein Wort ein."
#		check_button.disabled = false
#		print("Wörter geladen: ", valid_words.size())
#	else:
#		result_label.text = "Fehler beim Laden der Wortliste."
#		print("Fehler beim Laden der Datei: ", response_code)

func _on_check_button_pressed() -> void:
	_check_word()

func _on_word_submitted(new_text: String) -> void:
	_check_word()


#func _check_word() -> void:
#	if valid_words.size() == 0:
#		result_label.text = "Die Wortliste wird noch geladen..."
#		return
#
#	var word := word_input.text.strip_edges().to_lower()

#	if word == "":
#		result_label.text = "Bitte ein Wort eingeben."
##		return
#
#	if word in used_words:
#		result_label.text = "⚠️ \"" + word + "\" wurde bereits eingegeben."
#		return

#	if word in valid_words:
#		result_label.text = "✅ \"" + word + "\" ist gültig."
#		used_words.append(word)
#		server_broadcast.rpc(word)
#		print("Vor index +: " + str(current_turn_index))
#		print("Nach index +: " + str(current_turn_index))
#		print("Players:", players)
#		end_turn()
#	else:
#		result_label.text = "❌ \"" + word + "\" ist nicht in der Liste."

func _check_word() -> void:
	var w := word_input.text.strip_edges()
	if w == "":
		result_label.text = "Bitte ein Wort eingeben."
		return

	# Optional: Nur senden, wenn du am Zug bist
	if multiplayer.get_unique_id() != current_player_id:
		result_label.text = "Nicht dein Zug."
		return

	rpc_id(1, "submit_word_rpc", w)
	word_input.clear()


#@rpc("any_peer", "call_remote")  # jeder Peer empfängt es
#func server_broadcast(word: String) -> void:
#	if word in used_words:
#		return  # doppelt vermeiden
#	used_words.append(word)
#	result_label.text = "Wort hinzugefügt: " + word

#func start_turn():
#	current_player_id = players[current_turn_index]
#	rpc("sync_turn", current_player_id)

#func end_turn():
#	if !multiplayer.is_server():
#		return  # Clients warten
#
#	if players.size() == 0:
#		print("Keine Spieler, Turn kann nicht weitergegeben werden")
#		return

#	current_turn_index = (current_turn_index + 1) % players.size()
#	current_player_id = players[current_turn_index]
#	print("End_turn: current_turn_index =", current_turn_index)
#	print("Next player ID =", current_player_id)
#
	# an alle Peers synchronisieren
#	rpc("sync_turn", current_player_id)


#@rpc("any_peer", "call_local")
#func sync_turn(active_player_id: int):
#	current_player_id = active_player_id
#	if multiplayer.get_unique_id() == current_player_id:
#		word_input.editable = true
#		ready_label.text = "Du bist am Zug!"
#	else:
#		word_input.editable = false
#		ready_label.text = "Warte auf Spieler " + str(current_player_id)

func _on_button_pressed() -> void:
	rpc_id(1, "start_game_rpc")
	ready_button.hide()


@rpc("any_peer", "call_local")
func hide_ready_button_rpc():
	ready_button.hide()

#@rpc("any_peer", "call_local")
#func add_player_rpc(peer_id):
#	if peer_id not in players:
#		players.append(peer_id)
#		print("Players:", players)


#RPCs für Kommunikation mit Server

# Server schickt kompletten Zustand (players, names, used_words, usw.)
@rpc("authority", "call_remote")
func state_sync_rpc(state: Dictionary) -> void:
	players = state.get("players", [])
	var names_map: Dictionary = state.get("names", {})
	used_words = state.get("used_words", [])
	current_player_id = int(state.get("current_player_id", 0))

	# UI: Playerliste updaten
	playerlist.text = ""
	for pid in players:
		var n = names_map.get(pid, "Player %d" % pid)
		playerlist.text += "%s (%s)\n" % [str(n), str(pid)]

	# UI: evtl. used words anzeigen (optional)
	# messagebox.text += "Used words: %d\n" % used_words.size()


# Server sagt, wer am Zug ist
@rpc("authority", "call_remote")
func sync_turn_rpc(active_player_id: int) -> void:
	current_player_id = active_player_id

	if multiplayer.get_unique_id() == current_player_id:
		word_input.editable = true
		ready_label.text = "Du bist am Zug!"
	else:
		word_input.editable = false
		ready_label.text = "Warte auf Spieler " + str(current_player_id)


# Server broadcastet: Wort wurde akzeptiert
@rpc("authority", "call_remote")
func word_accepted_rpc(word: String, by_peer_id: int, by_name: String) -> void:
	# lokal merken
	if word not in used_words:
		used_words.append(word)

	result_label.text = "✅ %s: %s" % [by_name, word]


# Server antwortet NUR dem Sender bei Fehler / Feedback
@rpc("authority", "call_remote")
func word_result_rpc(ok: bool, word: String, reason: String) -> void:
	if ok:
		result_label.text = "✅ \"" + word + "\" akzeptiert."
	else:
		result_label.text = "❌ \"" + word + "\": " + reason


# Server broadcastet Chatnachrichten
@rpc("authority", "call_remote")
func chat_broadcast_rpc(username: String, message: String) -> void:
	messagebox.text += "%s: %s\n" % [username, message]
	messagebox.scroll_vertical = INF

