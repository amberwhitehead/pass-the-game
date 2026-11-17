extends RefCounted
## Wall-mounted infrastructure. Added detail stays off the shared puzzle floor.
## Hundreds of small fasteners and pipe segments use three shared batches.

const Geometry := preload("res://scenes/escape/hub_geometry.gd")
const Meshes := preload("res://scenes/escape/hub_meshes.gd")
const ServerPanels := preload("res://scenes/room/greebles.gd")
const NORTH := [[-10.55, -7.85], [-4.15, 0.15], [3.85, 10.55]]
const SOUTH := [[-10.55, -8.85], [-5.15, -1.85], [1.85, 5.15], [8.85, 10.55]]
var _boxes: Array[Transform3D] = []
var _pipes: Array[Transform3D] = []
var _bolts: Array[Transform3D] = []


static func build(parent: Node3D) -> void:
	var details := Node3D.new()
	details.name = "HallInfrastructure"
	parent.add_child(details)
	var builder := new()
	var sections: Array = []
	for side in [-1.0, 1.0]:
		var bays: Array = NORTH if side < 0 else SOUTH
		for i in bays.size():
			var bay: Array = bays[i]
			sections.append({"side": side, "wall": 7.82, "x0": bay[0] + .08,
				"x1": bay[1] - .08, "y0": .57, "y1": 3.35})
			builder._rack_surround(details, side, bay, i)
		builder._ceiling_conduits(side)
	var count := ServerPanels.build_sections(details, sections)
	details.set_meta("server_detail_count", count)
	builder._emit(details)


func _rack_surround(parent: Node3D, side: float, bay: Array, index: int) -> void:
	var center: float = (bay[0] + bay[1]) * .5
	var width: float = bay[1] - bay[0]
	var z := side * 7.78
	_rect(Vector3(center, .39, z), Vector3(width, .28, .26))
	_rect(Vector3(center, 3.49, z), Vector3(width, .22, .30))
	for x: float in [bay[0], bay[1]]:
		_rect(Vector3(x, 1.94, z), Vector3(.10, 3.3, .26))
		for y in [.43, 1.1, 2.65, 3.46]:
			_bolt(Vector3(x, y, side * 7.62), Vector3(0, 0, -side))
	# A lower kick plate and proper rack header make the restored panel field read
	# as a bank of machines rather than scattered boxes on a bare wall.
	var title: String = ["MEMORY BANK", "POWER DISTRIBUTION", "CHRONOLOGY", "ARCHIVE"][index % 4]
	var heading := Geometry.label(parent, "%s  /  %02d" % [title, index + 1],
		Vector3(center, 3.50, side * 7.59), 0 if side < 0 else PI,
		Color(.63, .73, .75), 21, .003)
	heading.visibility_range_end = 12


func _ceiling_conduits(side: float) -> void:
	for level in [4.48, 4.77]:
		_pipe(Vector3(-10.55, level, side * 7.46), Vector3(10.55, level, side * 7.46), .065)
		for x in [-10.2, -8.2, -6.2, -4.2, -2.2, -.2, 1.8, 3.8, 5.8, 7.8, 9.8]:
			_rect(Vector3(x, level, side * 7.5), Vector3(.08, .24, .24))
	# Vertical return legs are against the outer wall, leaving every portal clear.
	_pipe(Vector3(-10.55, .5, side * 7.46), Vector3(-10.55, 4.77, side * 7.46), .065)
	for y in [1.0, 2.5, 4.0]:
		_rect(Vector3(-10.55, y, side * 7.51), Vector3(.24, .08, .24))


func _rect(at: Vector3, size: Vector3) -> void:
	_boxes.append(Transform3D(Basis.from_scale(size), at))


func _pipe(a: Vector3, b: Vector3, radius: float) -> void:
	var basis := Basis(Quaternion(Vector3.UP, (b-a).normalized()))
	basis = basis * Basis.from_scale(Vector3(radius, a.distance_to(b), radius))
	_pipes.append(Transform3D(basis, (a+b)*.5))


func _bolt(at: Vector3, normal: Vector3) -> void:
	var basis := Basis(Quaternion(Vector3.UP, normal)) * Basis.from_scale(Vector3(.028, .022, .028))
	_bolts.append(Transform3D(basis, at))


func _emit(parent: Node3D) -> void:
	var pipe_mesh := CylinderMesh.new()
	pipe_mesh.top_radius = 1
	pipe_mesh.bottom_radius = 1
	pipe_mesh.height = 1
	pipe_mesh.radial_segments = 32
	var bolt_mesh := CylinderMesh.new()
	bolt_mesh.top_radius = 1
	bolt_mesh.bottom_radius = 1
	bolt_mesh.height = 1
	bolt_mesh.radial_segments = 8
	var casing := Geometry.surface(Color(.18, .22, .24), .7, .4)
	var copper := Geometry.surface(Color(.27, .19, .115), .72, .32)
	var steel := Geometry.material(Color(.4, .44, .46), .8)
	_batch(parent, Meshes.chamfer_box(Vector3.ONE, .08), casing, _boxes, "RackFrames")
	_batch(parent, pipe_mesh, copper, _pipes, "ServicePipes")
	_batch(parent, bolt_mesh, steel, _bolts, "RackFasteners")


static func _batch(parent: Node3D, mesh: Mesh, material: Material,
		transforms: Array[Transform3D], title: String) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index in transforms.size():
		multi.set_instance_transform(index, transforms[index])
	var view := MultiMeshInstance3D.new()
	view.name = title
	view.multimesh = multi
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
