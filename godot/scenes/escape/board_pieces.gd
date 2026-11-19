extends RefCounted
## Low-poly playing pieces for the Easter Egg room's board (egg_board.gd), one builder per
## piece so each can be reused or adjusted on its own. Pieces stand on their local origin,
## face +Z and are about 0.1–0.17 m tall. Colours come from the character palette
## (blends/palette/palette.py) so pieces match the characters they stand for.

const Geometry := preload("res://scenes/escape/hub_geometry.gd")

const KINDS := ["phone", "pyramid", "arch", "augmented", "mainframe", "maya_temple", "metric"]


static func build(kind: String) -> Node3D:
	var piece := Node3D.new()
	piece.name = kind.to_pascal_case() + "Piece"
	match kind:
		"phone": _phone(piece)
		"pyramid": _pyramid(piece)
		"arch": _arch(piece)
		"augmented": _augmented(piece)
		"mainframe": _mainframe(piece)
		"maya_temple": _maya_temple(piece)
		"metric": _metric(piece)
		_: push_error("Unknown board piece: " + kind)
	return piece


## The 21st-century player: an upright smartphone on a little stand.
static func _phone(piece: Node3D) -> void:
	_box(piece, Vector3(0, .006, 0), Vector3(.05, .012, .035), "#363b40", .4)
	_box(piece, Vector3(0, .07, -.004), Vector3(.056, .112, .009), "#1d1a18", .3)
	var screen := _mat("#2a4f6a", 0.0, .35)
	Geometry.box(piece, Vector3(0, .072, .0015), Vector3(.048, .098, .002), screen)
	_box(piece, Vector3(-.014, .116, .001), Vector3(.008, .008, .003), "#05090a")  # camera


## Egypt Fractal: a smooth-sided pyramid.
static func _pyramid(piece: Node3D) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = .085
	mesh.height = .12
	mesh.radial_segments = 4
	mesh.rings = 1
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = _mat("#dcc48f")
	view.position.y = .06
	view.rotation.y = PI / 4
	piece.add_child(view)
	var cap := CylinderMesh.new()  # A gilded capstone.
	cap.top_radius = 0.0
	cap.bottom_radius = .016
	cap.height = .022
	cap.radial_segments = 4
	cap.rings = 1
	var tip := MeshInstance3D.new()
	tip.mesh = cap
	tip.material_override = _mat("#e0b73c", .75)
	tip.position.y = .12 - .007
	tip.rotation.y = PI / 4
	piece.add_child(tip)


## Roman Flow: a small round arch on two piers.
static func _arch(piece: Node3D) -> void:
	var stone := "#e3d9bf"
	for side in [-1.0, 1.0]:
		_box(piece, Vector3(side * .045, .045, 0), Vector3(.026, .09, .04), stone)
		_box(piece, Vector3(side * .045, .004, 0), Vector3(.034, .008, .046), "#bdb190")
	var segments := 7
	for i in segments:  # Voussoirs around a semicircle.
		var angle := PI * (i + .5) / segments
		var at := Vector3(cos(angle) * .045, .09 + sin(angle) * .045, 0)
		var block := _box(piece, at, Vector3(.024, .016, .04), stone)
		block.rotation.z = angle - PI / 2
	_box(piece, Vector3(0, .148, 0), Vector3(.13, .016, .044), "#d8ccae")  # entablature


## The Brothers: the 3000s augmented person as a pawn: ceramic body, one chrome
## shoulder, a cyan eye implant and the skull antenna.
static func _augmented(piece: Node3D) -> void:
	_pawn_base(piece, "#4a505a")
	_tapered(piece, .05, .018, .03, .07, "#e6eaee")
	_box(piece, Vector3(0, .1, 0), Vector3(.05, .012, .036), "#e6eaee")  # high collar
	_box(piece, Vector3(.03, .093, 0), Vector3(.024, .02, .034), "#d6dbe2", .7)  # chrome shoulder
	_sphere(piece, Vector3(0, .128, 0), .022, "#c69c7d")
	_box(piece, Vector3(-.01, .155, 0), Vector3(.03, .01, .034), "#e6eaee")  # cranial plate
	_box(piece, Vector3(.009, .131, .021), Vector3(.007, .006, .003), "#5ee8ff", 0.0, 1.2)  # implant
	_box(piece, Vector3(-.012, .182, 0), Vector3(.003, .04, .003), "#d6dbe2", .7)  # antenna


