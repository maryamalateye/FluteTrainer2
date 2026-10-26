extends Control

@onready var achievements_grid: GridContainer = $VBoxContainer/ScrollContainer/AchievementsGrid
@onready var back_button: Button = $VBoxContainer/BackButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for entry in ExerciseDatabase.all():
		achievements_grid.add_child(_make_badge(entry))

#replace with actual badge later
func _make_badge(entry: Dictionary) -> Control:
	var box := VBoxContainer.new()

	var icon := Label.new()
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 32)

	var caption := Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.text = entry["Exercise"]

	if Gamestate.has_passed(entry["id"]):
		icon.text = "✓"
	else:
		icon.text = "✖"
		icon.modulate = Color(1, 1, 1, 0.4)
		caption.modulate = Color(1, 1, 1, 0.4)

	box.add_child(icon)
	box.add_child(caption)
	return box

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Menus/main_menu.tscn")
