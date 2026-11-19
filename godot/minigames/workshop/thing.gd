extends Node2D
## Base for every drawn object in the Workshop diorama.
##
## A Thing redraws itself on every boil frame (see ink.gd) and, when `id` is set, is a
## clickable hotspot: the stage tests `hit_test()` under the cursor, shows `hover_name`,
## and reports clicks by id. Subclasses draw in `_paint()` and may override `hit_test()`.

const Ink := preload("res://minigames/workshop/ink.gd")
const Style := preload("res://ui/game_style.gd")

@export var id := ""            ## Hotspot id reported on click; "" = scenery only.
@export var hover_name := ""    ## Shown beside the cursor when hovered.
var hit_rect := Rect2()         ## Local-space clickable area (used by the default hit_test).
var hovered := false:
	set(v):
		if hovered != v:
			hovered = v
			queue_redraw()
var enabled := true             ## False hides the hotspot from the cursor.

var _boil := -1


func _process(_delta: float) -> void:
	var f := Ink.boil_frame()
	if f != _boil:
		_boil = f
		queue_redraw()
	_tick(_delta)


## Per-frame animation hook for subclasses.
func _tick(_delta: float) -> void:
	pass


func _draw() -> void:
	_paint()
	if hovered and enabled and id != "":
		_paint_hover()


## Subclasses draw here.
func _paint() -> void:
	pass


## A soft glow ring around the hotspot while hovered.
func _paint_hover() -> void:
	if hit_rect.size == Vector2.ZERO:
		return
	var pts := Ink.rrect(hit_rect.grow(6.0), 14.0)
	pts.append(pts[0])
	draw_polyline(Ink.wobble(pts, 1.5, 99), Color(1.0, 0.93, 0.6, 0.85), 3.0, true)


## True when the global canvas point lies on this hotspot.
func hit_test(global_point: Vector2) -> bool:
	if id == "" or not enabled or not is_visible_in_tree():
		return false
	return hit_rect.has_point(to_local(global_point))
