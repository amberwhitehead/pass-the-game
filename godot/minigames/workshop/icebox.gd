extends "res://minigames/workshop/thing.gd"
## A rounded 1950s refrigerator. Opens to show its shelves, where the sardine tin waits.

const P := preload("res://minigames/workshop/palette.gd")
const BODY := Rect2(370, 330, 165, 330)

var open := false:
	set(v):
		open = v
		queue_redraw()
var has_tin := true:
	set(v):
		has_tin = v
		queue_redraw()


func _init() -> void:
	id = "icebox"
	hover_name = "Icebox"
	hit_rect = BODY


func _paint() -> void:
	var body := Ink.rrect(BODY, 34)
	# Feet.
	for x in [BODY.position.x + 18, BODY.end.x - 34]:
		Ink.shape(self, Ink.rrect(Rect2(x, BODY.end.y - 6, 16, 12), 3), P.STEEL, 2.5, int(x))
	Ink.shape(self, body, P.CREAM, 3.5, 60, 0.22, 0.18)
	if open:
		var inner := Rect2(BODY.position + Vector2(14, 22), BODY.size - Vector2(28, 44))
		Ink.shape(self, Ink.rrect(inner, 22), Color("e9f4f2"), 3.0, 61, 0.0, 0.22)
		for y in [460.0, 560.0]:
			Ink.line(self, PackedVector2Array([Vector2(inner.position.x + 6, y), Vector2(inner.end.x - 6, y)]), P.STEEL, 3.0, int(y))
		# (The milk and the jelly are their own hotspots: small_props.gd FridgeItem.)
		if has_tin:
			_tin(Vector2(440, 448))
		# The door, swung open to the left.
		var door := PackedVector2Array([Vector2(370, 340), Vector2(330, 318), Vector2(330, 672), Vector2(370, 650)])
		Ink.shape(self, door, P.CREAM.darkened(0.08), 3.0, 65, 0.1, 0.1)
	else:
		Ink.line(self, PackedVector2Array([Vector2(BODY.position.x + 8, 440), Vector2(BODY.end.x - 8, 440)]), Ink.OUTLINE.lightened(0.2), 2.5, 66)
		Ink.shape(self, Ink.rrect(Rect2(BODY.end.x - 30, 380, 14, 46), 6), P.CHROME, 2.5, 67, 0.35, 0.1)
		Ink.shape(self, Ink.rrect(Rect2(BODY.end.x - 30, 470, 14, 70), 6), P.CHROME, 2.5, 68, 0.35, 0.1)
		Ink.shape(self, Ink.rrect(Rect2(395, 360, 70, 20), 6), P.CHROME, 2.0, 69, 0.3)
		draw_string(Style.font(true), Vector2(400, 375), "FROSTMASTER", HORIZONTAL_ALIGNMENT_LEFT, 64, 9, P.RED.darkened(0.2))


func _tin(at: Vector2) -> void:
	Ink.shape(self, Ink.rrect(Rect2(at, Vector2(62, 22)), 9), Color("6aa6c4"), 2.5, 70, 0.3, 0.1)
	Ink.shape(self, Ink.ellipse(at + Vector2(31, 11), Vector2(16, 6), 14), Color("f2d34f"), 2.0, 71)
