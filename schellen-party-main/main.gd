extends Control

var valid_words: Array[String] = []
var used_words: Array[String] = []

var server := WebSocketMultiplayerPeer.new()
var players := {}

@onready var word_input: LineEdit = $MarginContainer/VBoxContainer/WordRow/Wordinput
@onready var check_button: Button = $MarginContainer/VBoxContainer/WordRow/CheckButton
@onready var result_label: Label = $MarginContainer/VBoxContainer/ResultLabel
@onready var http: HTTPRequest = HTTPRequest.new()

func _ready() -> void:
	add_child(http)
	http.connect("request_completed", Callable(self, "_on_request_completed"))

	check_button.pressed.connect(_on_check_button_pressed)
	word_input.text_submitted.connect(_on_word_submitted)

	check_button.disabled = true
	result_label.text = "Wörter werden geladen..."

	http.request("https://raw.githubusercontent.com/Flavio11-12/SchellenParty/main/wortliste.txt")

	var port := 4322
	var ok := server.create_server(port)

	if ok != OK:
		push_warning("Konnte Server nicht starten")
	else:
		print("Server läuft auf Port ", port)

	multiplayer.multiplayer_peer = server

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


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

		# an alle Spieler senden
		server_broadcast.rpc(word)
	else:
		result_label.text = "❌ \"" + word + "\" ist nicht in der Liste."


@rpc
func server_broadcast(msg: String) -> void:
	print("Broadcast:", msg)
	client_message.rpc(msg)


@rpc
func client_message(msg: String) -> void:
	print("Client erhielt:", msg)


func _on_peer_connected(id: int) -> void:
	print("Client verbunden:", id)
	players[id] = true


func _on_peer_disconnected(id: int) -> void:
	print("Client getrennt:", id)
	players.erase(id)


func _on_connected():
	print("Client verbunden mit Server")


func _on_connection_failed():
	print("Verbindung gescheitert")


func _on_server_disconnected():
	print("Server getrennt")
