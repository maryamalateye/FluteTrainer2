extends Node
#autoload with progress

const SAVE_PATH := "user://save.dat"
const PASS_THRESHOLD := 0.75	

var unlocked_level: int = 0	#highest unlocked level
var best_score: Dictionary = {}
var selected_exercise_id: int = 0	#used by exercise_menu to change to exercise scene

func is_unlocked(exercise_id: int) -> bool:
	return exercise_id <= unlocked_level

func get_best_score(exercise_id: int) -> float:
	return best_score.get(exercise_id, 0.0)
	
func has_passed(exercise_id: int) -> bool:
	return get_best_score(exercise_id) >= PASS_THRESHOLD

#show user if they passed or not and save their session info
func show_result(exercise_id: int, score: float) -> bool:
	var passed: bool
	passed = score >= PASS_THRESHOLD
	best_score[exercise_id] = max(get_best_score(exercise_id), score)
	if (passed) and exercise_id == unlocked_level:
		unlocked_level += 1
	save_progress()
	return passed

func save_progress() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Gamestate: failed to open save file for writing. Can't save (1)")
		return
	var data := {
		"unlocked_level": unlocked_level,
		"best_score": best_score
	}
	file.store_string(JSON.stringify(data))
	
func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	unlocked_level = parsed.get("unlocked_level", 0)
	#convert strings back into ints (json quirk, can just change how i index)
	best_score = {}
	for key in parsed.get("best_scores", {}):
		best_score[int(key)] = parsed["best_score"][key]
	
	
	
	








	
	
	
	
