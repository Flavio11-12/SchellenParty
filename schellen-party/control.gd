extends Control

var valid_words: Array[String] = []
var used_words: Array[String] = []

@onready var word_input: LineEdit = $MarginContainer/VBoxContainer/WordRow/Wordinput
@onready var check_button: Button = $MarginContainer/VBoxContainer/WordRow/CheckButton
@onready var result_label: Label = $MarginContainer/VBoxContainer/ResultLabel
@onready var http: HTTPRequest = HTTPRequest.new()

func _ready() -> void:
	add_child(http)
	http.connect("request_completed", Callable(self, "_on_request_completed"))
	
	# Button & Enter-Event verbinden
	check_button.pressed.connect(_on_check_button_pressed)
	word_input.text_submitted.connect(_on_word_submitted)
	
	# Button blockieren, bis Wörter geladen sind
	check_button.disabled = true
	result_label.text = "Wörter werden geladen..."
	
	# Online-Wortliste laden
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
	if valid_words.size() == 0:  # <-- hier geändert
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
	else:
		result_label.text = "❌ \"" + word + "\" ist nicht in der Liste."
