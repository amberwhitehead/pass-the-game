extends RefCounted
## The Workshop's carried items: names and hand-drawn icons.

const Ink := preload("res://minigames/workshop/ink.gd")
const P := preload("res://minigames/workshop/palette.gd")
const Small := preload("res://minigames/workshop/small_props.gd")

const NAMES := {
	"tube": "Vacuum tube",
	"sardines": "Tin of sardines",
	"opener": "Can opener",
	"flashlight": "Flashlight",
	"yarn": "Red yarn",
	"wire": "Copper wire",
	"box": "Flattened box",
}


## Draws item `id`'s icon centred on `c`, about 64 px across.
static func draw_icon(ci: CanvasItem, id: String, c: Vector2) -> void:
	match id:
		"tube":
			Small.Radio._tube(ci, c + Vector2(0, 24), 1.2, 700, true)
		"sardines":
			Ink.shape(ci, Ink.rrect(Rect2(c + Vector2(-30, -12), Vector2(60, 24)), 10), Color("6aa6c4"), 2.5, 701, 0.3, 0.1)
			Ink.shape(ci, Ink.ellipse(c + Vector2(-4, 0), Vector2(14, 6), 12), Color("f2d34f"), 2.0, 702)
			Ink.shape(ci, PackedVector2Array([c + Vector2(14, -4), c + Vector2(26, -10), c + Vector2(26, 2)]), P.CHROME, 2.0, 703)
		"opener":
			Ink.shape(ci, Transform2D(-0.5, c) * Ink.rrect(Rect2(-30, -6, 50, 12), 5), P.CHROME, 2.5, 704, 0.35)
			Ink.shape(ci, Transform2D(-0.5, c) * Ink.rrect(Rect2(14, -10, 18, 20), 4), P.RED, 2.5, 705)
		"flashlight":
			Ink.shape(ci, Transform2D(-0.4, c) * Ink.rrect(Rect2(-30, -9, 46, 18), 6), P.RED, 2.5, 706, 0.3)
			Ink.shape(ci, Transform2D(-0.4, c) * PackedVector2Array([Vector2(14, -10), Vector2(30, -15), Vector2(30, 15), Vector2(14, 10)]), P.CHROME, 2.5, 707)
		"yarn":
			Small.Basket.yarn_ball(ci, c, 24, 708)
		"wire":
			Small.WireCoil.coil(ci, c, 1.0, 709)
		"box":
			Ink.shape(ci, PackedVector2Array([c + Vector2(-26, -26), c + Vector2(22, -30), c + Vector2(26, 28), c + Vector2(-24, 26)]), Color("c49a62"), 2.5, 712, 0.12)
			Ink.line(ci, PackedVector2Array([c + Vector2(-24, 0), c + Vector2(24, -2)]), Color("8a6236"), 2.0, 713)
