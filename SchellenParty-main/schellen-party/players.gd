extends Control

@onready var players_container = $Players
@onready var bomb = $Hand

var radius := 150.0

func update_player_positions():
	var count = players_container.get_child_count()
	if count == 0:
		return

	for i in range(count):
		var player = players_container.get_child(i)
		var angle = TAU * i / count

		var offset = Vector2(
			cos(angle),
			sin(angle)
		) * radius

		# Bombe als Mittelpunkt
		player.position = bomb.position + offset - player.size / 2
