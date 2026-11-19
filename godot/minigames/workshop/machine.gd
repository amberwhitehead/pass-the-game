extends Node2D
## The Engineer's Chrono-Oscillator: a steel cabinet of tubes and meters, a destination
## dial, a big red lever and a brass portal ring. Each part is its own hotspot (a child
## Thing); they share this node's state.

const Thing := preload("res://minigames/workshop/thing.gd")
const P := preload("res://minigames/workshop/palette.gd")
const Ink := preload("res://minigames/workshop/ink.gd")
const Small := preload("res://minigames/workshop/small_props.gd")

const DIAL_SETTINGS := ["LAST TUESDAY", "A MOMENT AGO", "1955", "THE ICE AGE", "TOMORROW", "NEVER"]
const PORTAL_CENTER := Vector2(1452, 498)
const PORTAL_RADII := Vector2(104, 150)
const PORTAL_FLOOR := Vector2(1452, 664)
const LEVER_PIVOT := Vector2(1300, 560)
const LEVER_TOP := Vector2(1300, 470)   ## Where a cat lands to pull the lever.

var powered := false:
	set(v):
		powered = v
		_redraw()
var dial := 0:
	set(v):
		dial = posmod(v, DIAL_SETTINGS.size())
		_redraw()
var lever_down := false:
	set(v):
		lever_down = v
		_redraw()
var portal := 0.0           ## 0 closed .. 1 fully open
var portal_unstable := false

var cabinet: Thing
var dial_part: Thing
var lever: Thing
var ring: Thing
var _t := 0.0


func _ready() -> void:
	ring = _part(Ring.new())
	cabinet = _part(Cabinet.new())
	dial_part = _part(Dial.new())
	lever = _part(Lever.new())


func _part(t: Thing) -> Thing:
	t.set_meta("machine", self)
	add_child(t)
	return t


func _process(delta: float) -> void:
	_t += delta


func time() -> float:
	return _t


func dial_label() -> String:
	return DIAL_SETTINGS[dial]


func _redraw() -> void:
	for c in get_children():
		c.queue_redraw()


