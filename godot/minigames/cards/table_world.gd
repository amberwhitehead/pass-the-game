extends Node3D
## First-person card room. The view owns the camera, cards, score and bell.
## Table top: y=0; lanes: x=-1.25/0/1.25, z=-0.95 (enemy), +0.55 (player).

const Craft := preload("res://minigames/cards/table_craft.gd")

const OPPONENT_MODEL := preload("res://assets/characters/augmented.glb")

var opponent: Node3D
var lane_count := 3
var opponent_id := "little_brother"
var _body_anim: AnimationPlayer
var _face_anim: AnimationPlayer
var _face_meshes: Array[MeshInstance3D] = []
var _reaction: Tween
var _talking := false
var _blink_clock := 2.3
var _built := false


func _ready() -> void:
	setup()


func setup() -> void:
	if _built:
		return
	_built = true
	_build_lighting()
	_build_room()
	_build_table()
	_build_opponent()


func _material(color: Color, roughness: float = 0.85, metallic: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat


func _box(label: String, dimensions: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = at
	node.material_override = material
	add_child(node)
	return node


func _cylinder(label: String, radius: float, height: float, at: Vector3, material: Material, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 24
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = at
	node.material_override = material
	add_child(node)
	return node


func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("080e16")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9aaeb6")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var key := SpotLight3D.new()
	key.position = Vector3(-2.0, 4.0, 1.2)
	key.rotation_degrees.x = -75.0
	key.light_color = Color("ffe1b0")
	key.light_energy = 1.9
	key.spot_range = 12.0
	key.spot_angle = 65.0
	key.shadow_enabled = true
	key.shadow_bias = 0.04
	add_child(key)
	var face_light := OmniLight3D.new()
	face_light.position = Vector3(0.5, 2.1, -1.8)
	face_light.light_color = Color("f4d4ae")
	face_light.light_energy = 0.55
	face_light.omni_range = 5.0
	add_child(face_light)
	var rim := OmniLight3D.new()
	rim.position = Vector3(3.7, 1.5, -3.8)
	rim.light_color = Color("62b5bd")
	rim.light_energy = 0.75
	rim.omni_range = 6.0
	add_child(rim)


func _build_room() -> void:
	var wall := _material(Color("15242c"))
	var iron := _material(Color("263238"), 0.65, 0.35)
	var trim := _material(Color("517b7b"), 0.5, 0.15, 0.5)
	_box("Floor", Vector3(12, 0.16, 13), Vector3(0, -1.65, 0), _material(Color("151b20")))
	_box("BackWall", Vector3(12, 6.0, 0.2), Vector3(0, 1.3, -5.3), wall)
	for side in [-1.0, 1.0]:
		_box("SideWall", Vector3(0.2, 6.0, 13), Vector3(side * 5.6, 1.3, 0), wall)
	for x in [-4.8, -2.4, 0.0, 2.4, 4.8]:
		_box("WallPillar", Vector3(0.18, 5.2, 0.22), Vector3(x, 0.95, -5.12), iron)
		if x != 0.0:
			_box("WallStrip", Vector3(0.035, 1.45, 0.05), Vector3(x, 0.95, -4.98), trim)
	for side in [-1.0, 1.0]:
		_box("WallPanel", Vector3(1.3, 1.4, 0.12), Vector3(side * 3.4, 0.3, -5.1), iron)
		for row in 7:
			_box("Vent", Vector3(0.95, 0.025, 0.025), Vector3(side * 3.4, -0.12 + row * 0.12, -5.02), wall)
	var brass := _material(Color("947349"), 0.45, 0.5)
	_cylinder("LampCable", 0.018, 1.2, Vector3(-3.6, 3.5, -1.5), iron)
	_cylinder("LampShade", 0.5, 0.32, Vector3(-3.6, 2.77, -1.5), brass, 0.25)
	_cylinder("LampGlow", 0.43, 0.025, Vector3(-3.6, 2.595, -1.5), _material(Color("ffe2a1"), 0.8, 0.0, 2.0))


func _build_table() -> void:
	Craft.build(self, lane_count)

func _build_opponent() -> void:
	var chair := _material(Color("302d2e"), 0.8)
	_box("ChairBack", Vector3(1.85, 2.35, 0.22), Vector3(0, 0.0, -3.85), chair)
	_box("ChairSeat", Vector3(1.85, 0.18, 1.4), Vector3(0, -1.25, -3.5), chair)
	opponent = OPPONENT_MODEL.instantiate() as Node3D
	opponent.name = "OlderBrother" if opponent_id == "older_brother" else "LittleBrother"
	# Larger seated upper body; feet stay below the tabletop silhouette.
	opponent.position = Vector3(0, -2.25, -2.85)
	opponent.scale = Vector3.ONE * (2.03 if opponent_id == "older_brother" else 1.9)
	add_child(opponent)
	_body_anim = opponent.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for mesh: Node in opponent.find_children("*", "MeshInstance3D", true, false):
		_face_meshes.append(mesh as MeshInstance3D)
	if _body_anim == null:
		return
	_face_anim = AnimationPlayer.new()
	_body_anim.get_parent().add_child(_face_anim)
	_face_anim.root_node = _body_anim.root_node
	for library: StringName in _body_anim.get_animation_library_list():
		_face_anim.add_animation_library(library, _body_anim.get_animation_library(library))
	if _body_anim.has_animation("idle"):
		_body_anim.play("idle")


func set_talking(value: bool) -> void:
	_talking = value
	if _face_anim == null:
		return
	if value and _face_anim.has_animation("talk"):
		_face_anim.play("talk")
	else:
		_face_anim.stop()
		for mesh: MeshInstance3D in _face_meshes:
			for index in mesh.get_blend_shape_count():
				mesh.set_blend_shape_value(index, 0.0)


func react(won: bool) -> void:
	if _reaction:
		_reaction.kill()
	_reaction = create_tween()
	_reaction.tween_property(opponent, "rotation:z", -0.08 if won else 0.06, 0.22)
	_reaction.tween_property(opponent, "rotation:z", 0.0, 0.4)


func _process(delta: float) -> void:
	_blink_clock -= delta
	if _blink_clock <= 0.0:
		_blink_clock = 4.1
		if not _talking and _face_anim != null and _face_anim.has_animation("blink"):
			_face_anim.play("blink")
