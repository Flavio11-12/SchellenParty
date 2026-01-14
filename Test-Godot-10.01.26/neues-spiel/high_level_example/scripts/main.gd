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
@onready var http: HTTPRequest = HTTPRequest.new()

var valid_words: Array[String] = []
var used_words: Array[String] = []
const IP_ADDRESS := "localhost"
const PORT:  int = 42069

var peer = ENetMultiplayerPeer.new()
var username : String
var players := []               # Liste aller Spieler (peer_id)
var current_turn_index := 0     # index der Spieler am Zug
var current_player_id := 0

func _on_server_pressed() -> void:
	peer.create_server(PORT)

	var sm = SceneMultiplayer.new()
	sm.multiplayer_peer = peer
	get_tree().set_multiplayer(sm)

	joined()  # Server kann direkt joinen

func _on_client_pressed() -> void:
	peer.create_client(IP_ADDRESS, PORT)

	var sm = SceneMultiplayer.new()
	sm.multiplayer_peer = peer
	get_tree().set_multiplayer(sm)

	# Signal abfangen, sobald Verbindung steht
	sm.connected_to_server.connect(_on_connected_to_server)

func _on_send_pressed() -> void:
	if messageinput.text.strip_edges() == "":
		return
	rpc("msg_rpc", username, messageinput.text)
	messageinput.text = ""

func _on_connected_to_server():
	print("Client verbunden zum Server!")
	joined()  # Jetzt darfst du RPCs senden

@rpc("any_peer", "call_local")
func msg_rpc(username, data):
	messagebox.text += str(username, ": ", data, "\n")
	messagebox.scroll_vertical = INF

func joined():
	var my_id = multiplayer.get_unique_id()
	if multiplayer.is_server():
		# Direkt auf Server ausführen
		add_player_rpc(my_id)
	else:
		# Client sagt dem Server: "Ich bin da!"
		rpc_id(1, "add_player_rpc", my_id)
	connect_node.hide() 
	game_node.show() 
	username = nameinput.text
	
func _ready() -> void:
	add_child(http)
	http.connect("request_completed", Callable(self, "_on_request_completed"))

	check_button.pressed.connect(_on_check_button_pressed)
	word_input.text_submitted.connect(_on_word_submitted)

	result_label.text = "Wörter werden geladen..."

	http.request("https://raw.githubusercontent.com/Flavio11-12/SchellenParty/main/wortliste.txt")

func _on_request_completed(result, response_code, headers, body) -> void:
	if response_code == 200:
		var text: String = body.get_string_from_utf8()
		valid_words.clear()
		used_words.clear()

		for line in text.split("\n", false):
			var word := line.strip_edges()
			if word != "":
				valid_words.append(word.to_lower())

		result_label.text = "Wörter geladen! Gib ein Wort ein."
		check_button.disabled = false
		print("Wörter geladen: ", valid_words.size())
	else:
		result_label.text = "Fehler beim Laden der Wortliste."
		print("Fehler beim Laden der Datei: ", response_code)

func _on_check_button_pressed() -> void:
	_check_word()

func _on_word_submitted(new_text: String) -> void:
	_check_word()


func _check_word() -> void:
	if valid_words.size() == 0:
		result_label.text = "Die Wortliste wird noch geladen..."
		return

	var word := word_input.text.strip_edges().to_lower()

	if word == "":
		result_label.text = "Bitte ein Wort eingeben."
		return

	if word in used_words:
		result_label.text = "⚠️ \"" + word + "\" wurde bereits eingegeben."
		return

	if word in valid_words:
		result_label.text = "✅ \"" + word + "\" ist gültig."
		used_words.append(word)
		server_broadcast.rpc(word)
		print("Vor index +: " + str(current_turn_index))
		print("Nach index +: " + str(current_turn_index))
		print("Players:", players)
		end_turn()
	else:
		result_label.text = "❌ \"" + word + "\" ist nicht in der Liste."


@rpc("any_peer", "call_remote")  # jeder Peer empfängt es
func server_broadcast(word: String) -> void:
	if word in used_words:
		return  # doppelt vermeiden
	used_words.append(word)
	result_label.text = "Wort hinzugefügt: " + word

func start_turn():
	current_player_id = players[current_turn_index]
	rpc("sync_turn", current_player_id)

func end_turn():
	if !multiplayer.is_server():
		return  # Clients warten

	if players.size() == 0:
		print("Keine Spieler, Turn kann nicht weitergegeben werden")
		return

	current_turn_index = (current_turn_index + 1) % players.size()
	current_player_id = players[current_turn_index]
	print("End_turn: current_turn_index =", current_turn_index)
	print("Next player ID =", current_player_id)

	# an alle Peers synchronisieren
	rpc("sync_turn", current_player_id)


@rpc("any_peer", "call_local")
func sync_turn(active_player_id: int):
	current_player_id = active_player_id
	if multiplayer.get_unique_id() == current_player_id:
		word_input.editable = true
		ready_label.text = "Du bist am Zug!"
	else:
		word_input.editable = false
		ready_label.text = "Warte auf Spieler " + str(current_player_id)


func _on_button_pressed() -> void:
	start_turn()
	ready_button.hide()
	rpc("hide_ready_button_rpc")

@rpc("any_peer", "call_local")
func hide_ready_button_rpc():
	ready_button.hide()

@rpc("any_peer", "call_local")
func add_player_rpc(peer_id):
	if peer_id not in players:
		players.append(peer_id)
		print("Players:", players)
