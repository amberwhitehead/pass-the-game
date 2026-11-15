class_name HexFloor
extends Node3D
## Rectangular patch of illuminated hexagon tiles (pointy-top, odd rows offset).
## `columns` x `rows` tiles, each `tile_size` metres flat-to-flat. Tiles glow
## brighter near whatever you pass to update_glow() (the player).
## After _ready, room_width / room_length give the footprint for walls.

const TILE_SHADER := preload("res://shaders/hex_tile.gdshader")

@export var columns := 5
@export var rows := 8
@export var tile_size := 2.0

var room_width := 0.0
var room_length := 0.0

var _multi: MultiMesh
var _centers: PackedVector3Array = PackedVector3Array()
var _phase: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	var apothem := tile_size / 2.0
	var radius := apothem / cos(deg_to_rad(30.0))   # centre-to-corner
	var row_step := 1.5 * radius

	room_width = columns * tile_size + tile_size / 2.0
	room_length = (rows - 1) * row_step + 2.0 * radius

	# Tile centres, centred around the node's origin.
	var x_span := (columns - 1) * tile_size + tile_size / 2.0
	var z_span := (rows - 1) * row_step
	for r in rows:
		for c in columns:
			var x := c * tile_size + (tile_size / 2.0 if r % 2 == 1 else 0.0) - x_span / 2.0
			var z := r * row_step - z_span / 2.0
			_centers.append(Vector3(x, 0.02, z))
			_phase.append(randf())

	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_custom_data = true
	_multi.mesh = _hex_mesh(radius)
	_multi.instance_count = _centers.size()
	for i in _centers.size():
		_multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, _centers[i]))
		_multi.set_instance_custom_data(i, Color(0, _phase[i], 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _multi
	add_child(mmi)

	# Dark slab under the tiles (shows through the seams) + collision.
	var slab := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(room_width + 2.0, 0.2, room_length + 2.0)
	shape.shape = box
	shape.position.y = -0.1
	slab.add_child(shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(room_width, 0.2, room_length)
	mi.mesh = bm
	mi.position.y = -0.1
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.01, 0.012, 0.02)
	mi.material_override = dark
	slab.add_child(mi)
	add_child(slab)


func update_glow(world_pos: Vector3, reach := 4.5) -> void:
	var local := to_local(world_pos)
	for i in _centers.size():
		var d := Vector2(_centers[i].x - local.x, _centers[i].z - local.z).length()
		var g := clampf(1.0 - d / reach, 0.0, 1.0)
		_multi.set_instance_custom_data(i, Color(g * g, _phase[i], 0, 0))


func _hex_mesh(radius: float) -> ArrayMesh:
	var verts := PackedVector3Array([Vector3.ZERO])
	var uvs := PackedVector2Array([Vector2(0.5, 0.5)])
	var normals := PackedVector3Array([Vector3.UP])
	for k in 6:
		var a := deg_to_rad(60.0 * k + 90.0)   # corner pointing along +z first
		var v := Vector3(cos(a), 0.0, sin(a)) * radius
		verts.append(v)
		uvs.append(Vector2(v.x, v.z) / (2.0 * radius) + Vector2(0.5, 0.5))
		normals.append(Vector3.UP)
	var idx := PackedInt32Array()
	for k in 6:
		idx.append_array([0, 1 + k, 1 + (k + 1) % 6])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = TILE_SHADER
	mesh.surface_set_material(0, mat)
	return mesh
