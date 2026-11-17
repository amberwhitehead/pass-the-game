extends RefCounted
## Cached construction assets. Rounded edges and polished surfaces retain readable light.

const Sign := preload("res://ui/world_sign.gd")
const GLASS := preload("res://scenes/escape/optics_glass.gdshader")
static var _materials: Dictionary = {}
static var _shapes: Dictionary = {}


static func material(color: Color, glow: bool = false, metal: bool = false) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [color.to_html(), glow, metal]
	if _materials.has(key):
		return _materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = 0.72 if metal else 0.0
	result.roughness = 0.29 if metal else 0.65
	if glow:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		result.emission_enabled = true
		result.emission = color
	_materials[key] = result
	return result


static func glass(color: Color) -> ShaderMaterial:
	var key := "glass/" + color.to_html()
	if not _materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = GLASS
		mat.set_shader_parameter("tint", color)
		_materials[key] = mat
	return _materials[key]


static func mesh(parent: Node3D, shape: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.position = at
	instance.material_override = mat
	parent.add_child(instance)
	return instance


static func box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	var key := "box/" + str(size)
	if not _shapes.has(key):
		var shape := BoxMesh.new()
		shape.size = size
		_shapes[key] = shape
	var instance := mesh(parent, _shapes[key], at, mat)
	if solid:
		collision_box(parent, size, at)
	return instance


static func collision_box(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = size
	collision.shape = volume
	body.add_child(collision)
	parent.add_child(body)


static func rounded_box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, bevel := 0.035) -> MeshInstance3D:
	var key := "rounded/%s/%s" % [size, bevel]
	if not _shapes.has(key):
		_shapes[key] = _rounded_mesh(size, bevel)
	return mesh(parent, _shapes[key], at, mat)


static func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var key := "cylinder/%s/%s" % [radius, height]
	if not _shapes.has(key):
		var shape := CylinderMesh.new()
		shape.top_radius = radius
		shape.bottom_radius = radius
		shape.height = height
		shape.radial_segments = 32 if radius > 0.06 else 12
		_shapes[key] = shape
	return mesh(parent, _shapes[key], at, mat)


static func sphere(parent: Node3D, radius: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var key := "sphere/" + str(radius)
	if not _shapes.has(key):
		var shape := SphereMesh.new()
		shape.radius = radius
		shape.height = radius * 2
		shape.radial_segments = 32
		shape.rings = 16
		_shapes[key] = shape
	return mesh(parent, _shapes[key], at, mat)


static func ring(parent: Node3D, inner: float, outer: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var key := "ring/%s/%s" % [inner, outer]
	if not _shapes.has(key):
		var torus := TorusMesh.new()
		torus.inner_radius = inner
		torus.outer_radius = outer
		torus.rings = 40
		torus.ring_segments = 10
		_shapes[key] = torus
	return mesh(parent, _shapes[key], at, mat)


static func line(parent: Node3D, a: Vector3, b: Vector3, mat: Material, width: float = 0.018) -> MeshInstance3D:
	var offset := b - a
	var part := cylinder(parent, width, offset.length(), (a + b) * 0.5, mat)
	if offset.length() > 0.0001:
		part.quaternion = Quaternion(Vector3.UP, offset.normalized())
	return part


static func label(parent: Node3D, text: String, at: Vector3, size: int = 28, color: Color = Color.WHITE, distance: float = 7.0) -> Label3D:
	var part := Label3D.new()
	part.text = text
	Sign.style(part, size * .0038, color)
	part.position = at
	part.modulate = color
	part.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	part.visibility_range_end = distance
	part.visibility_range_end_margin = 0.35 if distance > 0 else 0.0
	parent.add_child(part)
	return part


static func prism_mesh() -> ArrayMesh:
	if _shapes.has("prism"):
		return _shapes.prism
	var corners := [Vector2(-0.23, -0.20), Vector2(0.23, -0.20), Vector2(0, 0.24)]
	var profile: Array[Vector2] = []
	for i in 3:
		profile.append(corners[i].lerp(corners[(i+2)%3], 0.10))
		profile.append(corners[i].lerp(corners[(i+1)%3], 0.10))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		for i in profile.size():
			var j := (i + 1) % profile.size()
			var a := Vector3(profile[i].x * .91, profile[i].y * .91, side * .18)
			var b := Vector3(profile[j].x * .91, profile[j].y * .91, side * .18)
			_triangle(st, Vector3(0, 0, side * .18), a, b, Vector3.BACK * side)
			var c := Vector3(profile[i].x, profile[i].y, side * .15)
			var d := Vector3(profile[j].x, profile[j].y, side * .15)
			var bevel_normal := Vector3((a+b).x, (a+b).y, side * .4).normalized()
			_triangle(st, a, c, d, bevel_normal)
			_triangle(st, a, d, b, bevel_normal)
	for i in profile.size():
		var j := (i + 1) % profile.size()
		var a := Vector3(profile[i].x, profile[i].y, -.15)
		var b := Vector3(profile[j].x, profile[j].y, -.15)
		var c := Vector3(profile[j].x, profile[j].y, .15)
		var d := Vector3(profile[i].x, profile[i].y, .15)
		var edge: Vector2 = profile[j] - profile[i]
		var normal := Vector3(edge.y, -edge.x, 0).normalized()
		_triangle(st, a, b, c, normal)
		_triangle(st, a, c, d, normal)
	_shapes.prism = st.commit()
	return _shapes.prism


static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	# Godot's clockwise front faces point opposite the mathematical cross product.
	var points := [a, c, b] if (b-a).cross(c-a).dot(normal) > 0 else [a, b, c]
	for point: Vector3 in points:
		st.set_normal(normal)
		st.set_uv(Vector2(point.x + point.z, point.y) * 2.0 + Vector2.ONE * .5)
		st.add_vertex(point)


static func _rounded_mesh(size: Vector3, radius: float) -> ArrayMesh:
	var half := size * .5
	var bevel := minf(radius, minf(half.x, minf(half.y, half.z)) * .9)
	var inner := half - Vector3.ONE * bevel
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var us := [-half[u], -inner[u], inner[u], half[u]]
		var vs := [-half[v], -inner[v], inner[v], half[v]]
		for side: float in [-1.0, 1.0]:
			for i in 3:
				for j in 3:
					var vertices: Array[Vector3] = []
					for uv in [Vector2(us[i], vs[j]), Vector2(us[i+1], vs[j]), Vector2(us[i+1], vs[j+1]), Vector2(us[i], vs[j+1])]:
						var p := Vector3.ZERO
						p[axis] = side * half[axis]
						p[u] = uv.x
						p[v] = uv.y
						var q := p.clamp(-inner, inner)
						vertices.append(q + (p-q).normalized() * bevel)
					var normal := Vector3.ZERO
					normal[axis] = side
					_rounded_triangle(st, vertices[0], vertices[1], vertices[2], normal, inner)
					_rounded_triangle(st, vertices[0], vertices[2], vertices[3], normal, inner)
	return st.commit()


static func _rounded_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, face: Vector3, inner: Vector3) -> void:
	var points := [a, c, b] if (b-a).cross(c-a).dot(face) > 0 else [a, b, c]
	for point: Vector3 in points:
		st.set_normal((point-point.clamp(-inner, inner)).normalized())
		st.set_uv(Vector2(point.x + point.z, point.y))
		st.add_vertex(point)
