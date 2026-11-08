extends Control
class_name SheetMusic

const GAP := 12.0
const SYSTEM_HEIGHT := 11.0
const HEADER_WIDTH := 4.5
const TIME_SIG_WIDTH := 2.5
const MAX_PX_PER_BEAT := 80.0
const MIN_SLOT := 3.0
const NOTE_OFFSET := 1.8
const LETTERS := "CDEFGAB"
const CLEF_TEXTURE := preload("res://icons/treble-clef.png")

const INK := Color(0.1, 0.12, 0.11)
const STAFF_COLOR := Color(0.35, 0.38, 0.36)
const CURRENT_COLOR := Color(0.1, 0.35, 0.85)
const HIGHLIGHT_COLOR := Color(1.0, 0.85, 0.2, 0.45)
const STATUS_COLORS := {
	"correct": Color(0.1, 0.6, 0.25),
	"close": Color(0.95, 0.55, 0.05),
	"miss": Color(0.85, 0.15, 0.15),
}

var notes: Array = []
var beats: Array[float] = []
var beats_per_bar: int = 4
var current_index: int = -1
var results: Dictionary = {}	#note index -> "correct" / "close" / "miss"

var _scale := 1.0
var _systems: Array = []
var _note_layout: Array = []

func _ready() -> void:
	resized.connect(_relayout)

func set_score(p_notes: Array, p_beats: Array, p_beats_per_bar: int = 4) -> void:
	notes = p_notes.duplicate()
	beats.clear()
	for i in range(notes.size()):
		beats.append(float(p_beats[i]) if i < p_beats.size() else 1.0)
	beats_per_bar = max(p_beats_per_bar, 1)
	current_index = -1
	results.clear()
	_relayout()

func set_current(index: int) -> void:
	if index != current_index:
		current_index = index
		queue_redraw()

func set_result(index: int, status: String) -> void:
	results[index] = status
	queue_redraw()

func reset_results() -> void:
	results.clear()
	queue_redraw()

func _relayout() -> void:
	_scale = 1.0
	while true:
		_build_layout(size.x / _scale)
		var needed := _systems.size() * SYSTEM_HEIGHT * GAP * _scale
		if needed <= size.y or _scale <= 0.4 or size.y <= 0.0:
			break
		_scale -= 0.05
	queue_redraw()

func _split_bars() -> Array:
	var bars: Array = []
	var bar: Array = []
	var count := 0.0
	var next_bar := float(beats_per_bar)
	for i in range(notes.size()):
		bar.append(i)
		count += beats[i]
		if count >= next_bar - 0.001:
			bars.append(bar)
			bar = []
			while next_bar <= count + 0.001:
				next_bar += beats_per_bar
	if not bar.is_empty():
		bars.append(bar)
	return bars

func _slot_width(b: float, px_per_beat: float) -> float:
	return maxf(b * px_per_beat, MIN_SLOT * GAP)

func _bars_width(bar_list: Array, px_per_beat: float) -> float:
	var w := 0.0
	for bar in bar_list:
		for i in bar:
			w += _slot_width(beats[i], px_per_beat)
	return w

func _header_width(first_line: bool) -> float:
	return (HEADER_WIDTH + (TIME_SIG_WIDTH if first_line else 0.0)) * GAP

func _build_layout(width: float) -> void:
	_systems.clear()
	_note_layout.clear()
	_note_layout.resize(notes.size())
	if notes.is_empty():
		return
		
	var min_ppb := MIN_SLOT * GAP
	var lines: Array = []
	var line: Array = []
	for bar in _split_bars():
		var header := _header_width(lines.is_empty())
		if not line.is_empty() and header + _bars_width(line + [bar], min_ppb) > width - GAP:
			lines.append(line)
			line = []
		line.append(bar)
	if not line.is_empty():
		lines.append(line)

	var total_height := lines.size() * SYSTEM_HEIGHT * GAP
	var top := maxf(0.0, (size.y / _scale - total_height) * 0.5)

	for li in range(lines.size()):
		var line_bars: Array = lines[li]
		var header := _header_width(li == 0)
		var avail := width - header - GAP
		var ppb := MAX_PX_PER_BEAT
		while ppb > min_ppb and _bars_width(line_bars, ppb) > avail:
			ppb -= 1.0
		var x := header
		var barlines: Array = []
		for bar in line_bars:
			for i in bar:
				_note_layout[i] = {"system": li, "x": x + NOTE_OFFSET * GAP}
				x += _slot_width(beats[i], ppb)
			barlines.append(x)
		_systems.append({
			"y": top + (li + 0.5) * SYSTEM_HEIGHT * GAP,
			"end_x": x,
			"barlines": barlines,
			"final": li == lines.size() - 1,
		})

func _draw() -> void:
	if notes.is_empty() or _systems.is_empty():
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_scale, _scale))

	if current_index >= 0 and current_index < notes.size() and not results.has(current_index):
		var lay: Dictionary = _note_layout[current_index]
		var cy: float = _systems[lay["system"]]["y"]
		draw_rect(Rect2(lay["x"] - 1.5 * GAP, cy - 3.75 * GAP, 3.0 * GAP, 7.5 * GAP), HIGHLIGHT_COLOR)

	for si in range(_systems.size()):
		_draw_staff(_systems[si], si == 0)
	for i in range(notes.size()):
		_draw_note(i)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _step_y(cy: float, step: int) -> float:
	return cy - (step - 4) * GAP * 0.5

