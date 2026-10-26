extends Node
class_name ExerciseDatabase
#loads from json file

const JSON_PATH := "res://data/exercises.json"
const CONTENT_SCENE := preload("res://Scenes/exercise.tscn")

static func all() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	
	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	if file == null:
		push_error("ExerciseDatabase: couldn't open %s" % JSON_PATH)
		return list
	
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or not (parsed.get("Exercises") is Array):
		push_error("ExerciseDatabase: %s did not contain an \"Exercises\" array" % JSON_PATH)
		return list
	
	for i in range(parsed["Exercises"].size()):
		var entry: Dictionary = parsed["Exercises"][i]
		entry["id"] = i
		list.append(entry)
	
	return list

static func get_by_id(exercise_id: int) -> Dictionary:
	for entry in all():
		if entry["id"] == exercise_id:
			return entry
	return {}
