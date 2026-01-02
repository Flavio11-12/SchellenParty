extends Control

var connected := false
var is_host := false
var ws_peer := WebSocketPeer.new()
var players := {}

@onready var server_ip_input := find_child("ServerIPInput", true, false)
@onready var player_name_input := find_child("PlayerNameInput", true, false)
@onready var connect_button := find_child("ConnectButton", true, false)
@onready var start_button := find_child("StartButton", true, false)
@onready var status_label := find_child("StatusLabel", true, false)
@onready var lobby_list := find_child("LobbyList", true, false)

func _ready():
	connect_button.pressed.connect(_on_connect_pressed)
	start_button.pressed.connect(_on_start_pressed)
	start_button.disabled = true
	set_process(true)

func _process(delta):
	if not connected:
		return
	ws_peer.poll()
	while ws_peer.get_available_packet_count() > 0:
		var pkt = ws_peer.get_packet()
		var msg = pkt.get_string_from_utf8()
		_handle_message(msg)

func _on_connect_pressed():
	var ip = server_ip_input.text.strip_edges()
	if ip == "":
		status_label.text = "Enter server IP"
		return
	var err = ws_peer.connect_to_url("ws://" + ip + ":4321")
	if err != OK:
		status_label.text = "Connection failed: " + str(err)
		return
	connected = true
	status_label.text = "Connecting..."

func _on_start_pressed():
	if is_host:
		ws_peer.send_text(JSON.stringify({"action":"start_game"}))

func _handle_message(msg: String):
	var json := JSON.new()
	if json.parse(msg) != OK:
		return
	var obj = json.get_data()
	match obj.get("type",""):
		"player_list":
			players = obj["players"]
			_update_lobby_ui()
		"host":
			is_host = true
			start_button.disabled = false
			status_label.text = "You are the Host"
		"start_game":
			_start_game()
		"join_denied":
			status_label.text = "Name already in use!"
		"join_ack":
			print("Join erfolgreich")

func _update_lobby_ui():
	for child in lobby_list.get_children():
		child.queue_free()
	for id in players.keys():
		var lbl = Label.new()
		lbl.text = players[id]
		lobby_list.add_child(lbl)

func _start_game():
	# Lobby ausblenden
	self.hide()

	# Main sichtbar machen
	var main_scene = get_parent().get_node("Main")
	if main_scene:
		main_scene.show()
	else:
		push_warning("Main node nicht gefunden!")
