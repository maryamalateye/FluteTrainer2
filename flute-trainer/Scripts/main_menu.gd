extends Control

@onready var practice_button: Button = $VBoxContainer/PracticeButton
@onready var achievements_button: Button = $VBoxContainer/AchievementsButton

func _on_practice_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Menus/exercise_menu.tscn")


func _on_achievements_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/achievements.tscn")
