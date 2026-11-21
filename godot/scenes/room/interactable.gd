class_name Interactable
extends Area3D
## Base for anything the player can walk up to and press A on.
## Set `minigame_id` (see autoload/minigames.gd) to open a mini-game.

signal interacted

@export var prompt := "Use"
@export var minigame_id := ""
## A second action, shown beside the first (right-click / R2 / R), e.g. "Take prism".
## Empty for things with only one. Override secondary() to do it.
var secondary_prompt := ""

var focused := false


func _ready() -> void:
	add_to_group("interactable")


func interact(_player: Node3D) -> void:
	if minigame_id != "":
		await MiniGames.play(minigame_id)
	interacted.emit()


func secondary(_player: Node3D) -> void:
	pass


func set_focused(value: bool) -> void:
	focused = value
	_set_outline(value)
	_on_focus_changed(value)


## The whole object this belongs to, for the focus outline and for matching what the
## crosshair is on: itself, unless it is one part of something bigger (a stand's knob).
func outline_root() -> Node3D:
	return self


static var _outline: ShaderMaterial

## A thin white rim round the targeted object's silhouette, so it is clear which one a
## press will use.
func _set_outline(on: bool) -> void:
	if _outline == null:
		# Two passes: mark the object's pixels in the stencil, then draw the rim outside
		# them. Both sort after everything else, the mark first, so every part is marked
		# before any part's rim is drawn.
		var rim := ShaderMaterial.new()
		rim.shader = preload("res://shaders/focus_outline.gdshader")
		rim.render_priority = 101
		_outline = ShaderMaterial.new()
		_outline.shader = preload("res://shaders/focus_mask.gdshader")
		_outline.render_priority = 100
		_outline.next_pass = rim
	for mesh: Node in outline_root().find_children("*", "MeshInstance3D", true, false):
		var m := mesh as MeshInstance3D
		if on and m.material_overlay == null:
			m.material_overlay = _outline
			m.set_meta("focus_outline", true)
		elif not on and m.has_meta("focus_outline"):
			m.material_overlay = null
			m.remove_meta("focus_outline")


func get_focus_position() -> Vector3:
	for child: Node in get_children():
		if child is CollisionShape3D:
			return child.global_position
	return global_position


func _on_focus_changed(_value: bool) -> void:
	pass
