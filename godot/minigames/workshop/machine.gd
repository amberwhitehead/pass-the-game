extends Node2D
## The Engineer's Chrono-Oscillator: a steel cabinet of tubes and meters, a destination
## dial, a big red lever and a brass portal ring. Each part is its own hotspot (a child
## Thing); they share this node's state.

const Thing := preload("res://minigames/workshop/thing.gd")
const P := preload("res://minigames/workshop/palette.gd")
const Ink := preload("res://minigames/workshop/ink.gd")
const Small := preload("res://minigames/workshop/small_props.gd")

const PORTAL_CENTER := Vector2(1452, 498)
const PORTAL_RADII := Vector2(104, 150)
const PORTAL_FLOOR := Vector2(1452, 664)
const LEVER_PIVOT := Vector2(1300, 560)
const LEVER_TOP := Vector2(1300, 470)   ## Where a cat lands to pull the lever.

var powered := false:
	set(v):
		powered = v
		_redraw()
## The destination time, in minutes after midnight on a 12-hour face (0..719).
var dial := 3 * 60:
	set(v):
		dial = posmod(v, 720)
		_redraw()
var lever_down := false:
	set(v):
		lever_down = v
		_redraw()
var fuse_blown := true      ## The socket holds a burnt-out fuse until the wire replaces it.
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
	return time_label(dial)


## "3:07" for minutes after midnight.
static func time_label(minutes: int) -> String:
	var h := (posmod(minutes, 720) / 60)
	return "%d:%02d" % [12 if h == 0 else h, posmod(minutes, 60)]


## Turns one of the dial's number wheels on by one: 0 hours, 1 tens of minutes, 2 minutes.
func turn_wheel(wheel: int) -> void:
	var h := dial / 60
	var tens := (dial % 60) / 10
	var ones := dial % 10
	match wheel:
		0: h = (h + 1) % 12
		1: tens = (tens + 1) % 6
		2: ones = (ones + 1) % 10
	dial = h * 60 + tens * 10 + ones


func _redraw() -> void:
	for c in get_children():
		c.queue_redraw()


class Cabinet extends Thing:
	func _init() -> void:
		id = "machine"
		hover_name = "Fuse socket"
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
			var c := Vector2(1226 + k * 38, 640)
			Ink.dot(self, c, 14, P.CREAM, 2.5, 210 + k, 0.1, 0.1)
			var a := -PI * 0.75 + (0.5 + 0.4 * sin(m.time() * (2.0 + k)) if on else 0.0) * PI * 0.5
			Ink.line(self, PackedVector2Array([c, c + Vector2(cos(a), sin(a)) * 14]), P.RED, 2.0, 212 + k, 0.3)
		# Fuse socket.
		Ink.shape(self, Ink.rrect(Rect2(1200, 476, 52, 20), 5), Color("2a2a2a"), 2.5, 214, 0.0)
		if on:
			# Copper wire bridging the socket, sparking now and then.
			Ink.line(self, PackedVector2Array([Vector2(1202, 486), Vector2(1214, 478), Vector2(1226, 494), Vector2(1238, 478), Vector2(1250, 486)]), Color("c8703f"), 3.5, 215)
			if sin(m.time() * 13.0) > 0.85:
				draw_circle(Vector2(1226, 480), 5, Color(1, 0.95, 0.6, 0.9))
		elif m.fuse_blown:
			Ink.shape(self, Ink.rrect(Rect2(1206, 479, 40, 14), 6), Color(0.35, 0.33, 0.3, 0.9), 2.0, 216, 0.2)
			Ink.line(self, PackedVector2Array([Vector2(1212, 486), Vector2(1222, 482)]), Color("222222"), 2.0, 218)
			Ink.line(self, PackedVector2Array([Vector2(1230, 489), Vector2(1240, 486)]), Color("222222"), 2.0, 219)
		Ink.dot(self, Vector2(1268, 486), 6, P.RED.lightened(0.3) if on else Color("552222"), 2.0, 217, 0.4)
		# Rivets.
		for p in [Vector2(1072, 640), Vector2(1278, 640), Vector2(1072, 478), Vector2(1278, 520)]:
			draw_circle(p, 3.0, Color("2f4e54"))


class Dial extends Thing:
	## The three number wheels of the destination counter: hours, tens, minutes.
	const WHEELS := [Rect2(1088, 600, 40, 34), Rect2(1140, 600, 26, 34), Rect2(1168, 600, 26, 34)]

	func _init() -> void:
		id = "dial"
		hover_name = "Destination counter"
		hit_rect = Rect2(1078, 480, 124, 160)

	## Which wheel a stage point is on, or -1.
	func wheel_at(stage_point: Vector2) -> int:
		for k in WHEELS.size():
			if WHEELS[k].grow(4).has_point(stage_point):
				return k
		return -1

	func _paint() -> void:
		var m = get_meta("machine")
		var c := Vector2(1134, 536)
		Ink.dot(self, c, 48, P.CHROME, 3.0, 220, 0.25, 0.15)
		Ink.dot(self, c, 40, P.CREAM, 2.5, 221, 0.05, 0.1)
		for k in 12:
			var a := TAU * k / 12.0 - PI / 2.0
			draw_line(c + Vector2(cos(a), sin(a)) * 31, c + Vector2(cos(a), sin(a)) * 37, Ink.OUTLINE, 2.0)
		# Hands show the destination time.
		var mins: int = m.dial
		var ha := TAU * float(mins % 720) / 720.0 - PI / 2.0
		var ma := TAU * float(mins % 60) / 60.0 - PI / 2.0
		Ink.line(self, PackedVector2Array([c, c + Vector2(cos(ha), sin(ha)) * 20]), Ink.OUTLINE, 4.0, 222, 0.3)
		Ink.line(self, PackedVector2Array([c, c + Vector2(cos(ma), sin(ma)) * 30]), P.RED, 2.5, 223, 0.3)
		Ink.dot(self, c, 5, Ink.OUTLINE, 0.0, 224, 0.0, 0.0)
		draw_string(Style.font(true), Vector2(c.x - 50, c.y + 55), "DESTINATION", HORIZONTAL_ALIGNMENT_CENTER, 100, 9, P.CREAM)
		# The counter: three wheels in a dark window.
		Ink.shape(self, Ink.rrect(Rect2(1082, 596, 118, 42), 6), Color("1f2a2c"), 2.5, 225, 0.0)
		var label: String = m.dial_label()
		var parts := label.split(":")
		var texts := [parts[0], parts[1].substr(0, 1), parts[1].substr(1, 1)]
		var lit := Color("9dffb0") if m.powered else Color("6f8a72")
		for k in 3:
			var r: Rect2 = WHEELS[k]
			Ink.shape(self, Ink.rrect(r, 4), Color("2c3a3c"), 1.5, 226 + k, 0.15, 0.0)
			draw_string(Style.font(), Vector2(r.position.x, r.position.y + 26), texts[k], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, lit)
		draw_string(Style.font(), Vector2(1128, 626), ":", HORIZONTAL_ALIGNMENT_CENTER, 12, 22, lit)


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

