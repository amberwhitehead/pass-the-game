extends Control
## A drawn controller button, shaped and coloured like the real one on the player's pad.
##
##   button: "a" "b" "x" "y" (face buttons by position: bottom, right, left, top),
##           "l1" "r1" (shoulders), "l2" "r2" (triggers), "start".
##   kind:   "playstation" (✕ ○ □ △ in their colours, L1/R1, L2/R2, OPTIONS),
##           "xbox" (green A, red B, blue X, yellow Y, LB/RB, LT/RT, ☰),
##           "generic" (a plain circle for a face button, which marks its position,
##           and a plain rectangle for a shoulder or trigger).
## PadLabels.kind(device) tells which kind a connected pad is.

const Style := preload("res://ui/game_style.gd")

const FACE := ["a", "b", "x", "y"]
const PS_COLORS := {"a": Color("7fb2f0"), "b": Color("ff6b6b"), "x": Color("eb8fd8"), "y": Color("3fd1a8")}
const XBOX_COLORS := {"a": Color("5fb946"), "b": Color("e24a3b"), "x": Color("2f7fe0"), "y": Color("f2c230")}
const XBOX_NAMES := {"a": "A", "b": "B", "x": "X", "y": "Y", "l1": "LB", "r1": "RB", "l2": "LT", "r2": "RT", "start": "☰"}
const PS_NAMES := {"l1": "L1", "r1": "R1", "l2": "L2", "r2": "R2", "start": "OPTIONS"}
const BODY := Color("1c2328")
const RIM := Color("c9d3d6")

var button := "a":
	set(value):
		button = value
		_resize()
var kind := "generic":
	set(value):
		kind = value
		_resize()
## Height in pixels; widths follow from the button's shape.
var glyph_height := 20.0:
	set(value):
		glyph_height = value
		_resize()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize()


## The size this glyph wants for its button and height.
static func size_for(which: String, of_kind: String, height: float) -> Vector2:
	if which in FACE:
		return Vector2(height, height)
	if which == "start":
		return Vector2(height * (2.6 if of_kind == "playstation" else 1.3), height)
	return Vector2(height * 1.55, height)


func _resize() -> void:
	custom_minimum_size = size_for(button, kind, glyph_height)
	queue_redraw()


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	if button in FACE:
		_draw_face(box)
	elif button in ["l1", "r1"]:
		_draw_shoulder(box, false)
	elif button in ["l2", "r2"]:
		_draw_shoulder(box, true)
	else:
		_draw_pill(box)


func _draw_face(box: Rect2) -> void:
	var c := box.get_center()
	var r := minf(box.size.x, box.size.y) * 0.5 - 1.0
	match kind:
		"playstation":
			draw_circle(c, r, BODY)
			draw_arc(c, r, 0, TAU, 32, RIM, 1.2, true)
			var col: Color = PS_COLORS[button]
			var s := r * 0.48
			var w := maxf(1.6, r * 0.16)
			match button:
				"a":
					draw_line(c + Vector2(-s, -s), c + Vector2(s, s), col, w, true)
					draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, w, true)
				"b":
					draw_arc(c, s, 0, TAU, 24, col, w, true)
				"x":
					draw_rect(Rect2(c - Vector2(s, s) * 0.9, Vector2(s, s) * 1.8), col, false, w)
				"y":
					var t := PackedVector2Array([c + Vector2(0, -s * 1.05), c + Vector2(s * 1.05, s * 0.75), c + Vector2(-s * 1.05, s * 0.75), c + Vector2(0, -s * 1.05)])
					draw_polyline(t, col, w, true)
		"xbox":
			draw_circle(c, r, XBOX_COLORS[button])
			draw_arc(c, r, 0, TAU, 32, Color(0, 0, 0, .35), 1.0, true)
			_text(c, XBOX_NAMES[button], r * 1.15, Color("151515") if button == "y" else Color.WHITE)
		_:
			# Unknown pad: a plain circle, with a dot showing which of the four it is.
			draw_circle(c, r, Color("39454a"))
			draw_arc(c, r, 0, TAU, 32, RIM, 1.2, true)
			var offsets := {"a": Vector2(0, 1), "b": Vector2(1, 0), "x": Vector2(-1, 0), "y": Vector2(0, -1)}
			for key: String in offsets:
				var at: Vector2 = c + offsets[key] * r * 0.5
				if key == button:
					draw_circle(at, r * 0.24, Color.WHITE)
				else:
					draw_arc(at, r * 0.2, 0, TAU, 12, Color(1, 1, 1, .45), 1.0, true)


## A shoulder button is a flat rounded bar; a trigger is taller with a rounded top.
func _draw_shoulder(box: Rect2, trigger: bool) -> void:
	var body := StyleBoxFlat.new()
	body.bg_color = BODY if kind != "generic" else Color("39454a")
	body.border_color = RIM
	body.set_border_width_all(1)
	body.anti_aliasing = true
	if trigger:
		body.corner_radius_top_left = int(box.size.y * 0.5)
		body.corner_radius_top_right = int(box.size.y * 0.5)
		body.corner_radius_bottom_left = 3
		body.corner_radius_bottom_right = 3
		draw_style_box(body, box)
	else:
		body.set_corner_radius_all(int(box.size.y * 0.3))
		draw_style_box(body, Rect2(box.position + Vector2(0, box.size.y * 0.12), box.size * Vector2(1, 0.76)))
	var label := ""
	match kind:
		"playstation":
			label = PS_NAMES[button]
		"xbox":
			label = XBOX_NAMES[button]
		_:
			label = button.to_upper()  # L1 / R1 / L2 / R2 on an unknown pad too.
	_text(box.get_center() + Vector2(0, box.size.y * (0.06 if trigger else 0.0)), label, box.size.y * 0.55, Color.WHITE)


func _draw_pill(box: Rect2) -> void:
	var body := StyleBoxFlat.new()
	body.bg_color = BODY
	body.border_color = RIM
	body.set_border_width_all(1)
	body.set_corner_radius_all(int(box.size.y * 0.5))
	body.anti_aliasing = true
	draw_style_box(body, box)
	var label: String = PS_NAMES.get(button, "") if kind == "playstation" else XBOX_NAMES.get(button, "")
	_text(box.get_center(), label, box.size.y * (0.42 if kind == "playstation" else 0.6), Color.WHITE)


func _text(center: Vector2, text: String, font_size: float, color: Color) -> void:
	if text == "":
		return
	var font := Style.font(true)
	var px := maxi(6, int(font_size))
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	var baseline := center.y + (font.get_ascent(px) - font.get_descent(px)) * 0.5
	draw_string(font, Vector2(center.x - sz.x * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
