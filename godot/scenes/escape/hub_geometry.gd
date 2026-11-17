extends RefCounted
## Shared chamfered geometry and tactile materials; resources are reused by the hub shell.

const Meshes := preload("res://scenes/escape/hub_meshes.gd")
const Sign := preload("res://ui/world_sign.gd")
const SURFACE := preload("res://scenes/escape/hub_surface.gdshader")


static func material(color: Color, metal := 0.0, emission := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.42 if metal > 0.4 else 0.65
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat


static func box(parent: Node3D, at: Vector3, size: Vector3, mat: Material,
		collidable := false) -> MeshInstance3D:
	var mesh := Meshes.chamfer_box(size)
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = mat
	view.position = at
	parent.add_child(view)
	if collidable:
		var body := StaticBody3D.new()
		body.position = at
		var shape := CollisionShape3D.new()
		var volume := BoxShape3D.new()
		volume.size = size
		shape.shape = volume
		body.add_child(shape)
		parent.add_child(body)
	return view


static func floor_tiles(parent: Node3D, center: Vector3, size: Vector2,
		base: Material, tile: Material) -> void:
	box(parent, center + Vector3(0, -0.13, 0), Vector3(size.x, 0.24, size.y), base, true)
	var columns := ceili(size.x / 1.5)
	var rows := ceili(size.y / 1.5)
	var width := size.x / columns
	var depth := size.y / rows
	var mesh := Meshes.chamfer_box(Vector3(width - 0.022, 0.035, depth - 0.022), 0.018)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = columns * rows
	for x in columns:
		for z in rows:
			var origin := center + Vector3(-size.x / 2.0 + width * (x + 0.5),
				-0.002, -size.y / 2.0 + depth * (z + 0.5))
			multi.set_instance_transform(x * rows + z, Transform3D(Basis.IDENTITY, origin))
			var variation := 0.94 + float((x * 17 + z * 31) % 11) * 0.012
			multi.set_instance_color(x * rows + z, Color(variation, variation, variation, 1))
	var view := MultiMeshInstance3D.new()
	view.name = "BatchedFloorPanels"
	view.multimesh = multi
	view.material_override = tile
	parent.add_child(view)


static func label(parent: Node3D, text: String, at: Vector3, yaw: float,
		color := Color(0.82, 0.91, 0.95), font_size := 36, pixel_size := 0.006) -> Label3D:
	var view := Label3D.new()
	view.text = text
	view.position = at
	view.rotation.y = yaw
	Sign.style(view, font_size * pixel_size, color)
	parent.add_child(view)
	return view


static func lamp(parent: Node3D, at: Vector3, color: Color, radius: float,
		energy := 1.0) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.omni_range = radius
	light.light_energy = energy
	light.shadow_enabled = false
	parent.add_child(light)


static func surface(color: Color, metal := 0.5, roughness := 0.46) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SURFACE
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("metalness", metal)
	mat.set_shader_parameter("surface_roughness", roughness)
	return mat