func _draw_staff(sys: Dictionary, first_line: bool) -> void:
	var cy: float = sys["y"]
	var end_x: float = sys["end_x"]
	for k in range(5):
		var y := cy + (k - 2) * GAP
		draw_line(Vector2(GAP * 0.3, y), Vector2(end_x, y), STAFF_COLOR, 1.0, true)

	_draw_clef(Vector2(GAP * 2.2, cy + 2.0 * GAP))

	if first_line:
		_draw_time_signature(Vector2(HEADER_WIDTH * GAP, cy))

	var top := cy - 2.0 * GAP
	var bottom := cy + 2.0 * GAP
	var barlines: Array = sys["barlines"]
	for bi in range(barlines.size()):
		var bx: float = barlines[bi]
		if sys["final"] and bi == barlines.size() - 1:
			draw_line(Vector2(bx - 5.0, top), Vector2(bx - 5.0, bottom), INK, 1.2)
			draw_line(Vector2(bx - 1.5, top), Vector2(bx - 1.5, bottom), INK, 3.0)
		else:
			draw_line(Vector2(bx, top), Vector2(bx, bottom), INK, 1.2)

func _draw_clef(origin: Vector2) -> void:
	var height := 7.5 * GAP
	var width := height * CLEF_TEXTURE.get_width() / CLEF_TEXTURE.get_height()
	draw_texture_rect(CLEF_TEXTURE, Rect2(origin.x - width * 0.5, origin.y - 5.8 * GAP, width, height), false)

func _draw_time_signature(pos: Vector2) -> void:
	var font := get_theme_default_font()
	var fs := int(GAP * 2.8)
	var text := str(beats_per_bar)
	var w := TIME_SIG_WIDTH * GAP
	for baseline in [pos.y, pos.y + 2.0 * GAP]:
		var p := Vector2(pos.x, baseline)
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, 2, INK)
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, INK)

func _draw_note(i: int) -> void:
	var lay: Dictionary = _note_layout[i]
	var cy: float = _systems[lay["system"]]["y"]
	var x: float = lay["x"]
	var parsed := _parse(notes[i])
	var step: int = parsed["step"]
	var y := _step_y(cy, step)
	var dur := _duration(beats[i])

	var color := INK
	if results.has(i):
		color = STATUS_COLORS.get(results[i], INK)
	elif i == current_index:
		color = CURRENT_COLOR

	var rx := GAP * (0.72 if dur["kind"] == "whole" else 0.62)
	_draw_head(Vector2(x, y), rx, dur["filled"], color)

	if dur["kind"] != "whole":
		var up := step < 4
		var sx := x + rx - 0.7 if up else x - rx + 0.7
		var end_y := minf(y - 3.5 * GAP, cy) if up else maxf(y + 3.5 * GAP, cy)
		draw_line(Vector2(sx, y), Vector2(sx, end_y), color, 1.4, true)

	if dur["dotted"]:
		var dot_y := y - GAP * 0.5 if posmod(step, 2) == 0 else y
		draw_circle(Vector2(x + rx + 0.5 * GAP, dot_y), 0.18 * GAP, color)

	match parsed["acc"]:
		"#":
			_draw_sharp(Vector2(x - 1.45 * GAP, y), color)
		"b":
			_draw_flat(Vector2(x - 1.4 * GAP, y), color)

func _draw_head(c: Vector2, rx: float, filled: bool, color: Color) -> void:
	var ry := GAP * 0.45
	var pts := PackedVector2Array()
	for k in range(24):
		var a := TAU * k / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(-0.35))
	if filled:
		draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, color, 1.0 if filled else 2.0, true)

func _draw_sharp(c: Vector2, color: Color) -> void:
	var g := GAP
	draw_line(c + Vector2(-0.22 * g, -1.1 * g), c + Vector2(-0.22 * g, 1.2 * g), color, 1.2)
	draw_line(c + Vector2(0.22 * g, -1.2 * g), c + Vector2(0.22 * g, 1.1 * g), color, 1.2)
	draw_line(c + Vector2(-0.5 * g, -0.25 * g), c + Vector2(0.5 * g, -0.5 * g), color, 2.4)
	draw_line(c + Vector2(-0.5 * g, 0.5 * g), c + Vector2(0.5 * g, 0.25 * g), color, 2.4)

func _draw_flat(c: Vector2, color: Color) -> void:
	var g := GAP
	draw_line(c + Vector2(-0.3 * g, -1.6 * g), c + Vector2(-0.3 * g, 0.5 * g), color, 1.4, true)
	draw_arc(c + Vector2(-0.3 * g, 0.2 * g), 0.3 * g, -PI * 0.5, PI * 0.5, 10, color, 1.6, true)

func _parse(note_name: String) -> Dictionary:
	var n := note_name.strip_edges()
	if n.is_empty():
		return {"step": 4, "acc": ""}
	var letter_index := LETTERS.find(n[0].to_upper())
	if letter_index == -1:
		return {"step": 4, "acc": ""}
	var rest := n.substr(1)
	var acc := ""
	if rest.begins_with("#") or rest.begins_with("b"):
		acc = rest[0]
		rest = rest.substr(1)
	var octave := int(rest) if rest.is_valid_int() else 4
	return {"step": octave * 7 + letter_index - 30, "acc": acc}

func _duration(b: float) -> Dictionary:
	const TABLE := [
		[4.0, "whole", false], [3.0, "half", true], [2.0, "half", false],
		[1.5, "quarter", true], [1.0, "quarter", false], [0.75, "eighth", true],
		[0.5, "eighth", false], [0.375, "16th", true], [0.25, "16th", false],
	]
	var best: Array = TABLE[4]
	for entry in TABLE:
		if absf(b - entry[0]) < absf(b - best[0]):
			best = entry
	var kind: String = best[1]
	return {
		"kind": kind,
		"filled": kind != "whole" and kind != "half",
		"dotted": best[2],
	}
