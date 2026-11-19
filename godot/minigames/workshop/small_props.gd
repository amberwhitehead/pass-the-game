extends RefCounted
## The Workshop's smaller hotspots, one inner class each: the radio, the coffee can, the
## knitting basket, the sardine tin on the floor, the cardboard box, the cushion, the
## window blinds and the wall clock.

const Thing := preload("res://minigames/workshop/thing.gd")
const P := preload("res://minigames/workshop/palette.gd")
const Ink := preload("res://minigames/workshop/ink.gd")


## A 50s tabletop radio. Plays music; its back opens to reveal a spare vacuum tube.
class Radio extends Thing:
	var playing := false
	var back_open := false:
		set(v):
			back_open = v
			queue_redraw()
	var has_tube := true:
		set(v):
			has_tube = v
			queue_redraw()
	var _t := 0.0

	func _init() -> void:
		id = "radio"
		hover_name = "Radio"
		hit_rect = Rect2(585, 410, 140, 90)

	func _tick(delta: float) -> void:
		_t += delta
		if playing:
			queue_redraw()

	func _paint() -> void:
		var r := Rect2(590, 418, 130, 80)
		if back_open:
			Ink.shape(self, Ink.rrect(r, 22), Color("5a3a26"), 3.0, 100, 0.0, 0.1)
			for k in 3:
				var x := 612.0 + k * 34.0
				if k == 1 and not has_tube:
					Ink.shape(self, Ink.rrect(Rect2(x - 2, 470, 22, 12), 3), P.STEEL, 2.0, 101 + k)
					continue
				_tube(self, Vector2(x + 9, 478), 0.9, 101 + k, k == 1)
			Ink.shape(self, PackedVector2Array([Vector2(720, 420), Vector2(760, 404), Vector2(760, 490), Vector2(720, 496)]), P.WOOD_DARK, 3.0, 104, 0.15)
			return
		Ink.shape(self, Ink.rrect(r, 22), Color("b33a35"), 3.5, 105, 0.25, 0.15)
		Ink.shape(self, Ink.rrect(Rect2(604, 430, 58, 56), 12), P.CREAM, 2.5, 106, 0.0, 0.12)
		for k in 5:
			Ink.line(self, PackedVector2Array([Vector2(610, 440 + k * 10), Vector2(656, 440 + k * 10)]), P.WOOD_DARK, 2.0, 107 + k)
		Ink.dot(self, Vector2(690, 440), 11, P.CREAM, 2.5, 112)
		Ink.dot(self, Vector2(690, 474), 11, P.CREAM, 2.5, 113)
		Ink.line(self, PackedVector2Array([Vector2(690, 440), Vector2(690 + cos(_t) * 8, 440 + sin(_t) * 8)]), Ink.OUTLINE, 2.0, 114)
		if playing:
			for k in 3:
				var ph := fmod(_t * 0.6 + k * 0.33, 1.0)
				var p := Vector2(650 + k * 22 + sin(ph * 9.0 + k) * 10, 410 - ph * 90)
				var c := Color(Ink.OUTLINE, 1.0 - ph)
				draw_circle(p, 5, c)
				draw_line(p + Vector2(4, 0), p + Vector2(4, -18), c, 2.0)
				draw_line(p + Vector2(4, -18), p + Vector2(11, -13), c, 2.0)

	static func _tube(ci: CanvasItem, base: Vector2, s: float, seed: int, glow: bool) -> void:
		var glass := Ink.smooth(PackedVector2Array([base + Vector2(-9, 0) * s, base + Vector2(-10, -26) * s,
			base + Vector2(-6, -40) * s, base + Vector2(0, -44) * s, base + Vector2(6, -40) * s, base + Vector2(10, -26) * s, base + Vector2(9, 0) * s]))
		Ink.shape(ci, glass, Color(1.0, 0.75, 0.45, 0.9) if glow else Color(0.85, 0.92, 0.95, 0.8), 2.5, seed, 0.35, 0.0)
		Ink.shape(ci, Ink.rrect(Rect2(base + Vector2(-11, -2) * s, Vector2(22, 10) * s), 3), Color("2a2a2a"), 2.0, seed + 50)


