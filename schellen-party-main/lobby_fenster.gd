extends Control

@onready var ip_input: LineEdit = $VBoxContainer/HBoxContainer/ServerIPInput
@onready var name_input: LineEdit = $VBoxContainer/HBoxContainer2/PlayerNameInput
@onready var lobby_list := $VBoxContainer/LobbyList
@onready var status: Label = $VBoxContainer/StatusLabel
@onready var host_button: Button = $VBoxContainer/HBoxContainer3/HostButton
@onready var join_button: Button = $VBoxContainer/HBoxContainer3/JoinButton
@onready var start_button: Button = $VBoxContainer/HBoxContainer4/StartButton

var server := Server

var ws_peer: StreamPeerTCP = null

func _ready():
	host_button.pressed.connect(_host)
	join_button.pressed.connect(_join)
	start_button.pressed.connect(_on_start_pressed)
	start_button.disabled = true

	# MainUI am Anfang verstecken
	var main_ui = get_parent().get_node_or_null("MainUI")
	if main_ui:
		main_ui.hide()

# --- Host starten ---
func _host():
	status.text = "Host läuft"
	start_button.disabled = false
	# LobbyList bleibt leer bis Spieler joinen

# --- Join als Client ---
func _join():
	ws_peer = StreamPeerTCP.new()
	var err = ws_peer.connect_to_host(ip_input.text.strip_edges(), 4322)
	if err != OK:
		status.text = "Verbindung fehlgeschlagen"
		return
	status.text = "Verbunden"

	# Name senden
	var join_msg = {"action":"join","name":name_input.text.strip_edges()}
	ws_peer.put_utf8_string(JSON.stringify(join_msg))

	set_process(true)

func _process(delta):
	if ws_peer == null:
		return
	while ws_peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and ws_peer.get_available_bytes() > 0:
		var msg = ws_peer.get_utf8_string(ws_peer.get_available_bytes())
		var data = JSON.parse_string(msg).result
		match data.get("action",""):
			"player_list":
				lobby_list.clear()
				for name in data.players:
					lobby_list.add_item(name)
			"start_game":
				_on_start_pressed()

# --- Host startet das Spiel ---
func _on_start_pressed():
	self.hide()
	var main_ui = get_parent().get_node_or_null("MainUI")
	if main_ui:
		main_ui.show()
	# Server broadcastet Start an alle Clients
	server.start_game()