class Cabinet extends Thing:
	func _init() -> void:
		id = "machine"
		hover_name = "Chrono-Oscillator"
		hit_rect = Rect2(1196, 448, 60, 50)

	func _paint() -> void:
		var m = get_meta("machine")
		var on: bool = m.powered
		# Cables to the ring.
		Ink.line(self, PackedVector2Array([Vector2(1280, 640), Vector2(1320, 655), Vector2(1370, 650)]), Color("2d2d2d"), 7.0, 200)
		Ink.line(self, PackedVector2Array([Vector2(1270, 430), Vector2(1320, 380), Vector2(1352, 400)]), Color("2d2d2d"), 6.0, 201)
		# Body.
		Ink.shape(self, Ink.rrect(Rect2(1060, 420, 230, 244), 14), Color("4f7f86"), 3.5, 202, 0.18, 0.18)
		Ink.shape(self, Ink.rrect(Rect2(1072, 432, 206, 34), 8), Color("2f4e54"), 2.5, 203, 0.0, 0.1)
		draw_string(Style.font(true), Vector2(1082, 455), "CHRONO-OSCILLATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, P.CREAM if on else P.CREAM.darkened(0.4))
		# Tubes on top.
		for k in 4:
			var x := 1090.0 + k * 50.0
			var glow := on and (sin(m.time() * 6.0 + k) > -0.6)
			Small.Radio._tube(self, Vector2(x, 420), 1.15, 204 + k, glow)
			if glow:
				draw_circle(Vector2(x, 395), 16, Color(1.0, 0.7, 0.35, 0.18))
		# Two meters.
		for k in 2:
			var c := Vector2(1205 + k * 46, 600)
			Ink.dot(self, c, 18, P.CREAM, 2.5, 210 + k, 0.1, 0.1)
			var a := -PI * 0.75 + (0.5 + 0.4 * sin(m.time() * (2.0 + k)) if on else 0.0) * PI * 0.5
			Ink.line(self, PackedVector2Array([c, c + Vector2(cos(a), sin(a)) * 14]), P.RED, 2.0, 212 + k, 0.3)
		# Fuse socket.
		Ink.shape(self, Ink.rrect(Rect2(1200, 476, 52, 20), 5), Color("2a2a2a"), 2.5, 214, 0.0)
		if on:
			Ink.shape(self, Ink.rrect(Rect2(1206, 479, 40, 14), 6), Color(0.85, 0.95, 1.0, 0.85), 2.0, 215, 0.4)
			Ink.line(self, PackedVector2Array([Vector2(1212, 486), Vector2(1240, 486)]), P.ORANGE, 2.0, 216)
		Ink.dot(self, Vector2(1268, 486), 6, P.RED.lightened(0.3) if on else Color("552222"), 2.0, 217, 0.4)
		# Rivets.
		for p in [Vector2(1072, 640), Vector2(1278, 640), Vector2(1072, 478), Vector2(1278, 520)]:
			draw_circle(p, 3.0, Color("2f4e54"))


class Dial extends Thing:
	func _init() -> void:
		id = "dial"
		hover_name = "Destination dial"
		hit_rect = Rect2(1078, 480, 112, 112)

	func _paint() -> void:
		var m = get_meta("machine")
		var c := Vector2(1134, 538)
		Ink.dot(self, c, 52, P.CHROME, 3.0, 220, 0.25, 0.15)
		Ink.dot(self, c, 44, P.CREAM, 2.5, 221, 0.05, 0.1)
		var n := DIAL_SETTINGS.size()
		for k in n:
			var a := _angle(k, n)
			var tick := c + Vector2(cos(a), sin(a)) * 40
			draw_line(c + Vector2(cos(a), sin(a)) * 34, tick, Ink.OUTLINE, 2.5 if k == m.dial else 1.5)
			draw_circle(c + Vector2(cos(a), sin(a)) * 28, 2.0, P.RED if k == m.dial else P.STEEL)
		var a := _angle(m.dial, n)
		Ink.shape(self, PackedVector2Array([c + Vector2(cos(a + 1.6), sin(a + 1.6)) * 6, c + Vector2(cos(a), sin(a)) * 32,
			c + Vector2(cos(a - 1.6), sin(a - 1.6)) * 6]), P.RED, 2.0, 222, 0.2)
		Ink.dot(self, c, 7, Ink.OUTLINE, 0.0, 223, 0.0, 0.0)
		var plate := Rect2(c.x - 62, c.y + 56, 124, 22)
		Ink.shape(self, Ink.rrect(plate, 5), Color("1f2a2c"), 2.0, 224, 0.0)
		draw_string(Style.font(), Vector2(plate.position.x, plate.position.y + 16), m.dial_label(), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 12,
			Color("9dffb0") if m.powered else Color("4f6650"))

	static func _angle(k: int, n: int) -> float:
		return PI * 0.8 + (PI * 1.4) * float(k) / float(n - 1)


class Lever extends Thing:
	func _init() -> void:
		id = "lever"
		hover_name = "Lever"
		hit_rect = Rect2(1282, 440, 46, 140)

	func _paint() -> void:
		var m = get_meta("machine")
		Ink.shape(self, Ink.rrect(Rect2(LEVER_PIVOT.x - 14, LEVER_PIVOT.y - 30, 28, 60), 6), Color("2f4e54"), 2.5, 230, 0.1)
		var a := 0.9 if m.lever_down else -0.12
		var tip := LEVER_PIVOT + Vector2(sin(a), -cos(a)) * 86
		Ink.line(self, PackedVector2Array([LEVER_PIVOT, tip]), P.CHROME, 9.0, 231, 0.4)
		Ink.dot(self, tip, 14, P.RED, 3.0, 232, 0.35, 0.15)
		Ink.dot(self, LEVER_PIVOT, 8, P.STEEL, 2.5, 233)


class Ring extends Thing:
	func _init() -> void:
		id = "portal"
		hover_name = "Portal ring"
		hit_rect = Rect2(PORTAL_CENTER - PORTAL_RADII - Vector2(16, 16), PORTAL_RADII * 2.0 + Vector2(32, 32))

	func _tick(_delta: float) -> void:
		queue_redraw()

	func _paint() -> void:
		var m = get_meta("machine")
		var c := PORTAL_CENTER
		var r := PORTAL_RADII
		# Base.
		Ink.shape(self, PackedVector2Array([Vector2(c.x - 90, 664), Vector2(c.x - 70, 630), Vector2(c.x + 70, 630), Vector2(c.x + 90, 664)]),
			Color("3c3c3c"), 3.0, 240, 0.15)
		var open: float = m.portal
		if open > 0.01:
			_swirl(c, r * open, m.time(), open, m.portal_unstable)
		# The ring itself: a thick brass band with ink on both edges.
		var mid := Ink.wobble(Ink.ellipse(c, r + Vector2(9, 9), 48), 0.8, 241)
		mid.append(mid[0])
		draw_polyline(mid, Ink.OUTLINE, 24.0, true)
		draw_polyline(mid, P.BRASS, 18.0, true)
		var shine := Ink.ellipse(c, r + Vector2(5, 5), 30, PI * 1.05, PI * 1.45)
		draw_polyline(shine, P.BRASS.lightened(0.35), 4.0, true)
		# Bolts around the ring.
		for k in 10:
			var a := TAU * k / 10.0
			var p := c + Vector2(cos(a) * (r.x + 9), sin(a) * (r.y + 9))
			var lit: bool = m.powered and open > 0.01
			Ink.dot(self, p, 5, P.PORTAL if lit else P.BRASS.darkened(0.25), 1.5, 242 + k, 0.4)

	func _swirl(c: Vector2, r: Vector2, t: float, open: float, unstable: bool) -> void:
		draw_colored_polygon(Ink.ellipse(c, r, 40), P.PORTAL_DEEP.lerp(Color.BLACK, 0.3))
		for k in 7:
			var f := 1.0 - float(k) / 7.0
			var spin := t * (1.5 + k * 0.4) * (1.0 if k % 2 == 0 else -1.0)
			var rr := r * f
			var pts := Ink.ellipse(c, rr, 32, spin, spin + PI * 1.4)
			var col := P.PORTAL.lerp(P.PORTAL_DEEP, float(k) / 7.0)
			if unstable:
				col = col.lerp(P.ALARM, 0.35 + 0.35 * sin(t * 9.0))
			draw_polyline(pts, Color(col, 0.9 * open), 5.0 - k * 0.4, true)
		draw_circle(c, 18 * open, Color(1, 1, 1, 0.8 * open))

