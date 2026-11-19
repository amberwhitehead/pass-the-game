extends "res://minigames/workshop/thing.gd"
## The Workshop's walls, floor, window frame, pegboard and shelf: scenery that never
## changes. Stage space is 1600 x 900 with the floor line at FLOOR_Y.

const P := preload("res://minigames/workshop/palette.gd")
const W := 1600.0
const H := 900.0
const FLOOR_Y := 660.0


func _paint() -> void:
	# Wall with a 50s stripe-and-diamond wallpaper.
	draw_rect(Rect2(0, 0, W, FLOOR_Y), P.WALL)
	for i in 34:
		var x := i * 48.0
		draw_rect(Rect2(x, 0, 18, 560), P.WALL_STRIPE)
		for j in 12:
			var c := Vector2(x + 33, 24 + j * 46)
			var d := PackedVector2Array([c + Vector2(0, -5), c + Vector2(4, 0), c + Vector2(0, 5), c + Vector2(-4, 0)])
			draw_colored_polygon(d, P.WALL_STRIPE.darkened(0.06))
	# Wainscot and chair rail.
	draw_rect(Rect2(0, 560, W, FLOOR_Y - 560), P.WAINSCOT)
	for i in 21:
		var x := 10.0 + i * 78.0
		Ink.shape(self, Ink.rrect(Rect2(x, 576, 62, 66), 6), P.WAINSCOT.lightened(0.05), 2.0, 300 + i, 0.06, 0.1)
	Ink.shape(self, PackedVector2Array([Vector2(-10, 548), Vector2(W + 10, 548), Vector2(W + 10, 566), Vector2(-10, 566)]),
		P.WOOD, 3.0, 2, 0.2, 0.2)
	# Floor boards, with a gentle perspective spread toward the viewer.
	draw_rect(Rect2(0, FLOOR_Y, W, H - FLOOR_Y), P.FLOOR)
	var rows := [FLOOR_Y, 690.0, 728.0, 776.0, 834.0, 905.0]
	for r in rows.size() - 1:
		var y0: float = rows[r]
		var y1: float = rows[r + 1]
		Ink.line(self, PackedVector2Array([Vector2(-5, y1), Vector2(W + 5, y1)]), P.FLOOR_DARK, 2.5, 40 + r)
		var step := 180.0 + r * 50.0
		var off := fmod(r * 97.0, step)
		var x := off
		while x < W:
			Ink.line(self, PackedVector2Array([Vector2(x, y0 + 2), Vector2(x, y1 - 2)]), P.FLOOR_DARK, 2.0, int(x) + r)
			x += step
	Ink.shape(self, PackedVector2Array([Vector2(-10, FLOOR_Y - 14), Vector2(W + 10, FLOOR_Y - 14), Vector2(W + 10, FLOOR_Y + 2), Vector2(-10, FLOOR_Y + 2)]),
		P.BASEBOARD, 3.0, 3, 0.15, 0.0)
	_window()
	_pegboard()
	_shelf()
	_blueprint()
	_ceiling_lamp()


func _window() -> void:
	var r := Rect2(70, 110, 260, 310)
	Ink.shape(self, Ink.rrect(r.grow(16), 8), P.CREAM, 3.5, 10, 0.1, 0.15)
	# Sky: an afternoon glow with a far roofline.
	var steps := 8
	for i in steps:
		var t := float(i) / steps
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y * t, r.size.x, r.size.y / steps + 1),
			P.SKY_TOP.lerp(P.SKY_BOTTOM, t))
	draw_circle(Vector2(250, 190), 34, Color(1, 0.97, 0.85))
	var roof := PackedVector2Array([Vector2(70, 380), Vector2(120, 350), Vector2(170, 365), Vector2(200, 335),
		Vector2(260, 352), Vector2(330, 330), Vector2(330, 420), Vector2(70, 420)])
	draw_colored_polygon(roof, Color("c9a27a"))
	# Mullions.
	Ink.shape(self, PackedVector2Array([Vector2(194, 110), Vector2(206, 110), Vector2(206, 420), Vector2(194, 420)]), P.CREAM, 2.5, 11, 0.0, 0.1)
	Ink.shape(self, PackedVector2Array([Vector2(70, 259), Vector2(330, 259), Vector2(330, 271), Vector2(70, 271)]), P.CREAM, 2.5, 12, 0.0, 0.1)
	# Sill.
	Ink.shape(self, Ink.rrect(Rect2(40, 430, 320, 22), 5), P.CREAM.darkened(0.05), 3.0, 13)
	# A potted cactus on the sill.
	Ink.shape(self, PackedVector2Array([Vector2(290, 432), Vector2(296, 404), Vector2(326, 404), Vector2(332, 432)]), P.ORANGE.darkened(0.15), 2.5, 14)
	Ink.shape(self, Ink.smooth(PackedVector2Array([Vector2(300, 404), Vector2(302, 372), Vector2(311, 360), Vector2(320, 372), Vector2(322, 404)])),
		Color("6fa35b"), 2.5, 15)


