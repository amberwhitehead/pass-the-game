extends Node3D
## A live, screen-projected window into the table, placed in the source 3D world.
## The launcher moves the source camera and changes ownership only after covers_view().

const SURFACE_SHADER := preload("res://minigames/cards/table_portal.gdshader")
const DISTANCE := 2.4
const RIM_WIDTH := 0.045
var source_anchor := Transform3D.IDENTITY
var aperture_size := Vector2.ZERO
var progress := 0.0
var aperture_transform: Transform3D:
	get:
		return _opening.global_transform if _opening != null else global_transform
var _camera: Camera3D
var _opening: Node3D
var _surface: MeshInstance3D
var _rims: Array[MeshInstance3D] = []
var _light: OmniLight3D


func configure(source_camera: Camera3D, destination_texture: Texture2D) -> void:
	_camera = source_camera
	source_anchor = source_camera.global_transform
	global_transform = source_anchor.translated_local(Vector3(0, 0, -DISTANCE))
	process_mode = Node.PROCESS_MODE_ALWAYS
	_opening = Node3D.new()
	_opening.name = "Opening"
	add_child(_opening)
	_surface = MeshInstance3D.new()
	_surface.name = "LiveDestination"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_surface.mesh = quad
	_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SURFACE_SHADER
	material.render_priority = 127
	material.set_shader_parameter("destination", destination_texture)
	_surface.material_override = material
	_opening.add_child(_surface)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("c7a363")
	brass.metallic = 0.55
	brass.roughness = 0.35
	brass.emission_enabled = true
	brass.emission = Color("5a3b14")
	brass.no_depth_test = true
	brass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	brass.render_priority = 127
	for index in 4:
		var rim := MeshInstance3D.new()
		rim.name = "Rim%d" % index
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		rim.mesh = box
		rim.material_override = brass
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_opening.add_child(rim)
		_rims.append(rim)
	_light = OmniLight3D.new()
	_light.position.z = 0.3
	_light.light_color = Color("e9bd76")
	_light.omni_range = 4.0
	_opening.add_child(_light)
	set_progress(0.0)


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	visible = progress > 0.0
	if _opening == null:
		return
	var unfold := smoothstep(0.0, 0.30, progress)
	var growth := smoothstep(0.35, 1.0, progress)
	var projection := _camera.get_camera_projection()
	var projection_depth := 1.0 if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL else DISTANCE
	# Derive the final opening from the actual frustum, including unusual aspect ratios.
	var final_size := Vector2(maxf(2.79, projection_depth / absf(projection.x.x)), maxf(3.78, projection_depth / absf(projection.y.y)))
	aperture_size = Vector2(lerpf(0.018, 1.55, unfold), lerpf(0.08, 2.1, unfold)).lerp(final_size, growth)
	_opening.rotation = Vector3(0, lerpf(deg_to_rad(-72.0), 0.0, smoothstep(0.0, 0.45, progress)), 0.08 * sin(progress * PI))
	_surface.scale = Vector3(aperture_size.x, aperture_size.y, 1)
	for side in [-1.0, 1.0]:
		var index := 0 if side < 0 else 1
		var upright := _rims[index]
		upright.position = Vector3(side * (aperture_size.x + RIM_WIDTH) * 0.5, 0, 0.025)
		upright.scale = Vector3(RIM_WIDTH, aperture_size.y + 2 * RIM_WIDTH, 0.075)
		var rail := _rims[index + 2]
		rail.position = Vector3(0, side * (aperture_size.y + RIM_WIDTH) * 0.5, 0.025)
		rail.scale = Vector3(aperture_size.x, RIM_WIDTH, 0.075)
	_light.light_energy = 0.85 * unfold


func projected_polygon() -> PackedVector2Array:
	var polygon := PackedVector2Array()
	if _camera == null or _opening == null:
		return polygon
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var point := _opening.to_global(Vector3(corner.x * aperture_size.x * 0.5, corner.y * aperture_size.y * 0.5, 0))
		if _camera.is_position_behind(point):
			return PackedVector2Array()
		polygon.append(_camera.unproject_position(point))
	return polygon


func covers_view(margin_pixels: float = 8.0) -> bool:
	# Coverage is a geometric condition, not a guessed elapsed-time threshold.
	if not visible or _camera == null:
		return false
	var distance := aperture_transform.basis.z.dot(_camera.global_position - aperture_transform.origin)
	if distance <= _camera.near * 1.5:
		return false
	var polygon := projected_polygon()
	if polygon.size() != 4:
		return false
	var size := _camera.get_viewport().get_visible_rect().size
	for corner in [Vector2(-margin_pixels, -margin_pixels), Vector2(size.x + margin_pixels, -margin_pixels), size + Vector2.ONE * margin_pixels, Vector2(-margin_pixels, size.y + margin_pixels)]:
		if not Geometry2D.is_point_in_polygon(corner, polygon):
			return false
	return true
