extends RefCounted
## Fixed instruments for Door 2. Receiver is a wall fitting, not a freestanding post.

const Sign := preload("res://ui/world_sign.gd")
const Art := preload("res://scenes/escape/optics_art.gd")


static func build_receiver(parent: Node3D, position: Vector3) -> Dictionary:
	var root := Node3D.new()
	root.name = "DoorReceiver"
	# Broad aperture catches the straight calibration ray and the diagonal final ray.
	root.position = position + Vector3(-.06, 0, 0)
	root.rotation.y = -PI / 2.0
	parent.add_child(root)
	var steel := Art.material(Color(.22, .29, .32), false, true)
	var dark := Art.material(Color(.035, .06, .065), false, true)
	var brass := Art.material(Color(.62, .48, .25), false, true)
	var green := Art.material(Color(.17, .8, .42), true)
	# Stand proud of the door moulding; the sensor housing contains the ray endpoint.
	Art.rounded_box(root, Vector3(.38, .58, .32), Vector3(0, -.02, -.21), dark, .035)
	Art.rounded_box(root, Vector3(.64, .78, .15), Vector3(0, -.02, -.12), steel, .045)
	Art.rounded_box(root, Vector3(.54, .67, .04), Vector3(0, -.02, -.025), dark, .025)
	var bezel := Art.ring(root, .214, .247, Vector3(0, 0, .015), brass)
	bezel.rotation.x = PI / 2.0
	var target := Art.ring(root, .188, .210, Vector3(0, 0, .033), green)
	target.rotation.x = PI / 2.0
	var core := Art.cylinder(root, .17, .025, Vector3(0, 0, .025), green)
	core.rotation.x = PI / 2.0
	for x in [-.265, .265]:
		for y in [-.33, .29]:
			var bolt := Art.cylinder(root, .021, .015, Vector3(x, y, -.004), brass)
			bolt.rotation.x = PI / 2.0
	for pair in [[-.075, Color(1, .72, .08)], [.075, Color(.15, .48, 1)]]:
		var dot := Art.cylinder(root, .023, .015, Vector3(pair[0], -.25, .012), Art.material(pair[1], true))
		dot.rotation.x = PI / 2.0
	var sign := Sign.plaque(root, "GREEN REQUIRED", "02 / LIGHT RECEIVER", Vector3(0, .58, .03), Vector2(1.03, .32), Sign.Style.TEAL)
	var label: Label3D = sign.title
	# Recessed conduit enters the frame above the instrument, never across the floor.
	Art.line(root, Vector3(.22, .28, -.10), Vector3(.22, 1.3, -.10), steel, .025)
	return {"root": root, "core": core, "label": label}


static func build_engine(parent: Node3D, position: Vector3, size: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "OpticalRelayCabinet"
	root.position = position
	parent.add_child(root)
	var metal := Art.material(Color(.21, .27, .29), false, true)
	var trim := Art.material(Color(.39, .43, .43), false, true)
	var dark := Art.material(Color(.045, .065, .075), false, true)
	var brass := Art.material(Color(.61, .45, .23), false, true)
	Art.rounded_box(root, size, Vector3.ZERO, metal, .08)
	Art.collision_box(root, size, Vector3.ZERO)
	var front := size.z * .5
	var left := -size.x * .5
	Art.rounded_box(root, Vector3(.025, size.y-.20, size.z-.22), Vector3(left-.004, 0, 0), trim, .01)
	Art.rounded_box(root, Vector3(.03, size.y-.31, size.z-.33), Vector3(left-.018, 0, 0), dark, .01)
	var side_fins: Array[Transform3D] = []
	for i in 13:
		side_fins.append(Transform3D(Basis(Vector3.UP, PI*.5), Vector3(left-.038, -.65+i*.11, 0)))
	_batch_boxes(root, Vector3(size.z*.68, .026, .024), side_fins, trim)
	Art.rounded_box(root, Vector3(size.x-.18, size.y-.18, .035), Vector3(0, 0, front-.025), dark, .016)
	for side: float in [-1.0, 1.0]:
		Art.rounded_box(root, Vector3(.07, size.y-.16, .045), Vector3(side*(size.x*.5-.07), 0, front-.021), trim, .015)
		Art.rounded_box(root, Vector3(size.x-.12, .07, size.z-.08), Vector3(0, side*(size.y*.5-.07), 0), trim, .025)
	# Repeated ventilation fins and fasteners each use one instanced batch.
	var vents: Array[Transform3D] = []
	for i in 17:
		vents.append(Transform3D(Basis.IDENTITY, Vector3(0, -.87+i*.058, front+.002)))
	_batch_boxes(root, Vector3(size.x*.68, .018, .023), vents, trim)
	var bolts: Array[Transform3D] = []
	for x in [-size.x*.5+.13, size.x*.5-.13]:
		for y in [-size.y*.5+.13, 0.0, size.y*.5-.13]:
			bolts.append(Transform3D(Basis.IDENTITY, Vector3(x, y, front+.007)))
	_batch_boxes(root, Vector3(.033, .033, .02), bolts, brass)
	Art.rounded_box(root, Vector3(size.x*.66, .39, .035), Vector3(-.04, .56, front+.008), metal, .035)
	Art.rounded_box(root, Vector3(size.x*.55, .24, .014), Vector3(-.04, .57, front+.031), Art.material(Color(.07, .19, .19), true), .018)
	for i in 7:
		Art.box(root, Vector3(.055, .012, .009), Vector3(-.34+i*.1, .61, front+.043), Art.material(Color(.45, .7, .6), true))
	Art.box(root, Vector3(.015, .135, .01), Vector3(.11, .57, front+.047), Art.material(Color(.9, .69, .34), true))
	var nameplate := Art.label(root, "OPTICAL RELAY  /  02", Vector3(0, .97, front+.035), 24, Color(.78, .82, .75), 6.0)
	nameplate.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	nameplate.pixel_size = .0024
	var serial := Art.label(root, "QUARTER-TURN ARRAY", Vector3(0, .30, front+.035), 17, Color(.55, .64, .64), 3.5)
	serial.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	serial.pixel_size = .0025
	return root


static func _batch_boxes(parent: Node3D, size: Vector3, transforms: Array[Transform3D], material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mm := MultiMesh.new()
	mm.mesh = mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var view := MultiMeshInstance3D.new()
	view.multimesh = mm
	view.material_override = material
	parent.add_child(view)
