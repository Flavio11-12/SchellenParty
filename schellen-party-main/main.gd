extends Control

var valid_words := []
var used_words := []

@onready var input := $MarginContainer/VBoxContainer/WordRow/WordInput
@onready var label := $MarginContainer/VBoxContainer/ResultLabel

func _ready():
	$MarginContainer/VBoxContainer/WordRow/CheckButton.pressed.connect(check_word)

func check_word():
	var word: String = input.text.strip_edges().to_lower()

	if word == "":
		label.text = "Leer"
		return

	add_word.rpc(word)

@rpc("authority")
func add_word(word: String):
	if word in valid_words and not used_words.has(word):
		used_words.append(word)
		sync_word.rpc(word)


@rpc("any_peer")
func sync_word(word: String):
	used_words.append(word)
	label.text = "Neues Wort: " + word
