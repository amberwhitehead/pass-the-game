extends Node2D
## A hand-drawn speech bubble in stage space. `show_line()` types the text out and
## returns once the player clicks (or, for `auto`, after a reading pause).

const Ink := preload("res://minigames/workshop/ink.gd")
const Style := preload("res://ui/game_style.gd")

signal dismissed

const MAX_WIDTH := 460.0
const PAD := Vector2(22, 16)
const FONT_SIZE := 22
const LINE_H := 29.0

var _text := ""
var _speaker := ""
var _anchor := Vector2.ZERO       ## Where the tail points (the speaker's mouth).
var _shown := 0.0
var _box := Rect2()
var _lines: PackedStringArray = []   ## The text, already wrapped.
var _tint := Color("fffaf0")
var _waiting := false
var _auto := 0.0
var _side := 1.0
var _boil := -1


func _ready() -> void:
	visible = false
	z_index = 50


## Shows `text` from a speaker whose mouth is at `anchor`; resolves when dismissed.
## The bubble sits beside the speaker, on `side` (1 right, -1 left).
func show_line(speaker: String, text: String, anchor: Vector2, tint := Color("fffaf0"), auto := 0.0, side := 1.0) -> void:
	_side = side
	_speaker = speaker
	_text = text
	_anchor = anchor
	_tint = tint
	_shown = 0.0
	_auto = auto
	_layout()
	visible = true
	_waiting = true
	queue_redraw()
	await dismissed
	visible = false


## Waits for a click without showing anything (e.g. while something is zoomed in).
func wait_click() -> void:
	_text = ""
	_lines = PackedStringArray()
	_box = Rect2()
	_shown = 0.0
	_auto = 0.0
	_waiting = true
	queue_redraw()
	await dismissed


## Click: finish typing first, then dismiss.
func advance() -> bool:
	if not _waiting:
		return false
	if _shown < _text.length():
		_shown = _text.length()
		queue_redraw()
		return true
	_waiting = false
	dismissed.emit()
	return true


func is_open() -> bool:
	return _waiting


func _process(delta: float) -> void:
	if not _waiting:
		return
	if _shown < _text.length():
		_shown = minf(_text.length(), _shown + delta * 55.0)
		queue_redraw()
	elif _auto > 0.0:
		_auto -= delta
		if _auto <= 0.0:
			_waiting = false
			dismissed.emit()
	var f := Ink.boil_frame()
	if f != _boil:
		_boil = f
		queue_redraw()


func _layout() -> void:
	_lines = wrap_words(_text, Style.font(), FONT_SIZE, MAX_WIDTH)
	var widest := 0.0
	for l in _lines:
		widest = maxf(widest, Style.font().get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	var name_h := 24.0 if _speaker != "" else 0.0
	# A little slack: glyphs drawn at the stage's scale can come out a touch wider.
	var box_size := Vector2(widest * 1.06 + 8.0, _lines.size() * LINE_H) + PAD * 2.0 + Vector2(0, name_h)
	box_size.x = maxf(box_size.x, 210.0)
	var pos := _anchor + Vector2(60.0 if _side > 0.0 else -60.0 - box_size.x, -box_size.y * 0.75)
	pos.x = clampf(pos.x, 20, 1580 - box_size.x)
	pos.y = clampf(pos.y, 16, 880 - box_size.y)
	_box = Rect2(pos, box_size)


## Splits `text` into lines no wider than `width`, breaking between words.
static func wrap_words(text: String, font: Font, size: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var trial := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			out.append(line)
			line = word
		else:
			line = trial
	if line != "":
		out.append(line)
	return out


func _draw() -> void:
	if _box.size == Vector2.ZERO:
		return
	var edge_x := _box.position.x + 4 if _anchor.x < _box.position.x else _box.end.x - 4
	var mid_y := clampf(_anchor.y, _box.position.y + 26, _box.end.y - 26)
	var tail_base := Vector2(edge_x, mid_y)
	var tail_tip := _anchor + (tail_base - _anchor).normalized() * 14.0
	var bubble := Ink.rrect(_box, 22)
	Ink.shape(self, bubble, _tint, 3.5, 900, 0.0, 0.05)
	var tri := PackedVector2Array([tail_base + Vector2(0, -13), tail_tip, tail_base + Vector2(0, 13)])
	Ink.shape(self, tri, _tint, 0.0, 901, 0.0, 0.0)
	Ink.line(self, tri, Ink.OUTLINE, 3.5, 902)
	var y := _box.position.y + PAD.y
	if _speaker != "":
		draw_string(Style.font(true), Vector2(_box.position.x + PAD.x, y + 16), _speaker.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("b0552a"))
		y += 24.0
	# Type the wrapped lines out character by character, each drawn without re-wrapping.
	var left := int(_shown)
	for l in _lines:
		if left <= 0:
			break
		y += LINE_H
		draw_string(Style.font(), Vector2(_box.position.x + PAD.x, y - 6.0), l.substr(0, left), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Ink.OUTLINE)
		left -= l.length() + 1
	if _shown >= _text.length() and _auto <= 0.0:
		var p := Vector2(_box.end.x - 22, _box.end.y - 14 + sin(Time.get_ticks_msec() / 200.0) * 2.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -4), p + Vector2(6, -4), p + Vector2(0, 4)]), Color("b0552a"))