func _pegboard() -> void:
	var r := Rect2(560, 220, 240, 250)
	Ink.shape(self, Ink.rrect(r, 6), Color("c8a274"), 3.0, 20, 0.08, 0.1)
	for i in 11:
		for j in 11:
			draw_circle(r.position + Vector2(14 + i * 21.5, 14 + j * 22), 2.0, Color("8a6a46"))
	# Hanging tools: hammer, saw, pliers, coil of wire.
	Ink.shape(self, Ink.rrect(Rect2(590, 250, 12, 110), 4), P.WOOD, 2.5, 21)
	Ink.shape(self, Ink.rrect(Rect2(572, 244, 48, 20), 4), P.STEEL, 2.5, 22)
	Ink.shape(self, PackedVector2Array([Vector2(640, 250), Vector2(700, 250), Vector2(700, 268), Vector2(690, 380), Vector2(640, 268)]), P.CHROME, 2.5, 23)
	Ink.shape(self, Ink.rrect(Rect2(700, 246, 26, 34), 6), P.RED, 2.5, 24)
	Ink.line(self, PackedVector2Array([Vector2(740, 250), Vector2(732, 340)]), P.STEEL, 5.0, 25)
	Ink.line(self, PackedVector2Array([Vector2(752, 250), Vector2(762, 340)]), P.STEEL, 5.0, 26)
	Ink.shape(self, Ink.rrect(Rect2(728, 330, 16, 50), 6), P.RED, 2.5, 27)
	Ink.shape(self, Ink.rrect(Rect2(756, 330, 16, 50), 6), P.RED, 2.5, 28)
	for k in 3:
		var ring := Ink.ellipse(Vector2(620, 410), Vector2(26 - k * 6, 26 - k * 6), 20)
		ring.append(ring[0])
		Ink.line(self, ring, Color("b5643a"), 3.0, 29 + k)


func _shelf() -> void:
	# The Futurescope stands on this shelf (drawn by futurescope.gd).
	Ink.shape(self, Ink.rrect(Rect2(815, 418, 210, 16), 4), P.WOOD, 3.0, 30)
	for x in [840.0, 1000.0]:
		Ink.shape(self, PackedVector2Array([Vector2(x - 4, 434), Vector2(x + 4, 434), Vector2(x + 4, 470), Vector2(x - 26 if x < 900 else x + 26, 434)]),
			P.STEEL, 2.5, 31 + int(x))


func _blueprint() -> void:
	var r := Rect2(1330, 120, 170, 120)
	Ink.shape(self, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y + 4), r.end, Vector2(r.position.x + 3, r.end.y)]),
		Color("3d6fa8"), 2.5, 40, 0.06, 0.06)
	var c := Color(0.85, 0.92, 1.0, 0.8)
	var ring := Ink.ellipse(Vector2(1395, 180), Vector2(34, 34), 22)
	ring.append(ring[0])
	Ink.line(self, ring, c, 2.0, 41)
	Ink.line(self, PackedVector2Array([Vector2(1440, 150), Vector2(1485, 150)]), c, 2.0, 42)
	Ink.line(self, PackedVector2Array([Vector2(1440, 168), Vector2(1475, 168)]), c, 2.0, 43)
	Ink.line(self, PackedVector2Array([Vector2(1440, 186), Vector2(1488, 186)]), c, 2.0, 44)
	Ink.line(self, PackedVector2Array([Vector2(1350, 222), Vector2(1482, 222)]), c, 1.5, 45)
	for p in [r.position + Vector2(8, 8), Vector2(r.end.x - 8, r.position.y + 10)]:
		Ink.dot(self, p, 4, P.RED, 1.5, 46)


func _ceiling_lamp() -> void:
	Ink.line(self, PackedVector2Array([Vector2(860, -5), Vector2(860, 70)]), Ink.OUTLINE, 3.0, 50)
	Ink.shape(self, PackedVector2Array([Vector2(820, 112), Vector2(842, 70), Vector2(878, 70), Vector2(900, 112)]), P.TEAL, 3.0, 51)
	draw_colored_polygon(PackedVector2Array([Vector2(826, 114), Vector2(894, 114), Vector2(960, 230), Vector2(760, 230)]), Color(1, 0.95, 0.7, 0.07))
