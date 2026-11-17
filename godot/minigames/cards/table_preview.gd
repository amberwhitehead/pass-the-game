extends Node3D
## Hover paths use only visible cards and candidate placement; never hidden intents.
var _surface: MeshInstance3D
var _key := ""

func _ready() -> void:
	_surface = MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_surface.material_override = material
	_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_surface)

func clear() -> void:
	visible = false
	_key = ""

func show_paths(table: Control, side: String, lane: int, card: Dictionary, state: Dictionary) -> void:
	var ability: String = card.get("ability", "")
	if card.is_empty() or card.get("kind", "unit") != "unit" or ability not in ["diagonal", "intercept"]:
		clear()
		return
	var targets: Array[int] = []
	for target in [lane - 1, lane + 1]:
		if target >= 0 and target < table.lane_count:
			if ability == "diagonal" or (card.get("intercept_ready", true) and state[side][target].is_empty()):
				targets.append(target)
	var key := str([side, lane, ability, targets])
	visible = not targets.is_empty()
	if key == _key or targets.is_empty():
		return
	_key = key
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var color := Color("e8bd70") if ability == "diagonal" else Color("82c7c0")
	var source: Vector3 = table.lane_position(side, lane)
	for target in targets:
		if ability == "diagonal":
			var direction := -1.0 if side == "player" else 1.0
			var other := "enemy" if side == "player" else "player"
			var end: Vector3 = table.lane_position(other, target)
			_arrow(mesh, source + Vector3(0, .11, direction * .36), end + Vector3(0, .11, -direction * .42), color)
		else:
			var end: Vector3 = table.lane_position(side, target)
			# Route interception cues near the top edge so the card face remains readable.
			var margin := Vector3(0, .10, -.50)
			_arrow(mesh, source + margin, end + margin, color)
	mesh.surface_end()
	_surface.mesh = mesh

func _arrow(mesh: ImmediateMesh, start: Vector3, end: Vector3, color: Color) -> void:
	var direction := (end - start).normalized()
	var across := direction.cross(Vector3.UP).normalized()
	var neck := end - direction * .13
	_quad(mesh, start - across * .018, start + across * .018, neck + across * .018, neck - across * .018, color)
	_triangle(mesh, end, neck - across * .085, neck + across * .085, color)

func _quad(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_triangle(mesh, a, b, c, color)
	_triangle(mesh, a, c, d, color)

func _triangle(mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for point in [a, b, c]:
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(point)
