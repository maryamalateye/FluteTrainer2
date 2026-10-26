extends Control

signal finished(score: float)

const MIN_HZ: int = 60
const MAX_HZ: int = 2000
const STEP_HZ: int = 1
const MIN_MAG: float = 0.0001	#if too many notes, raise it. if missing notes, lower it. this is number needed to register note as sound
const SILENCE_MAG: float = 0.00002
const STABLE_TIME: float = 0.18	#seconds a note must stay stable before committing.
const NOTES_NAME_SHARP := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const BEAT_PULSE_DECAY: float = 0.35	#seconds for the metronome pulse to fade back down
const BEAT_PULSE_BASE_COLOR := Color(0.55, 0.55, 0.6)
const BEAT_PULSE_HIT_COLOR := Color(1.0, 0.85, 0.2)
const COUNT_IN_BEATS: int = 4	#how many metronome beats to click before listening starts
const SCORE_DISPLAY_DELAY: float = 1.0	#seconds to hold the last note's feedback before switching to the score screen

var config: Dictionary = {}

@onready var label: Label = $Label
@onready var now_label: Label = $NowLabel
@onready var record_button: Button = $Button
@onready var mic: AudioStreamPlayer = $Mic
@onready var note_progress: ProgressBar = $NoteProgress
@onready var beat_pulse: ColorRect = $BeatPulse

var spectrum: AudioEffectSpectrumAnalyzerInstance
var listening := false
var counting_in := false
var is_playing := false
var candidate_note := ""
var candidate_time := 0.0
var last_committed_note := ""
var _started := false

var exercise_notes: Array = []
var note_beats: Array[float] = []	#beat length (1 = full beat, 0.5 = half beat) for each note, in sync with Comparator.index
var note_elapsed := 0.0
var metronome_elapsed := 0.0
var pulse_strength := 0.0
var _last_shown_index := -1

func _ready() -> void:
	record_button.show()
	start()

func start() -> void:
	if _started:
		return
	_started = true

	var bpm: int = config.get("BPM", 80)
	exercise_notes = config.get("Notes", [])
	var beats: Array = config.get("Beats", [])
	note_beats.clear()
	for i in range(exercise_notes.size()):
		note_beats.append(float(beats[i]) if i < beats.size() else 1.0)
	label.text = "Play at %d BPM: %s" % [bpm, ", ".join(exercise_notes)]
	if now_label:
		now_label.text = ""
	record_button.text = "Start Listening"
	record_button.pressed.connect(_on_record_button_pressed)
	Comparator.note_result.connect(_on_note_result)
	Comparator.session_finished.connect(_on_session_finished)

	var record_bus_index := AudioServer.get_bus_index("Record")
	if record_bus_index == -1:
		push_error("Audio bus 'Record' not found")
		return
	if not (AudioServer.get_bus_effect(record_bus_index, 0) is AudioEffectSpectrumAnalyzer):
		push_error("Error with spectrum analyser effect")
		return
	spectrum = AudioServer.get_bus_effect_instance(record_bus_index, 0)

func _process(delta: float) -> void:
	if not listening or spectrum == null:
		return

	_update_timing(delta)

	var peak := get_peak_frequency()
	var freq: float = peak.freq
	var mag: float = peak.mag

	if is_playing:
		if mag < SILENCE_MAG:
			is_playing = false
			candidate_note = ""
			candidate_time = 0.0
	else:
		if mag > MIN_MAG:
			is_playing = true

	if not is_playing:
		return

	var midi := hz_to_midi(freq)
	if midi < 0:
		return

	var detected_note := midi_to_name(midi)
	var newly_committed := update_stable_note(detected_note, delta)

	if newly_committed != "":
		print(newly_committed)

# Advances one note per beat/half-beat, on a clock, instead of waiting for the
# player to hold a note stably — keeps the exercise moving at tempo. Scores
# whatever pitch the player was last on when each note's time is up.
func _update_timing(delta: float) -> void:
	if not Comparator.session_active:
		return

	var beat_length: float = max(Comparator.seconds_per_beat, 0.001)
	metronome_elapsed += delta
	if metronome_elapsed >= beat_length:
		metronome_elapsed = fmod(metronome_elapsed, beat_length)
		_trigger_beat_pulse()
	_decay_beat_pulse(delta)

	_update_now_label()

	var duration := _current_note_duration()
	if duration <= 0.0:
		return
	note_elapsed += delta
	if note_progress:
		note_progress.value = clampf(note_elapsed / duration, 0.0, 1.0)
	if note_elapsed >= duration:
		note_elapsed -= duration
		Comparator.check_note(last_committed_note)
		_update_now_label()

func _current_note_duration() -> float:
	var idx := Comparator.index
	if idx < 0 or idx >= note_beats.size():
		return 0.0
	return note_beats[idx] * max(Comparator.seconds_per_beat, 0.001)

