extends Node

@export var client_scene_path: String = "res://high_level_example/scenes/main.tscn"
@export var server_scene_path: String = "res://high_level_example/scenes/ServerMain.tscn"


func _ready() -> void:
	var user_args := OS.get_cmdline_user_args()
	var is_server := ("--server" in user_args) or OS.has_feature("dedicated_server")
	call_deferred("_switch_scene", is_server)

func _switch_scene(is_server: bool) -> void:
	if is_server:
		print("Bootstrap: Starte SERVER:", server_scene_path)
		get_tree().change_scene_to_file(server_scene_path)
	else:
		print("Bootstrap: Starte CLIENT:", client_scene_path)
		get_tree().change_scene_to_file(client_scene_path)