## Workshop: a 1950s mainframe cabinet with two tape reels and a lamp panel.
static func _mainframe(piece: Node3D) -> void:
	_box(piece, Vector3(0, .07, 0), Vector3(.1, .14, .05), "#9ccbb5")
	_box(piece, Vector3(0, .004, 0), Vector3(.104, .008, .054), "#78ad97")
	_box(piece, Vector3(0, .142, 0), Vector3(.104, .006, .054), "#d6dbe2", .7)  # chrome trim
	for side in [-1.0, 1.0]:
		var reel := CylinderMesh.new()
		reel.top_radius = .019
		reel.bottom_radius = .019
		reel.height = .006
		reel.radial_segments = 12
		var view := MeshInstance3D.new()
		view.mesh = reel
		view.material_override = _mat("#6b4a33")
		view.rotation.x = PI / 2
		view.position = Vector3(side * .024, .1, .027)
		piece.add_child(view)
		_box(piece, Vector3(side * .024, .1, .031), Vector3(.008, .008, .003), "#d6dbe2", .7)  # hub
	for i in 5:
		_box(piece, Vector3(-.032 + i * .016, .052, .026), Vector3(.007, .007, .003),
			["#e8b92e", "#c23a2b", "#e8b92e", "#2c8c8e", "#e8b92e"][i], 0.0, .9)
	_box(piece, Vector3(0, .028, .026), Vector3(.07, .012, .003), "#363b40")  # control strip


## Calendar: a stepped Maya temple with a front stair and a shrine on top.
static func _maya_temple(piece: Node3D) -> void:
	var tiers := [[.15, .022], [.118, .022], [.088, .022], [.06, .022]]
	var y := 0.0
	for tier: Array in tiers:
		_box(piece, Vector3(0, y + tier[1] / 2, 0), Vector3(tier[0], tier[1], tier[0]), "#b9b8b2")
		y += tier[1]
	for k in tiers.size():  # A central stair climbing the front of every tier.
		var tier: Array = tiers[k]
		_box(piece, Vector3(0, k * .022 + .011, tier[0] / 2 + .007), Vector3(.03, .022, .014), "#957a54")
	_box(piece, Vector3(0, y + .016, 0), Vector3(.04, .032, .036), "#b27d55")  # shrine
	_box(piece, Vector3(0, y + .012, .0185), Vector3(.014, .02, .002), "#1d1a18")  # doorway
	_box(piece, Vector3(0, y + .036, 0), Vector3(.046, .008, .042), "#3fae86")  # roof comb


## Observatory / Metric pair: a pawn in a long black leather coat and sunglasses.
static func _metric(piece: Node3D) -> void:
	_pawn_base(piece, "#2a2a2f")
	_tapered(piece, .056, .02, .03, .078, "#17171a")  # flared long coat
	_box(piece, Vector3(0, .1, .012), Vector3(.03, .02, .012), "#2a2a2f")  # lapels
	_sphere(piece, Vector3(0, .128, 0), .021, "#6a4430")
	_box(piece, Vector3(0, .132, .019), Vector3(.034, .008, .006), "#05090a")  # sunglasses
	_box(piece, Vector3(.021, .126, .004), Vector3(.004, .006, .006), "#5ee8ff", 0.0, 1.0)  # earpiece LED


static func _pawn_base(piece: Node3D, color: String) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = .03
	disc.bottom_radius = .034
	disc.height = .012
	disc.radial_segments = 12
	var view := MeshInstance3D.new()
	view.mesh = disc
	view.material_override = _mat(color, .4)
	view.position.y = .006
	piece.add_child(view)


static func _tapered(piece: Node3D, bottom: float, top: float, y0: float, height: float, color: String) -> void:
	var body := CylinderMesh.new()
	body.bottom_radius = bottom / 2
	body.top_radius = top
	body.height = height
	body.radial_segments = 10
	var view := MeshInstance3D.new()
	view.mesh = body
	view.material_override = _mat(color)
	view.position.y = y0 + height / 2 - .018
	piece.add_child(view)


static func _sphere(piece: Node3D, at: Vector3, radius: float, color: String) -> void:
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2
	ball.radial_segments = 10
	ball.rings = 6
	var view := MeshInstance3D.new()
	view.mesh = ball
	view.material_override = _mat(color)
	view.position = at
	piece.add_child(view)


static func _box(piece: Node3D, at: Vector3, size: Vector3, color: String, metal := 0.0, glow := 0.0) -> MeshInstance3D:
	return Geometry.box(piece, at, size, _mat(color, metal, glow))


static func _mat(color: String, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	return Geometry.material(Color(color), metal, glow)
