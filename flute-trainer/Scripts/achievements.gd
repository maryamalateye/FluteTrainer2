extends Control

@onready var achievements_grid: GridContainer = $VBoxContainer/ScrollContainer/AchievementsGrid
@onready var back_button: Button = $VBoxContainer/BackButton

func _ready() -> void:
	for entry in ExerciseDatabase.all():
		achievements_grid.add_child(_make_badge(entry))

const PASS_ICON: Texture2D = preload("res://icons/pass.png")
const FAIL_ICON: Texture2D = preload("res://icons/fail.png")
const ICON_SIZE := Vector2(48, 48)
const THEME: Theme = preload("res://theme.tres")

func _make_badge(entry: Dictionary) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)

	var icon := TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var caption := Label.new()
	caption.theme = THEME
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caption.add_theme_font_size_override("font_size", 24)
	caption.text = "Level %d" % (entry["id"] + 1)

	if Gamestate.has_passed(entry["id"]):
		icon.texture = PASS_ICON
	else:
		icon.texture = FAIL_ICON
		caption.modulate = Color(1, 1, 1, 0.4)

	box.add_child(icon)
	box.add_child(caption)
	return box

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Menus/main_menu.tscn")
