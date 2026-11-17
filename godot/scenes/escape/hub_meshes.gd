extends RefCounted
## Cached chamfered primitives. Small bevel faces catch real lighting at the edges.

static var _boxes: Dictionary = {}


static func chamfer_box(size: Vector3, radius := 0.035) -> ArrayMesh:
	var r := minf(radius, minf(size.x, minf(size.y, size.z)) * 0.22)
	var key := str(size) + ":" + str(r)
	if _boxes.has(key):
		return _boxes[key]
	var half := size * 0.5
	var inner := half - Vector3.ONE * r
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Six large faces.
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for sign_value in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = sign_value
			var points: Array[Vector3] = []
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var point := Vector3.ZERO
				point[axis] = half[axis] * sign_value
				point[u] = inner[u] * corner.x
				point[v] = inner[v] * corner.y
				points.append(point)
			_face(surface, points, normal)
	# Twelve bevel strips.
	for along in 3:
		var u := (along + 1) % 3
		var v := (along + 2) % 3
		for su in [-1.0, 1.0]:
			for sv in [-1.0, 1.0]:
				var normal := Vector3.ZERO
				normal[u] = su
				normal[v] = sv
				var points: Array[Vector3] = []
				for pair in [Vector2(-1, 0), Vector2(1, 0), Vector2(1, 1), Vector2(-1, 1)]:
					var point := Vector3.ZERO
					point[along] = inner[along] * pair.x
					point[u] = su * (half[u] if pair.y == 0 else inner[u])
					point[v] = sv * (inner[v] if pair.y == 0 else half[v])
					points.append(point)
				_face(surface, points, normal.normalized())
	# Eight closed corners.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var signs := Vector3(sx, sy, sz)
				var points: Array[Vector3] = []
				for axis in 3:
					var point := inner
					point[axis] = half[axis]
					points.append(point * signs)
				_face(surface, points, signs.normalized())
	var result := surface.commit()
	_boxes[key] = result
	return result


static func _face(surface: SurfaceTool, points: Array[Vector3], normal: Vector3) -> void:
	# Godot's front faces wind clockwise as viewed from outside.
	if (points[1] - points[0]).cross(points[2] - points[0]).dot(normal) > 0:
		points.reverse()
	for i in range(1, points.size() - 1):
		for point: Vector3 in [points[0], points[i], points[i + 1]]:
			surface.set_normal(normal)
			surface.set_uv(Vector2(point.x + point.z, point.y + point.z))
			surface.add_vertex(point)
