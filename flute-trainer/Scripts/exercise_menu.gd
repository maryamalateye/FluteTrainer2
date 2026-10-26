extends Control

@onready var exercise_list: VBoxContainer = $VBoxContainer/ScrollContainer/ExerciseList
@onready var back_button: Button = $VBoxContainer/BackButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for entry in ExerciseDatabase.all():
		var button := Button.new()
		var unlocked := Gamestate.is_unlocked(entry.id)
		button.text = entry["Exercise"]
		if unlocked:
			var best := Gamestate.get_best_score(entry.id)
			if best > 0.0:
				button.text += " (best: %d%%)" % round(best * 100)
		button.disabled = not unlocked
		button.pressed.connect(_on_exercise_pressed.bind(entry["id"]))
		exercise_list.add_child(button)
	
func _on_exercise_pressed(exercise_id: int) -> void:
	Gamestate.selected_exercise_id = exercise_id
	get_tree().change_scene_to_file("res://Scenes/exercise_shell.tscn")


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Menus/main_menu.tscn")