## A coffee can full of odds and ends; the machine's missing fuse is inside.
class CoffeeCan extends Thing:
	var has_fuse := true

	func _init() -> void:
		id = "can"
		hover_name = "Coffee can"
		hit_rect = Rect2(760, 436, 56, 64)

	func _paint() -> void:
		Ink.shape(self, Ink.rrect(Rect2(764, 442, 48, 56), 6), Color("2f6aa3"), 3.0, 120, 0.25, 0.15)
		Ink.shape(self, Ink.rrect(Rect2(764, 458, 48, 20), 2), P.CREAM, 2.0, 121, 0.0)
		Ink.shape(self, Ink.ellipse(Vector2(788, 442), Vector2(24, 6), 16), P.CHROME, 2.5, 122)
		# Odds and ends poking out.
		Ink.line(self, PackedVector2Array([Vector2(778, 440), Vector2(770, 412)]), P.STEEL, 3.0, 123)
		Ink.line(self, PackedVector2Array([Vector2(796, 440), Vector2(806, 418)]), P.BRASS, 3.0, 124)
		Ink.dot(self, Vector2(806, 418), 4, P.BRASS, 2.0, 125)


## A wicker basket of knitting. Its ball of red yarn rolls out when nudged.
class Basket extends Thing:
	var has_yarn := true:
		set(v):
			has_yarn = v
			queue_redraw()

	func _init() -> void:
		id = "basket"
		hover_name = "Knitting basket"
		hit_rect = Rect2(890, 590, 120, 76)

	func _paint() -> void:
		if has_yarn:
			yarn_ball(self, Vector2(935, 600), 22, 130)
			Ink.line(self, PackedVector2Array([Vector2(960, 590), Vector2(985, 560), Vector2(1000, 565)]), P.STEEL, 3.0, 131)
			Ink.line(self, PackedVector2Array([Vector2(966, 594), Vector2(996, 552)]), P.STEEL, 3.0, 132)
		var b := PackedVector2Array([Vector2(890, 606), Vector2(1010, 606), Vector2(996, 664), Vector2(904, 664)])
		Ink.shape(self, b, Color("c99a5c"), 3.0, 133, 0.15, 0.15)
		for k in 4:
			Ink.line(self, PackedVector2Array([Vector2(896 + k * 2, 618 + k * 12), Vector2(1004 - k * 2, 618 + k * 12)]), Color("8a6236"), 2.0, 134 + k)

	static func yarn_ball(ci: CanvasItem, c: Vector2, r: float, seed: int) -> void:
		Ink.dot(ci, c, r, P.YARN, 3.0, seed, 0.2, 0.15)
		for k in 3:
			var a := 0.6 + k * 0.9
			Ink.line(ci, Ink.ellipse(c, Vector2(r * 0.85, r * 0.35), 14, a, a + PI).duplicate(), P.YARN.darkened(0.3), 2.0, seed + k + 1)


## The sardine tin once it is on the floor; the can opener opens it.
class Tin extends Thing:
	var opened := false:
		set(v):
			opened = v
			queue_redraw()
	var eaten := false:
		set(v):
			eaten = v
			queue_redraw()

	func _init() -> void:
		id = "tin"
		hover_name = "Sardines"
		hit_rect = Rect2(-40, -26, 80, 36)

	func _paint() -> void:
		Ink.shape(self, Ink.rrect(Rect2(-32, -16, 64, 22), 9), Color("6aa6c4"), 2.5, 140, 0.3, 0.1)
		if opened:
			Ink.shape(self, Ink.ellipse(Vector2(0, -16), Vector2(28, 6), 16), Color("4c3a2c"), 2.0, 141, 0.0, 0.0)
			if not eaten:
				for k in 3:
					Ink.shape(self, Ink.ellipse(Vector2(-14 + k * 14, -17), Vector2(8, 3), 10), P.CHROME, 1.5, 142 + k)
		else:
			Ink.shape(self, Ink.ellipse(Vector2(0, -16), Vector2(28, 6), 16), Color("f2d34f"), 2.0, 145)


