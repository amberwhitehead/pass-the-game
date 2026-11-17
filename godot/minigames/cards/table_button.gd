extends Node3D
## Brass end-turn bell. The table view owns pointer picking and emits pressed.

const Meshes := preload("res://scenes/escape/hub_meshes.gd")
const Style := preload("res://ui/game_style.gd")

signal pressed

var disabled := false
var label: Label3D
var collider: StaticBody3D
var _cap: MeshInstance3D
var _material: StandardMaterial3D
var _hovered := false
var _motion: Tween


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color("b78a45")
	_material.metallic = 0.65
	_material.roughness = 0.3
	_material.emission_enabled = true
	var base := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.36
	cylinder.bottom_radius = 0.4
	cylinder.height = 0.12
	cylinder.radial_segments = 48
	base.mesh = cylinder
	base.position.y = 0.06
	base.material_override = _material
	add_child(base)
	_cap = MeshInstance3D.new()
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.29
	cap_mesh.height = 0.37
	cap_mesh.radial_segments = 48
	cap_mesh.rings = 24
	_cap.mesh = cap_mesh
	_cap.position.y = 0.22
	_cap.material_override = _material
	add_child(_cap)
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.07
	stem_mesh.bottom_radius = 0.045
	stem_mesh.height = 0.13
	stem.mesh = stem_mesh
	stem.position.y = 0.43
	stem.material_override = _material
	_cap.add_child(stem)
	stem.position.y = 0.20
	label = Label3D.new()
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = .32
	ring.outer_radius = .355
	ring.rings = 48
	ring.ring_segments = 10
	rim.mesh = ring
	rim.position.y = .115
	rim.material_override = _material
	add_child(rim)
	var plate := MeshInstance3D.new()
	plate.mesh = Meshes.chamfer_box(Vector3(1.0, .028, .38), .018)
	plate.position = Vector3(0, .015, .70)
	plate.material_override = _material
	add_child(plate)
	label.text = "End turn"
	label.font = Style.font(true)
	label.font_size = 40
	label.pixel_size = 0.0025
	label.modulate = Style.INK
	label.outline_size = 0
	label.rotation.x = -PI / 2.0
	label.position = Vector3(0, .034, .70)
	add_child(label)
	collider = StaticBody3D.new()
	collider.collision_layer = 1
	collider.collision_mask = 0
	collider.set_meta("card_actor", self)
	var shape := CollisionShape3D.new()
	var bounds := CylinderShape3D.new()
	bounds.radius = 0.42
	bounds.height = 0.6
	shape.shape = bounds
	shape.position.y = 0.3
	collider.add_child(shape)
	# The engraved plate is part of the same end-turn target as the bell.
	var plate_shape := CollisionShape3D.new()
	var plate_bounds := BoxShape3D.new()
	plate_bounds.size = Vector3(1.0, .07, .38)
	plate_shape.shape = plate_bounds
	plate_shape.position = Vector3(0, .025, .70)
	collider.add_child(plate_shape)
	add_child(collider)


func set_hovered(value: bool) -> void:
	_hovered = value
	if _material:
		_material.emission = Color("a07935") * (0.55 if value and not disabled else 0.0)


func press_animation() -> void:
	if _motion:
		_motion.kill()
	_motion = create_tween()
	_motion.tween_property(_cap, "position:y", 0.16, 0.07)
	_motion.tween_property(_cap, "position:y", 0.22, 0.14).set_trans(Tween.TRANS_BACK)
