extends RefCounted
## The table's furniture only. Lane coordinates and interaction are owned by the view.
const Meshes := preload("res://scenes/escape/hub_meshes.gd")
const Layout := preload("res://minigames/cards/table_layout.gd")
const Surface := preload("res://minigames/cards/table_surface.gdshader")
static var _materials: Dictionary = {}

static func material(color: Color, roughness := .65, metal := .0) -> StandardMaterial3D:
	var key := str(color) + "/" + str(roughness) + "/" + str(metal)
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		mat.metallic = metal
		_materials[key] = mat
	return _materials[key]

static func surface(color: Color, wood := false) -> ShaderMaterial:
	var key := "surface/" + str(color) + str(wood)
	if not _materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = Surface
		mat.set_shader_parameter("base_color", color)
		mat.set_shader_parameter("wood", wood)
		mat.set_shader_parameter("grain_color", color.lightened(.18))
		mat.set_shader_parameter("finish_roughness", .44 if wood else .96)
		_materials[key] = mat
	return _materials[key]

static func box(parent: Node3D, title: String, size: Vector3, at: Vector3, mat: Material, bevel := .035) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = Meshes.chamfer_box(size, bevel)
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node

static func build(parent: Node3D, lane_count := 3) -> void:
	var extension := Layout.side_extension(lane_count)
	var extra_width := extension * 2
	var wood := surface(Color("302219"), true)
	var rail := surface(Color("4d3423"), true)
	var dark := material(Color("191b18"), .9)
	var brass := material(Color("a58954"), .36, .65)
	var aged_brass := material(Color("66523b"), .6, .5)
	var felt := surface(Color("183e36"))
	var suede := surface(Color("19312e"))
	box(parent, "TableSlab", Vector3(7 + extra_width, .24, 5.8), Vector3(0, -.14, 0), wood, .07)
	box(parent, "LowerMoulding", Vector3(7.03 + extra_width, .065, 5.83), Vector3(0, -.245, 0), dark)
	box(parent, "Felt", Vector3(6.46 + extra_width, .025, 5.26), Vector3(0, -.0075, 0), felt, .01)
	for side in [-1.0, 1.0]:
		box(parent, "SideRail", Vector3(.29, .13, 5.8), Vector3(side * (3.35 + extension), .015, 0), rail)
		box(parent, "EndRail", Vector3(6.45 + extra_width, .13, .29), Vector3(0, .015, side * 2.75), rail)
		box(parent, "RailBead", Vector3(.022, .016, 5.24), Vector3(side * (3.205 + extension), .016, 0), brass, .005)
		box(parent, "EndBead", Vector3(6.4 + extra_width, .016, .022), Vector3(0, .016, side * 2.605), brass, .005)
		box(parent, "FeltInset", Vector3(.012, .008, 5.1), Vector3(side * (3.13 + extension), .014, 0), aged_brass, .003)
		for z in [-2.4, 2.4]:
			box(parent, "TableLeg", Vector3(.27, 1.45, .27), Vector3(side * (2.9 + extension), -.9, z), wood)
			box(parent, "LegCollar", Vector3(.30, .08, .30), Vector3(side * (2.9 + extension), -.45, z), brass)
		for z in [-2.75, 2.75]:
			_corner(parent, Vector3(side * (3.35 + extension), .085, z), brass)
	var corners: Array[Transform3D] = []
	for lane in lane_count:
		var x := Layout.lane_x(lane, lane_count)
		for z in [-.95, .55]:
			# Preserve the original card landing heights and rim bounds.
			box(parent, "CardMatRim", Vector3(1.09, .012, 1.39), Vector3(x, .013, z), aged_brass, .003)
			box(parent, "CardMat", Vector3(1.055, .015, 1.355), Vector3(x, .022, z), suede, .003)
			_collect_corners(corners, Vector3(x, .034, z))
			var count := lane + 1
			for pip in count:
				var diamond := box(parent, "LanePip", Vector3(.035, .006, .035),
					Vector3(x + (pip-(count-1)*.5)*.07, .037, z+.73), brass, .001)
				diamond.rotation.y = PI / 4
	for lane in lane_count - 1:
		var x := Layout.lane_x(lane, lane_count) + Layout.SPACING * .5
		box(parent, "LaneDivider", Vector3(.008, .005, 2.95), Vector3(x, .01, -.2), aged_brass, .001)
	box(parent, "CenterInlay", Vector3(3.7 + extra_width, .006, .012), Vector3(0, .014, -.2), aged_brass, .001)
	_corner_marks(parent, corners, brass)
	_stitching(parent, extension)
	# Small dealer's ornament, safely beyond the incoming row and all raycast targets.
	var medallion := box(parent, "DealerDiamond", Vector3(.13, .006, .13), Vector3(0, .015, -2.04), brass, .001)
	medallion.rotation.y = PI / 4
	for side in [-1.0, 1.0]:
		box(parent, "DealerRule", Vector3(.62, .005, .008), Vector3(side*.49, .014, -2.04), aged_brass, .001)

static func _corner(parent: Node3D, at: Vector3, brass: Material) -> void:
	box(parent, "RailCorner", Vector3(.21, .012, .21), at, brass, .003)
	var screw := CylinderMesh.new()
	screw.top_radius = .022
	screw.bottom_radius = .022
	screw.height = .008
	screw.radial_segments = 12
	for delta in [-.065, .065]:
		var node := MeshInstance3D.new()
		node.mesh = screw
		node.material_override = material(Color("44392b"), .4, .6)
		node.position = at + Vector3(delta, .01, delta)
		parent.add_child(node)

static func _collect_corners(corners: Array[Transform3D], at: Vector3) -> void:
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			corners.append(Transform3D(Basis.IDENTITY, at+Vector3(x*.465, 0, z*.625)))
			corners.append(Transform3D(Basis(Vector3.UP, PI/2), at+Vector3(x*.505, 0, z*.585)))

static func _corner_marks(parent: Node3D, corners: Array[Transform3D], brass: Material) -> void:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = Meshes.chamfer_box(Vector3(.09, .004, .012), .001)
	batch.instance_count = corners.size()
	for i in corners.size():
		batch.set_instance_transform(i, corners[i])
	var node := MultiMeshInstance3D.new()
	node.name = "MatCornerInlays"
	node.multimesh = batch
	node.material_override = brass
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

static func _stitching(parent: Node3D, extension: float) -> void:
	# All stitch segments share a single mesh/draw call, instead of many tiny nodes.
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for side in [-1.0, 1.0]:
		for i in 80:
			var z := -2.48 + i * .062
			mesh.surface_add_vertex(Vector3(side*(3.075 + extension), .013, z))
			mesh.surface_add_vertex(Vector3(side*(3.075 + extension), .013, z+.025))
		for i in ceili((6.04 + extension * 2) / .062):
			var x := -3.02 - extension + i * .062
			mesh.surface_add_vertex(Vector3(x, .013, side*2.49))
			mesh.surface_add_vertex(Vector3(x+.025, .013, side*2.49))
	mesh.surface_end()
	var node := MeshInstance3D.new()
	node.name = "FeltStitching"
	node.mesh = mesh
	node.material_override = material(Color("6c765b"), .95)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