## A cardboard box: flat against the wall at first, folded into a cat-sized box once used.
class Box extends Thing:
	var folded := false:
		set(v):
			folded = v
			queue_redraw()

	func _init() -> void:
		id = "box"
		hover_name = "Flattened box"
		hit_rect = Rect2(1010, 480, 50, 180)

	func _paint() -> void:
		if not folded:
			Ink.shape(self, PackedVector2Array([Vector2(1018, 486), Vector2(1052, 480), Vector2(1056, 660), Vector2(1014, 660)]),
				Color("c49a62"), 3.0, 150, 0.12, 0.1)
			Ink.line(self, PackedVector2Array([Vector2(1020, 560), Vector2(1052, 556)]), Color("8a6236"), 2.0, 151)
			return
		draw_box(self, Vector2.ZERO)

	static func draw_box(ci: CanvasItem, at: Vector2) -> void:
		Ink.shape(ci, PackedVector2Array([at + Vector2(-60, -60), at + Vector2(60, -60), at + Vector2(60, 0), at + Vector2(-60, 0)]),
			Color("c49a62"), 3.0, 152, 0.12, 0.15)
		Ink.shape(ci, PackedVector2Array([at + Vector2(-60, -60), at + Vector2(-82, -84), at + Vector2(-40, -78), at + Vector2(-20, -60)]),
			Color("b38a54"), 3.0, 153, 0.1)
		Ink.shape(ci, PackedVector2Array([at + Vector2(60, -60), at + Vector2(84, -86), at + Vector2(44, -80), at + Vector2(22, -60)]),
			Color("b38a54"), 3.0, 154, 0.1)
		Ink.line(ci, PackedVector2Array([at + Vector2(-30, -34), at + Vector2(30, -34)]), Color(0.3, 0.2, 0.1, 0.6), 2.0, 155)


## Venetian blinds on the window: closed blinds keep the sunbeam off the floor.
class Blinds extends Thing:
	var open := false:
		set(v):
			open = v
			queue_redraw()

	func _init() -> void:
		id = "blinds"
		hover_name = "Blinds"
		hit_rect = Rect2(64, 100, 274, 324)

	func _paint() -> void:
		if open:
			Ink.shape(self, Ink.rrect(Rect2(66, 102, 268, 36), 4), Color("efe4c8"), 2.5, 160, 0.1)
			# The sunbeam reaching across the floor.
			draw_colored_polygon(PackedVector2Array([Vector2(70, 420), Vector2(330, 420), Vector2(640, 800), Vector2(260, 800)]), P.SUN)
		else:
			for k in 16:
				Ink.shape(self, Ink.rrect(Rect2(66, 104 + k * 20, 268, 16), 4), Color("efe4c8"), 2.0, 161 + k, 0.08, 0.15)
		Ink.line(self, PackedVector2Array([Vector2(318, 104), Vector2(318, 150 if open else 440)]), Ink.OUTLINE, 2.0, 180)
		Ink.dot(self, Vector2(318, 150 if open else 440), 5, P.CREAM, 2.0, 181)


## The wall clock. Freezes when time is stuck in the loop.
class Clock extends Thing:
	var frozen := false
	var seconds := 15.0 * 3600.0 + 5.0 * 60.0
	var alarm := false

	func _init() -> void:
		id = "clock"
		hover_name = "Clock"
		hit_rect = Rect2(1090, 90, 120, 120)

	func _tick(delta: float) -> void:
		if not frozen:
			seconds += delta
			queue_redraw()

	func _paint() -> void:
		var c := Vector2(1150, 150)
		for k in 12:
			var a := TAU * k / 12.0
			var o := c + Vector2(cos(a), sin(a)) * 58
			draw_line(c + Vector2(cos(a), sin(a)) * 46, o, P.BRASS, 4.0)
		Ink.dot(self, c, 46, Color("f6efdc"), 3.5, 190, 0.1, 0.12)
		Ink.dot(self, c, 52, P.BRASS, 0.0, 191, 0.0, 0.0)
		Ink.dot(self, c, 44, Color("f6efdc") if not alarm else Color("ffd4cc"), 3.0, 192, 0.1, 0.12)
		for k in 12:
			var a := TAU * k / 12.0
			draw_circle(c + Vector2(cos(a), sin(a)) * 36, 2.5, Ink.OUTLINE)
		var h := fmod(seconds / 3600.0, 12.0)
		var m := fmod(seconds / 60.0, 60.0)
		var s := fmod(seconds, 60.0)
		_hand(c, h / 12.0, 20, 5.0, Ink.OUTLINE)
		_hand(c, m / 60.0, 32, 3.5, Ink.OUTLINE)
		_hand(c, floor(s) / 60.0, 36, 1.5, P.RED)
		Ink.dot(self, c, 4, P.RED, 1.5, 193)

	func _hand(c: Vector2, turn: float, length: float, width: float, color: Color) -> void:
		var a := turn * TAU - PI / 2.0
		Ink.line(self, PackedVector2Array([c, c + Vector2(cos(a), sin(a)) * length]), color, width, 194, 0.4)

	## "3:07" for the speech text.
	func label() -> String:
		var total := int(seconds)
		return "%d:%02d" % [((total / 3600) + 11) % 12 + 1, (total / 60) % 60]
