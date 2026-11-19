extends "res://minigames/workshop/thing.gd"
## The workbench, and its drawer (the hotspot): a can opener and a flashlight live inside.

const P := preload("res://minigames/workshop/palette.gd")
const TOP := Rect2(555, 496, 470, 26)
const DRAWER := Rect2(600, 528, 170, 46)

var drawer_open := false:
	set(v):
		drawer_open = v
		queue_redraw()
var has_opener := true:
	set(v):
		has_opener = v
		queue_redraw()
var has_flashlight := true:
	set(v):
		has_flashlight = v
		queue_redraw()


func _init() -> void:
	id = "drawer"
	hover_name = "Drawer"
	hit_rect = DRAWER.grow(4)


func _paint() -> void:
	# Legs and a lower shelf.
	for x in [TOP.position.x + 14, TOP.end.x - 34]:
		Ink.shape(self, PackedVector2Array([Vector2(x, TOP.end.y), Vector2(x + 20, TOP.end.y),
			Vector2(x + 22, 662), Vector2(x - 2, 662)]), P.WOOD_DARK, 3.0, int(x), 0.12, 0.15)
	Ink.shape(self, Ink.rrect(Rect2(TOP.position.x + 20, 610, TOP.size.x - 50, 12), 3), P.WOOD_DARK, 2.5, 80)
	# Paint cans on the lower shelf.
	Ink.shape(self, Ink.rrect(Rect2(800, 570, 44, 40), 5), P.TEAL, 2.5, 81, 0.25)
	Ink.shape(self, Ink.rrect(Rect2(850, 580, 36, 30), 5), P.ORANGE, 2.5, 82, 0.25)
	# Top and apron.
	Ink.shape(self, Ink.rrect(TOP, 5), P.WOOD, 3.5, 83, 0.25, 0.2)
	Ink.shape(self, Ink.rrect(Rect2(TOP.position.x + 16, TOP.end.y, TOP.size.x - 32, 56), 3), P.WOOD_DARK.lightened(0.08), 3.0, 84, 0.06, 0.2)
	if drawer_open:
		var tray := Rect2(DRAWER.position + Vector2(-6, 18), DRAWER.size + Vector2(12, 14))
		Ink.shape(self, Ink.rrect(tray, 4), Color("5a3a26"), 3.0, 85, 0.0, 0.1)
		if has_opener:
			Ink.shape(self, Ink.rrect(Rect2(620, 548, 54, 12), 5), P.CHROME, 2.5, 86, 0.35)
			Ink.shape(self, Ink.rrect(Rect2(668, 544, 16, 20), 4), P.RED, 2.5, 87)
		if has_flashlight:
			Ink.shape(self, Ink.rrect(Rect2(700, 548, 50, 16), 5), P.RED, 2.5, 88, 0.3)
			Ink.shape(self, PackedVector2Array([Vector2(748, 543), Vector2(762, 538), Vector2(762, 574), Vector2(748, 569)]), P.CHROME, 2.5, 89)
		Ink.shape(self, Ink.rrect(Rect2(tray.position.x - 2, tray.end.y - 10, tray.size.x + 4, 22), 4), P.WOOD, 3.0, 90, 0.2)
		Ink.shape(self, Ink.rrect(Rect2(tray.get_center().x - 16, tray.end.y - 2, 32, 8), 3), P.CHROME, 2.0, 91)
	else:
		Ink.shape(self, Ink.rrect(DRAWER, 4), P.WOOD, 3.0, 92, 0.18, 0.15)
		Ink.shape(self, Ink.rrect(Rect2(DRAWER.get_center().x - 18, DRAWER.get_center().y - 4, 36, 9), 3), P.CHROME, 2.0, 93, 0.3)
