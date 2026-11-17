extends Node3D
## A short spatial battle wipe. Everything transient belongs to the table scene.

signal finished

const DURATION := 1.85
const CARD_COUNT := 5
var cancelled := false
var _completed := false
var _tween: Tween


func start(table: Control) -> void:
	var camera: Camera3D = table.camera
	var destination := camera.transform
	var final_fov := camera.fov
	var opening := destination.origin + Vector3(1.8, 0.15, 2.1)
	camera.position = opening
	camera.look_at(Vector3(-0.65, 0.15, -0.6))
	var opening_rotation := camera.quaternion
	camera.fov = final_fov + 14.0
	table.hud.modulate.a = 0.0
	table.hud.hide()
	table.hand.hide()

	var cards: Array[Node3D] = []
	var starts: Array[Vector3] = []
	var rotations: Array[Quaternion] = []
	for index in CARD_COUNT:
		var card := _card_back()
		add_child(card)
		var offset := float(index) - float(CARD_COUNT - 1) * 0.5
		card.position = camera.transform * Vector3(offset * 1.12, 0.10 + absf(offset) * 0.12, -2.15 - absf(offset) * 0.18)
		card.basis = camera.basis
		card.rotate_object_local(Vector3.FORWARD, offset * 0.12)
		card.rotate_object_local(Vector3.UP, -offset * 0.10)
		cards.append(card)
		starts.append(card.position)
		rotations.append(card.quaternion)

	# The scene-owned tween has no suspended coroutine when the player leaves early.
	_tween = create_tween()
	_tween.tween_method(func(time: float):
		var camera_progress := _smooth(clampf(time / 0.94, 0.0, 1.0))
		camera.position = opening.lerp(destination.origin, camera_progress)
		camera.quaternion = opening_rotation.slerp(destination.basis.get_rotation_quaternion(), camera_progress)
		camera.fov = lerpf(final_fov + 14.0, final_fov, camera_progress)
		for index in CARD_COUNT:
			var progress := _smooth(clampf((time - index * 0.035) / 0.78, 0.0, 1.0))
			var offset := float(index) - float(CARD_COUNT - 1) * 0.5
			var finish := Vector3(-2.6, 0.20 + index * 0.028, 1.2)
			var bend := starts[index].lerp(finish, 0.45) + Vector3(offset * 0.7, 1.15, -0.8)
			cards[index].position = starts[index].lerp(bend, progress).lerp(bend.lerp(finish, progress), progress)
			var flat := Quaternion(Vector3.RIGHT, -PI / 2.0)
			cards[index].quaternion = rotations[index].slerp(flat, progress)
			cards[index].scale = Vector3.ONE * lerpf(1.0, 0.43, progress)
	, 0.0, 1.0, DURATION)
	_tween.tween_callback(func():
		camera.transform = destination
		camera.fov = final_fov
		table.hud.show()
		table.hand.show()
		hide())
	_tween.tween_property(table.hud, "modulate:a", 1.0, 0.16)
	_tween.finished.connect(_finish)


func _finish() -> void:
	_completed = true
	finished.emit()
	queue_free()


func _exit_tree() -> void:
	if not _completed:
		cancelled = true
		_completed = true
		if _tween:
			_tween.kill()
		# Resume the controller on early exit instead of leaving an await orphaned.
		finished.emit()


static func _smooth(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)


static func _material(color: String, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.metallic = metallic
	material.roughness = 0.55
	return material


static func _box(parent: Node3D, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	node.material_override = material
	parent.add_child(node)
	return node


static func _card_back() -> Node3D:
	var card := Node3D.new()
	var brass := _material("b99b60", 0.45)
	_box(card, Vector3(1.5, 2.05, 0.055), Vector3.ZERO, brass)
	_box(card, Vector3(1.39, 1.94, 0.065), Vector3.ZERO, _material("17423e"))
	for side in [-1.0, 1.0]:
		_box(card, Vector3(1.20, 0.025, 0.012), Vector3(0, side * 0.84, 0.038), brass)
		_box(card, Vector3(0.025, 1.70, 0.012), Vector3(side * 0.60, 0, 0.038), brass)
	var diamond := _box(card, Vector3(0.54, 0.54, 0.025), Vector3(0, 0, 0.043), brass)
	diamond.rotation.z = PI / 4.0
	var inset := _box(card, Vector3(0.36, 0.36, 0.025), Vector3(0, 0, 0.060), _material("265d54"))
	inset.rotation.z = PI / 4.0
	return card
