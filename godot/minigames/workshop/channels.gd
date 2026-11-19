extends RefCounted
## The Futurescope's other channels: once the Workshop is won, it picks up the futures
## of other rooms, each one a problem from autoload/time_link.gd PROBLEMS, drawn in the
## diorama's style. Like the loop footage, each shows how the trouble ends: the hint.
##
## To add a channel: add a problem to TimeLink.PROBLEMS, then a scene class here (a
## Node2D drawn in stage space, 1600 x 900, with `play()` resolving when it ends) and an
## entry in SCENES. The channel appears while the problem is active.

const Ink := preload("res://minigames/workshop/ink.gd")
const P := preload("res://minigames/workshop/palette.gd")
const Style := preload("res://ui/game_style.gd")
const Cat := preload("res://minigames/workshop/cat.gd")
const TimeLink := preload("res://autoload/time_link.gd")

## problem id -> scene class
const SCENES := {
	"egypt_dark": EgyptSun,
	"fuse_loose": HallNap,
}


## The channels to show now: titles and scene classes, in order.
static func available() -> Array:
	var out := []
	for id: String in TimeLink.active_problems():
		if SCENES.has(id):
			out.append({"id": id, "title": TimeLink.PROBLEMS[id].title, "scene": SCENES[id]})
	return out


## Base: a scene that redraws every frame and plays a timed sequence.
class ChannelScene extends Node2D:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func play() -> void:
		t = 0.0
		await get_tree().create_timer(duration()).timeout

	func duration() -> float:
		return 6.0


## Egypt's room, dark. A 1955 flashlight on an optics stand shines through yellow glass
## onto the sun disc; the room fills with light and the Egyptian lifts his arms.
class EgyptSun extends ChannelScene:
	func duration() -> float:
		return 7.0

	func _draw() -> void:
		var beam := clampf((t - 1.5) / 1.2, 0.0, 1.0)      # The beam crosses the room.
		var sun := clampf((t - 2.7) / 1.0, 0.0, 1.0)       # The disc and the room light up.
		var stone := Color("c79a5c").lerp(Color("2b2016"), 0.75 * (1.0 - sun))
		draw_rect(Rect2(380, 0, 1300, 900), stone)
		# Hieroglyph band.
		draw_rect(Rect2(380, 180, 1300, 60), stone.darkened(0.25))
		for k in 22:
			var x := 440.0 + k * 56.0
			var c := Color("3a6aa0").lerp(stone, 0.6)
			match k % 4:
				0: Ink.shape(self, Ink.ellipse(Vector2(x, 210), Vector2(12, 18), 12), c, 2.0, 600 + k, 0.0, 0.0)
				1: Ink.line(self, PackedVector2Array([Vector2(x - 12, 196), Vector2(x, 224), Vector2(x + 12, 196)]), c, 3.0, 600 + k)
				2: Ink.shape(self, PackedVector2Array([Vector2(x - 12, 224), Vector2(x, 196), Vector2(x + 12, 224)]), c, 2.0, 600 + k, 0.0, 0.0)
				_: Ink.line(self, PackedVector2Array([Vector2(x - 12, 210), Vector2(x + 12, 210)]), c, 4.0, 600 + k)
		# Floor.
		draw_rect(Rect2(380, 660, 1300, 240), stone.darkened(0.3))
		# The sun disc on the back wall.
		var disc_c := Vector2(1180, 400)
		for k in 12:
			var a := TAU * k / 12.0
			Ink.line(self, PackedVector2Array([disc_c + Vector2(cos(a), sin(a)) * 70, disc_c + Vector2(cos(a), sin(a)) * (100 + 30 * sun)]),
				P.BRASS.lerp(Color("ffd84a"), sun), 6.0, 620 + k)
		Ink.dot(self, disc_c, 64, Color("4a3a20").lerp(Color("ffcf4a"), sun), 4.0, 640, 0.3 * sun, 0.1)
		if sun > 0.0:
			draw_circle(disc_c, 140 + 60 * sun, Color(1, 0.85, 0.3, 0.18 * sun))
		# The pyramid table.
		Ink.shape(self, Ink.rrect(Rect2(820, 600, 300, 30), 6), Color("6b4a2a"), 3.0, 650, 0.2, 0.2)
		for k in 3:
			var px := 860.0 + k * 100.0
			Ink.shape(self, PackedVector2Array([Vector2(px - 30, 600), Vector2(px, 550 - k * 8), Vector2(px + 30, 600)]),
				Color("e0b860").lerp(Color("5a4a30"), 1.0 - sun * 0.8), 2.5, 651 + k, 0.2, 0.1)
		Ink.shape(self, Ink.rrect(Rect2(840, 630, 20, 50), 3), Color("6b4a2a"), 2.5, 655)
		Ink.shape(self, Ink.rrect(Rect2(1080, 630, 20, 50), 3), Color("6b4a2a"), 2.5, 656)
		_egyptian(Vector2(1420, 760), sun)
		# The lamp on its stand, by the door on the left, and the yellow lens.
		var lamp := Vector2(520, 470)
		Ink.shape(self, Ink.rrect(Rect2(lamp.x - 14, lamp.y + 20, 28, 220), 4), P.STEEL, 3.0, 660)
		Ink.shape(self, Ink.rrect(Rect2(lamp.x - 46, lamp.y - 14, 70, 28), 8), P.RED, 3.0, 661, 0.3)
		Ink.shape(self, PackedVector2Array([lamp + Vector2(24, -18), lamp + Vector2(48, -26), lamp + Vector2(48, 26), lamp + Vector2(24, 18)]), P.CHROME, 3.0, 662)
		var lens := Vector2(780, 452)
		Ink.shape(self, Ink.rrect(Rect2(lens.x - 6, lens.y + 30, 12, 210), 3), P.STEEL, 3.0, 663)
		Ink.shape(self, Ink.ellipse(lens, Vector2(16, 36), 16), Color(1.0, 0.8, 0.0), 3.0, 664, 0.3, 0.0)
		if beam > 0.0:
			var white_end := lamp + Vector2(48, 0)
			var lens_x := lerpf(white_end.x, lens.x, minf(1.0, beam * 2.0))
			draw_line(white_end, Vector2(lens_x, lamp.y + (lens.y - lamp.y) * (lens_x - white_end.x) / (lens.x - white_end.x)), Color(1, 1, 0.92, 0.9), 8.0)
			if beam > 0.5:
				var f := (beam - 0.5) * 2.0
				draw_line(lens, lens.lerp(disc_c, f), Color(1, 0.85, 0.0), 12.0)
		# Darkness over everything until the sun returns.
		draw_rect(Rect2(380, 0, 1300, 900), Color(0.02, 0.01, 0.03, 0.45 * (1.0 - sun)))

	func _egyptian(feet: Vector2, joy: float) -> void:
		var skin := Color("b97a4a")
		var arm_up := joy * 70.0
		for side in [-1.0, 1.0]:
			Ink.line(self, PackedVector2Array([feet + Vector2(side * 30, -230), feet + Vector2(side * (52 + joy * 10), -170 - arm_up)]), skin, 14.0, 670 + int(side))
		Ink.shape(self, PackedVector2Array([feet + Vector2(-34, -250), feet + Vector2(34, -250), feet + Vector2(30, -150), feet + Vector2(-30, -150)]), skin, 3.0, 672, 0.15, 0.1)
		Ink.shape(self, PackedVector2Array([feet + Vector2(-38, -150), feet + Vector2(38, -150), feet + Vector2(46, -60), feet + Vector2(-46, -60)]), Color("f2ead2"), 3.0, 673, 0.1, 0.1)
		for side in [-1.0, 1.0]:
			Ink.line(self, PackedVector2Array([feet + Vector2(side * 18, -60), feet + Vector2(side * 20, 0)]), skin, 14.0, 674 + int(side))
		Ink.shape(self, Ink.ellipse(feet + Vector2(0, -284), Vector2(28, 32), 18), skin, 3.0, 676, 0.15, 0.1)
		# Nemes headdress, blue and gold.
		var head := feet + Vector2(0, -290)
		Ink.shape(self, PackedVector2Array([head + Vector2(-34, -10), head + Vector2(0, -38), head + Vector2(34, -10), head + Vector2(44, 60), head + Vector2(26, 60), head + Vector2(20, 10), head + Vector2(-20, 10), head + Vector2(-26, 60), head + Vector2(-44, 60)]),
			Color("2f5ea8"), 3.0, 677, 0.2, 0.1)
		for k in 3:
			Ink.line(self, PackedVector2Array([head + Vector2(-38 + k * 4, 14 + k * 14), head + Vector2(-26 + k * 3, 14 + k * 14)]), P.BRASS, 3.0, 678 + k)
		for x in [-9.0, 9.0]:
			draw_circle(head + Vector2(x, 2), 3.0, Ink.OUTLINE)


