extends Node
#autoload

var expected: Array = []
var note_beats: Array[float] = []
var bpm: float = 80.0
var seconds_per_beat: float = 0.5
var index: int = 0
var correct: int = 0
var close: int = 0
var history: Array = []
var session_active: bool = false

var onset_log: Array = []
var last_tempo_result: Dictionary = {}

const TEMPO_TOLERANCE: float = 0.08	

signal note_result(status: String, expected_pitch: String, played_pitch: String)
signal session_finished(accuracy: float, tempo: Dictionary)

const NOTE_OFFSETS := {
	"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
	"F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11
}

func load_score(notes: Array, bpm_value: int, beats: Array = []) -> void:
	expected = notes.duplicate()
	bpm = float(max(bpm_value, 1))
	seconds_per_beat = 60.0 / bpm
	note_beats.clear()
	for i in range(expected.size()):
		note_beats.append(float(beats[i]) if i < beats.size() else 1.0)
	index = 0
	correct = 0
	close = 0
	history.clear()
	onset_log.clear()
	last_tempo_result = {}
	session_active = true

func record_onset(elapsed_time: float) -> void:
	if not session_active:
		return
	onset_log.append({"index": index, "time": elapsed_time})

func check_note(played_pitch: String) -> void:
	if not session_active or index >= expected.size():
		return

	var expected_pitch: String = expected[index]
	var status: String = classify_pitch(played_pitch, expected_pitch)

	print("Played: %s Expected: %s (%s)" % [played_pitch, expected_pitch, status])
	_record(expected_pitch, played_pitch, status)

func classify_pitch(played_pitch: String, expected_pitch: String) -> String:
	var norm_played := normalise_pitch(played_pitch)
	var norm_expected := normalise_pitch(expected_pitch)

	if norm_played == norm_expected:
		return "correct"

	var played_midi := pitch_to_midi(norm_played)
	var expected_midi := pitch_to_midi(norm_expected)
	if played_midi == -1 or expected_midi == -1:
		return "miss"

	var diff: int = abs(played_midi - expected_midi)
	if diff == 1 or (diff > 0 and diff % 12 == 0):
		return "close"
	return "miss"

func pitch_to_midi(normalised_pitch: String) -> int:
	if normalised_pitch.is_empty():
		return -1
	var octave_str := ""
	var head := normalised_pitch
	var i := normalised_pitch.length() - 1
	while i >= 0 and normalised_pitch[i].is_valid_int():
		octave_str = normalised_pitch[i] + octave_str
		head = normalised_pitch.substr(0, i)
		i -= 1
	if octave_str.is_empty() or not NOTE_OFFSETS.has(head):
		return -1
	var octave := int(octave_str)
	return NOTE_OFFSETS[head] + (octave + 1) * 12

func finish_now() -> void:
	if not session_active:
		return
	while index < expected.size():
		_record(expected[index], "", "miss")
	_finish_session()

func reset() -> void:
	index = 0
	correct = 0
	close = 0
	history.clear()
	session_active = false

func normalise_pitch(pitch: String) -> String:
	var eharmonics := {"Bb": "A#", "Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#"}
	if pitch.is_empty():
		return pitch
	var octave := ""
	var head := pitch
	if pitch[pitch.length() - 1].is_valid_int():
		octave = pitch[pitch.length() - 1]
		head = pitch.substr(0, pitch.length() - 1)
	return eharmonics.get(head, head) + octave

func _record(expected_pitch: String, played_pitch: String, status: String) -> void:
	if status == "correct":
		correct += 1
	elif status == "close":
		close += 1

	history.append({
		"expected": expected_pitch,
		"played": played_pitch,
		"status": status,
		"correct": status != "miss"
	})

	index += 1

	note_result.emit(status, expected_pitch, played_pitch)

	if index >= expected.size():
		_finish_session()

func _finish_session() -> void:
	if not session_active:
		return
	session_active = false

	var accuracy: float = 0.0
	if not expected.is_empty():
		accuracy = (float(correct + close) / float(expected.size())) * 100.0

	last_tempo_result = _compute_tempo_analysis()
	session_finished.emit(accuracy, last_tempo_result)

func _compute_tempo_analysis() -> Dictionary:
	var expected_times: Array = []
	var cumulative := 0.0
	for b in note_beats:
		expected_times.append(cumulative)
		cumulative += b * seconds_per_beat

	var actual_times: Dictionary = {}
	for entry in onset_log:
		var idx: int = entry["index"]
		if idx >= 0 and idx < expected.size() and not actual_times.has(idx):
			actual_times[idx] = entry["time"]

	var per_note: Array = []
	var bpm_samples: Array = []
	print("--- Tempo analysis (target %.1f BPM) ---" % bpm)
	for i in range(1, expected.size()):
		if not (actual_times.has(i) and actual_times.has(i - 1)):
			continue
		var actual_interval: float = actual_times[i] - actual_times[i - 1]
		if actual_interval <= 0.0:
			continue
		var beats_for_prev_note: float = note_beats[i - 1]
		var actual_bpm: float = (beats_for_prev_note / actual_interval) * 60.0
		var status := _classify_tempo(actual_bpm)
		bpm_samples.append(actual_bpm)
		per_note.append({
			"note_index": i - 1,
			"note": expected[i - 1],
			"expected_bpm": bpm,
			"actual_bpm": actual_bpm,
			"status": status
		})
		print("Note %d (%s): expected %.1f BPM, actual %.1f BPM -> %s" % [i - 1, expected[i - 1], bpm, actual_bpm, status])

	var has_data := not bpm_samples.is_empty()
	var overall_actual_bpm := 0.0
	if has_data:
		var sum := 0.0
		for s in bpm_samples:
			sum += s
		overall_actual_bpm = sum / bpm_samples.size()
	var overall_status := _classify_tempo(overall_actual_bpm) if has_data else "Unknown"
	if has_data:
		print("Overall: expected %.1f BPM, actual %.1f BPM -> %s" % [bpm, overall_actual_bpm, overall_status])
	else:
		print("Overall: expected %.1f BPM, actual N/A (not enough onsets detected) -> %s" % [bpm, overall_status])

	return {
		"per_note": per_note,
		"expected_bpm": bpm,
		"actual_bpm": overall_actual_bpm,
		"has_data": has_data,
		"status": overall_status
	}

func tempo_message(tempo: Dictionary) -> String:
	if not tempo.get("has_data", false):
		return "Not enough notes heard to check your tempo"
	match tempo.get("status", ""):
		"Too Fast":
			return "You were playing too fast"
		"Too Slow":
			return "You were going too slow"
		"Just Right":
			return "Your tempo was just right"
	return "Couldn't check your tempo"

func _classify_tempo(actual_bpm: float) -> String:
	if bpm <= 0.0:
		return "Unknown"
	var ratio := actual_bpm / bpm
	if ratio > 1.0 + TEMPO_TOLERANCE:
		return "Too Fast"
	elif ratio < 1.0 - TEMPO_TOLERANCE:
		return "Too Slow"
	else:
		return "Just Right"
