extends Node

# -----------------------
# TCP Server für Lobby
# -----------------------
var tcp_server := TCPServer.new()
var tcp_port := 4322

var clients := {}         # id -> StreamPeerTCP
var players := {}         # id -> Spielername
var next_client_id := 1   # eindeutige IDs für Clients

func _ready():
	# TCP Server starten
	var err = tcp_server.listen(tcp_port)
	if err != OK:
		push_warning("TCPServer konnte nicht starten: %s" % str(err))
	else:
		print("TCPServer läuft auf Port %d" % tcp_port)

	set_process(true)

func _process(delta):
	# Neue TCP-Verbindungen annehmen
	while tcp_server.is_connection_available():
		var peer = tcp_server.take_connection()
		if peer:
			var id = next_client_id
			next_client_id += 1
			clients[id] = peer
			print("Client verbunden:", id)

	# Nachrichten von Clients lesen
	var remove_list := []
	for id in clients.keys():
		var peer = clients[id]
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			remove_list.append(id)
			continue
		while peer.get_available_bytes() > 0:
			var msg = peer.get_utf8_string(peer.get_available_bytes())
			_handle_tcp_message(id, msg)

	# Getrennte Clients entfernen
	for id in remove_list:
		clients.erase(id)
		if players.has(id):
			players.erase(id)
			_broadcast_player_list()
		print("Client getrennt:", id)

# --- TCP Nachricht bearbeiten ---
func _handle_tcp_message(client_id, msg: String):
	# Nachricht als JSON parsen
	var data = JSON.parse_string(msg)
	if data.error != OK:
		print("Fehler beim Parsen: ", msg)
		return
	var obj = data.result

	match obj.get("action",""):
		"join":
			var name = obj.get("name","Spieler")
			players[client_id] = name
			_broadcast_player_list()
			print("Spieler beigetreten:", name)
		"start_game":
			_broadcast({"action":"start_game"})
		"word":
			_broadcast(obj)  # Nachricht einfach an alle weiterleiten

# --- Spieler-Liste an alle Clients broadcasten ---
func _broadcast_player_list():
	var player_list = []
	for name in players.values():
		player_list.append(name)
	_broadcast({"action":"player_list", "players": player_list})

# --- Broadcast an alle Clients ---
func _broadcast(obj: Dictionary):
	var msg = JSON.stringify(obj)
	for peer in clients.values():
		peer.put_utf8_string(msg)

# --- Start-Game manuell vom Host auslösen ---
func start_game():
	_broadcast({"action":"start_game"})
	print("Spiel gestartet, Broadcast an alle Clients")
