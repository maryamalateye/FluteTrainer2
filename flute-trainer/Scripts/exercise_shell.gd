extends Control

@onready var title_label: Label = $TitleLabel
@onready var content: Control = $Content
@onready var results_screen: Control = $ResultsScreen
@onready var score_label: Label = $ResultsScreen/VBoxContainer/ScoreLabel
@onready var retry_button: Button = $ResultsScreen/VBoxContainer/RetryButton
@onready var next_button: Button = $ResultsScreen/VBoxContainer/NextButton
@onready var menu_button: Button = $ResultsScreen/VBoxContainer/MenuButton

var _current_info: Dictionary
var _current_content

func _ready() -> void:
	results_screen.hide()
	retry_button.pressed.connect(_load_current)
	next_button.pressed.connect(_go_to_next)
	menu_button.pressed.connect(_go_to_menu)
	_load_current()

func _load_current() -> void:
	results_screen.hide()
	if _current_content:
		_current_content.queue_free()
	
	_current_info = ExerciseDatabase.get_by_id(Gamestate.selected_exercise_id)
	if _current_info.is_empty():
		push_error("ExerciseShell: unknown exercise id %s" % Gamestate.selected_exercise_id)
		return
	
	title_label.text = _current_info["Exercise"]
	_current_content = ExerciseDatabase.CONTENT_SCENE.instantiate()
	_current_content.config = _current_info
	content.add_child(_current_content)
	_current_content.finished.connect(_on_exercise_finished)
	_current_content.start()

func _on_exercise_finished(score: float) -> void:
	var passed := Gamestate.show_result(_current_info["id"], score)
	score_label.text = "%d%% - %s" % [round(score * 100), "Passed!" if passed else "Try again"]

	var next_info := ExerciseDatabase.get_by_id(_current_info["id"] + 1)
	next_button.disabled = not (passed and not next_info.is_empty())

	results_screen.show()

func _go_to_next() -> void:
	Gamestate.selected_exercise_id = _current_info["id"] + 1
	_load_current()

func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://Menus/main_menu.tscn")