## The hall, blue and dim, and Fuse asleep on the floor in a relay cabinet's warm exhaust.
class HallNap extends ChannelScene:
	var _cat: Node2D

	func duration() -> float:
		return 5.0

	func _ready() -> void:
		_cat = Cat.new()
		_cat.id = ""
		_cat.pose = "sleep"
		_cat.lid = true
		_cat.yarn = true
		_cat.position = Vector2(1300, 760)
		_cat.scale = Vector2(1.4, 1.4)
		add_child(_cat)

	func _draw() -> void:
		draw_rect(Rect2(380, 0, 1300, 900), Color("1b2a33"))
		for k in 7:
			Ink.line(self, PackedVector2Array([Vector2(420 + k * 180, 0), Vector2(420 + k * 180, 660)]), Color("24363f"), 6.0, 700 + k)
		draw_rect(Rect2(380, 660, 1300, 240), Color("2a3b42"))
		# The relay cabinet: a big metal box with dials; warm, as cats like.
		var cab := Rect2(840, 440, 360, 280)
		Ink.shape(self, Ink.rrect(cab, 12), Color("364a50"), 4.0, 710, 0.15, 0.2)
		for k in 3:
			Ink.dot(self, Vector2(900 + k * 110, 540), 26, P.CREAM.darkened(0.3), 3.0, 711 + k)
		for k in 6:
			draw_circle(Vector2(890 + k * 50, 640), 7, [Color("ff6a4a"), Color("6aff9a"), Color("ffd84a")][k % 3].darkened(0.2 if int(t * 3.0 + k) % 2 == 0 else 0.6))
		# A green beam far behind, for scale.
		draw_line(Vector2(380, 330), Vector2(1680, 300), Color(0.2, 1, 0.47, 0.35), 5.0)
		# Warm air blowing out of the cabinet's side vent, over the cat.
		for k in 4:
			Ink.line(self, PackedVector2Array([Vector2(1200, 600 + k * 22), Vector2(1240, 600 + k * 22)]), Color("1e2c30"), 4.0, 730 + k)
		for k in 4:
			var ph := fmod(t * 0.5 + k * 0.25, 1.0)
			var y := 610.0 + k * 22.0
			Ink.line(self, PackedVector2Array([Vector2(1210 + ph * 140, y), Vector2(1240 + ph * 140, y - 10), Vector2(1270 + ph * 140, y)]),
				Color(1, 0.8, 0.5, 0.35 * (1.0 - ph)), 3.0, 720 + k)