# Shows which note is expected right now, separate from the transient
# GOOD/CLOSE/MISS feedback in `label` — so the two never overwrite each other.
func _update_now_label() -> void:
	var idx := Comparator.index
	if idx == _last_shown_index:
		return
	_last_shown_index = idx
	if not now_label:
		return
	if idx >= 0 and idx < exercise_notes.size():
		now_label.text = "Now play: %s" % exercise_notes[idx]
	else:
		now_label.text = ""

func _trigger_beat_pulse() -> void:
	pulse_strength = 1.0
	if beat_pulse:
		beat_pulse.color = BEAT_PULSE_HIT_COLOR
		beat_pulse.scale = Vector2.ONE * 1.25

func _decay_beat_pulse(delta: float) -> void:
	pulse_strength = max(0.0, pulse_strength - delta / BEAT_PULSE_DECAY)
	if beat_pulse:
		beat_pulse.color = BEAT_PULSE_BASE_COLOR.lerp(BEAT_PULSE_HIT_COLOR, pulse_strength)
		beat_pulse.scale = Vector2.ONE * (1.0 + 0.25 * pulse_strength)

func _on_record_button_pressed() -> void:
	if listening:
		Comparator.finish_now()
		record_button.hide()
		return
	if counting_in:
		return
	_begin_count_in()

# Clicks out COUNT_IN_BEATS beats at the exercise's tempo before listening
# turns on, so you know the pulse and have a moment to get your flute up —
# no pitch detection happens until this finishes.
func _begin_count_in() -> void:
	counting_in = true
	record_button.disabled = true
	if now_label:
		now_label.text = ""
	var bpm: int = config.get("BPM", 80)
	var beat_length: float = 60.0 / float(max(bpm, 1))
	for i in range(COUNT_IN_BEATS, 0, -1):
		label.text = "Get ready... %d" % i
		label.modulate = Color.WHITE
		if beat_pulse:
			beat_pulse.color = BEAT_PULSE_HIT_COLOR
		await get_tree().create_timer(beat_length * 0.5).timeout
		if beat_pulse:
			beat_pulse.color = BEAT_PULSE_BASE_COLOR
		await get_tree().create_timer(beat_length * 0.5).timeout
	counting_in = false
	record_button.disabled = false
	_start_listening()

func _start_listening() -> void:
	listening = true
	record_button.text = "Stop"
	candidate_note = ""
	candidate_time = 0.0
	is_playing = false
	last_committed_note = ""
	note_elapsed = 0.0
	metronome_elapsed = 0.0
	pulse_strength = 0.0
	_last_shown_index = -1
	if note_progress:
		note_progress.value = 0.0
	label.text = "Go!"
	label.modulate = Color.WHITE
	Comparator.load_score(config.get("Notes", []), config.get("BPM", 80))
	_update_now_label()
	mic.play()

func _stop_listening() -> void:
	listening = false
	record_button.text = "Start Listening"
	mic.stop()

func _on_note_result(status: String, expected_pitch: String, played_pitch: String) -> void:
	match status:
		"correct":
			label.text = "GOOD — %s" % expected_pitch
			label.modulate = Color.GREEN
		"close":
			label.text = "CLOSE — expected %s, played %s" % [expected_pitch, played_pitch]
			label.modulate = Color.ORANGE
		_:
			if played_pitch == "":
				label.text = "MISS — expected %s, heard nothing" % expected_pitch
			else:
				label.text = "MISS — expected %s, heard %s" % [expected_pitch, played_pitch]
			label.modulate = Color.RED

func _on_session_finished(accuracy: float) -> void:
	_stop_listening()
	if now_label:
		now_label.text = ""
	record_button.hide()
	await get_tree().create_timer(SCORE_DISPLAY_DELAY).timeout
	label.modulate = Color.WHITE
	label.text = "Score: %.0f%%" % accuracy
	finished.emit(clampf(accuracy / 100.0, 0.0, 1.0))

func get_peak_frequency() -> Dictionary:
	var best_freq := 0.0
	var best_mag := 0.0

	for hz in range(MIN_HZ, MAX_HZ, STEP_HZ):
		var mag := spectrum.get_magnitude_for_frequency_range(hz, hz + STEP_HZ)[0]
		if mag > best_mag:
			best_mag = mag
			best_freq = hz + STEP_HZ * 0.5
	return {"freq": best_freq, "mag": best_mag}

func hz_to_midi(freq: float) -> int:
	if freq <= 0.0:
		return -1
	return int(round(69.0 + 12.0 * (log(freq / 440.0) / log(2.0))))

func midi_to_name(midi: int) -> String:
	var note_name: String = NOTES_NAME_SHARP[midi % 12]
	var octave: int = int(midi / 12.0) - 1
	return "%s%d" % [note_name, octave]

func update_stable_note(detected: String, delta: float) -> String:
	if detected != candidate_note:
		candidate_note = detected
		candidate_time = 0.0
		return ""
	candidate_time += delta
	if candidate_time >= STABLE_TIME and detected != last_committed_note:
		last_committed_note = detected
		return detected
	return ""
