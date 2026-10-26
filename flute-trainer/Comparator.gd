extends Node
#autoload: sequential pitch comparison against the current exercise's Notes list

var expected: Array = []
var seconds_per_beat: float = 0.5
var index: int = 0
var correct: int = 0
var close: int = 0
var history: Array = []
var session_active: bool = false

signal note_result(status: String, expected_pitch: String, played_pitch: String)
signal session_finished(accuracy: float)

const NOTE_OFFSETS := {
	"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
	"F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11
}

func load_score(notes: Array, bpm: int) -> void:
	expected = notes.duplicate()
	seconds_per_beat = 60.0 / float(max(bpm, 1))
	index = 0
	correct = 0
	close = 0
	history.clear()
	session_active = true

func check_note(played_pitch: String) -> void:
	if not session_active or index >= expected.size():
		return

	var expected_pitch: String = expected[index]
	var status: String = classify_pitch(played_pitch, expected_pitch)

	print("Played: %s Expected: %s (%s)" % [played_pitch, expected_pitch, status])
	_record(expected_pitch, played_pitch, status)

# Compares played vs expected and returns "correct" (exact match), "close"
# (a semitone off, or the right note in the wrong octave — common with
# flute/whistle overblowing) which should not be scored as wrong, or "miss".
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
	session_finished.emit(accuracy)
