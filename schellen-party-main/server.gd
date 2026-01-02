extends Node

var tcp_server := TCPServer.new()
var clients := {}
var players := {}
var next_client_id := 0
var pending_peers := []
var ws_port := 4322

func _ready():
	var err = tcp_server.listen(ws_port)
	if err != OK:
		push_warning("WebSocket Server konnte nicht gestartet werden. Fehler: " + str(err))
	else:
		print("WebSocket Server läuft auf Port ", ws_port)
	set_process(true)

func _process(delta):
	while tcp_server.is_connection_available():
		var tcp_peer = tcp_server.take_connection()
		var ws_peer = WebSocketPeer.new()
		ws_peer.accept_stream(tcp_peer)
		pending_peers.append(ws_peer)

	var i = 0
	while i < pending_peers.size():
		var ws_peer = pending_peers[i]
		ws_peer.poll()
		var state = ws_peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			var client_id = next_client_id
			next_client_id += 1
			clients[client_id] = ws_peer
			pending_peers.remove_at(i)
			print("Client verbunden:", client_id)
		elif state == WebSocketPeer.STATE_CLOSED:
			pending_peers.remove_at(i)
		else:
			i += 1

	var to_remove = []
	for client_id in clients.keys():
		var peer = clients[client_id]
		peer.poll()
		var state = peer.get_ready_state()
		if state == WebSocketPeer.STATE_CLOSED:
			to_remove.append(client_id)
			if players.has(client_id):
				players.erase(client_id)
			continue
		while peer.get_available_packet_count() > 0:
			var pkt = peer.get_packet()
			var msg = pkt.get_string_from_utf8()
			_handle_client_message(client_id, msg)
	for client_id in to_remove:
		clients.erase(client_id)
	if to_remove.size() > 0:
		_broadcast_player_list()

func _handle_client_message(client_id: int, msg: String):
	var json := JSON.new()
	if json.parse(msg) != OK:
		return
	var data = json.get_data()
	match data.get("action",""):
		"join":
			var name = data.get("name","Player")
			if players.has(client_id) or name in players.values():
				send_to_client(client_id, {"type":"join_denied"})
				return
			players[client_id] = name
			send_to_client(client_id, {"type":"join_ack"})
			_broadcast_player_list()
		"start_game":
			broadcast({"type":"start_game"})

func send_to_client(client_id: int, data: Dictionary):
	if clients.has(client_id):
		clients[client_id].send_text(JSON.stringify(data))

func broadcast(data: Dictionary):
	var msg = JSON.stringify(data)
	for peer in clients.values():
		peer.send_text(msg)

func _broadcast_player_list():
	var player_dict = {}
	for id in players.keys():
		player_dict[str(id)] = players[id]
	broadcast({"type":"player_list","players":player_dict})
