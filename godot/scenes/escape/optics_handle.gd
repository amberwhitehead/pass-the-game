extends Interactable
## A physical handle on an optical stand. What it does is set by the stand: `primary`
## (click / A / E) and `secondary` (right-click / R2 / R) name an action, "turn" or
## "exchange", and used(action) reports which one the player chose.

signal used(action: String)
var primary := ""
var secondary_action := ""
var _focus_tween: Tween


func _ready() -> void:
	super()
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	# The compact apparatus is scaled horizontally. Jolt supports that scale on
	# boxes, while spheres silently expand to a different interaction footprint.
	var box := BoxShape3D.new()
	box.size = Vector3(0.48, 0.48, 0.48)
	shape.shape = box
	add_child(shape)


func interact(_player: Node3D) -> void:
	if primary != "":
		used.emit(primary)
	interacted.emit()


func secondary(_player: Node3D) -> void:
	if secondary_action != "":
		used.emit(secondary_action)
	interacted.emit()


func _on_focus_changed(value: bool) -> void:
	if _focus_tween:
		_focus_tween.kill()
	_focus_tween = create_tween().set_parallel(true)
	for child in get_children():
		if child is MeshInstance3D:
			_focus_tween.tween_property(child, "scale", Vector3.ONE * (1.24 if value else 1.0), 0.13)
