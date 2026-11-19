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
			_hover_tint(v)
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


## Subclasses draw here.
func _paint() -> void:
	pass


## Hovered things brighten a little. Colours above 1 lighten everything drawn here.
func _hover_tint(on: bool) -> void:
	var tw := create_tween()
	tw.tween_property(self, "self_modulate", Color(1.22, 1.18, 1.1) if on else Color.WHITE, 0.12)


## True when the global canvas point lies on this hotspot.
func hit_test(global_point: Vector2) -> bool:
	if id == "" or not enabled or not is_visible_in_tree():
		return false
	return hit_rect.has_point(to_local(global_point))
