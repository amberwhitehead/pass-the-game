extends RefCounted
## Quiet card-parlour details. All coordinates are local to the brothers' chamber.
const Craft := preload("res://minigames/cards/table_craft.gd")
const Sign := preload("res://ui/world_sign.gd")


static func build(room: Node3D) -> void:
	var root := Node3D.new()
	root.name = "CardRoomDetails"
	room.add_child(root)
	var materials := {
		"wood": Craft.surface(Color("302219"), true),
		"rail": Craft.surface(Color("4d3423"), true),
		"felt": Craft.surface(Color("183e36")),
		"brass": Craft.material(Color("a58954"), .36, .65),
		"aged": Craft.material(Color("66523b"), .6, .5),
		"dark": Craft.material(Color("151d1c"), .8),
		"green": Craft.material(Color("163f32"), .27, .22),
		"paper": Craft.material(Color("cabd98"), .92),
	}
	_credenza(root, materials)
	_wall_emblem(root, -1.12, 3, "A FRIENDLY GAME", materials)
	_wall_emblem(root, 1.12, 4, "A LARGER WAGER", materials)
	for side in [-1.0, 1.0]:
		_sconce(root, side, materials)
		_side_plaque(root, side)
	_pendant(root, materials)


static func _credenza(root: Node3D, m: Dictionary) -> void:
	var cabinet := Node3D.new()
	cabinet.name = "CardCabinet"
	cabinet.position = Vector3(0, 0, 2.78)
	root.add_child(cabinet)
	Craft.box(cabinet, "CabinetBody", Vector3(4.9, .66, .51), Vector3(0, .45, 0), m.wood)
	Craft.box(cabinet, "TopRail", Vector3(5.04, .085, .6), Vector3(0, .82, 0), m.rail)
	Craft.box(cabinet, "TopBead", Vector3(4.96, .014, .57), Vector3(0, .865, 0), m.brass, .003)
	Craft.box(cabinet, "TopFelt", Vector3(4.82, .012, .46), Vector3(0, .878, 0), m.felt, .003)
	Craft.box(cabinet, "LowerMoulding", Vector3(4.96, .07, .55), Vector3(0, .14, 0), m.rail)
	for x in [-1.65, 0.0, 1.65]:
		Craft.box(cabinet, "InsetDoor", Vector3(1.5, .47, .025), Vector3(x, .45, -.27), m.rail, .008)
		var field := Craft.box(cabinet, "RecessedDoorField", Vector3(1.34, .018, .32), Vector3(x, .45, -.286), m.wood, .004)
		field.rotation.x = PI / 2
		var pull := _cylinder(cabinet, "BrassPull", .018, .18, Vector3(x, .60, -.322), m.brass)
		pull.rotation.z = PI / 2
	for x in [-2.18, 2.18]:
		for z in [-.17, .17]:
			Craft.box(cabinet, "CabinetFoot", Vector3(.14, .18, .14), Vector3(x, .09, z), m.wood, .025)
	# A single body follows the rear cabinet, never the path to either brother.
	var body := StaticBody3D.new()
	body.name = "CabinetCollision"
	var shape := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(4.9, .85, .52)
	shape.shape = volume
	shape.position.y = .425
	body.add_child(shape)
	cabinet.add_child(body)
	_card_box(cabinet, Vector3(-1.76, .9, -.03), -.12, m)
	_card_box(cabinet, Vector3(-1.08, .9, .035), .07, m)
	_chip_tray(cabinet, Vector3(.1, .9, -.02), m)
	_books(cabinet, Vector3(1.59, .9, .015), m)


static func _card_box(parent: Node3D, at: Vector3, yaw: float, m: Dictionary) -> void:
	var box := Node3D.new()
	box.name = "DeckCase"
	box.position = at
	box.rotation.y = yaw
	parent.add_child(box)
	Craft.box(box, "Case", Vector3(.44, .17, .30), Vector3(0, .085, 0), m.wood, .018)
	Craft.box(box, "Lid", Vector3(.46, .035, .32), Vector3(0, .185, 0), m.rail, .009)
	Craft.box(box, "LidInlay", Vector3(.27, .008, .19), Vector3(0, .207, 0), m.felt, .003)
	Craft.box(box, "Clasp", Vector3(.065, .065, .015), Vector3(0, .15, -.17), m.brass, .004)
	var pip := Craft.box(box, "DiamondInlay", Vector3(.055, .007, .055), Vector3(0, .215, 0), m.brass, .001)
	pip.rotation.y = PI / 4


static func _chip_tray(parent: Node3D, at: Vector3, m: Dictionary) -> void:
	Craft.box(parent, "ChipTray", Vector3(1.25, .055, .36), at, m.rail, .025)
	Craft.box(parent, "TrayLining", Vector3(1.15, .012, .27), at + Vector3.UP * .032, m.felt, .006)
	for column in 4:
		var height := 3 + column % 3
		for level in height:
			var chip := _cylinder(parent, "WagerToken", .092, .024,
				at + Vector3(-.43 + column * .28, .055 + level * .026, 0), m.brass if column % 2 == 0 else m.green)
			chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cylinder(parent, "TokenFace", .064, .005,
			at + Vector3(-.43 + column * .28, .055 + (height - 1) * .026 + .015, 0), m.aged)


static func _books(parent: Node3D, at: Vector3, m: Dictionary) -> void:
	for index in 3:
		var book := Node3D.new()
		book.name = "GameLedger"
		book.position = at + Vector3(index * .025, index * .07, 0)
		book.rotation.y = -.08 + index * .08
		parent.add_child(book)
		Craft.box(book, "Pages", Vector3(.63, .045, .33), Vector3(0, .035, 0), m.paper, .006)
		for y in [.006, .064]:
			Craft.box(book, "Cover", Vector3(.67, .014, .37), Vector3(0, y, 0), m.green if index != 1 else m.rail, .004)
		Craft.box(book, "Spine", Vector3(.04, .065, .37), Vector3(-.32, .035, 0), m.rail, .006)
		for z in [-.115, .115]:
			Craft.box(book, "SpineBand", Vector3(.045, .068, .018), Vector3(-.322, .035, z), m.brass, .002)


static func _wall_emblem(parent: Node3D, x: float, lanes: int, title: String, m: Dictionary) -> void:
	var frame := Node3D.new()
	frame.name = "PracticeEmblem" if lanes == 3 else "WagerEmblem"
	frame.position = Vector3(x, 2.62, 2.96)
	frame.rotation.y = PI
	parent.add_child(frame)
	Craft.box(frame, "Frame", Vector3(1.76, 1.48, .08), Vector3.ZERO, m.rail, .025)
	Craft.box(frame, "InnerBrass", Vector3(1.60, 1.32, .018), Vector3(0, 0, .05), m.aged, .005)
	var felt := Craft.box(frame, "FeltGround", Vector3(1.56, .015, 1.28), Vector3(0, 0, .067), m.felt, .003)
	felt.rotation.x = PI / 2
	Sign.text(frame, "III" if lanes == 3 else "IV", Vector3(0, .42, .086), .19, Sign.GOLD, .8, true)
	for lane in lanes:
		var dx := (lane - (lanes - 1) * .5) * .29
		Craft.box(frame, "CardOutline", Vector3(.23, .38, .009), Vector3(dx, .02, .084), m.brass, .006)
		Craft.box(frame, "CardField", Vector3(.197, .346, .007), Vector3(dx, .02, .091), m.dark, .004)
		var pip := Craft.box(frame, "CardDiamond", Vector3(.054, .054, .006), Vector3(dx, .02, .099), m.brass, .001)
		pip.rotation.z = PI / 4
	Sign.text(frame, title, Vector3(0, -.42, .086), .072, Sign.PAPER, 1.39)
	Craft.box(frame, "CaptionRule", Vector3(.85, .008, .006), Vector3(0, -.28, .088), m.aged, .001)


static func _side_plaque(parent: Node3D, side: float) -> void:
	var plate := Node3D.new()
	plate.position = Vector3(side * 3.04, 1.95, -1.30)
	plate.rotation.y = -side * PI / 2
	parent.add_child(plate)
	Sign.plaque(plate, "A friendly game" if side < 0 else "A larger wager",
		"THREE LANES" if side < 0 else "FOUR LANES", Vector3.ZERO, Vector2(1.40, .36), Sign.GOLD)


static func _sconce(parent: Node3D, side: float, m: Dictionary) -> void:
	var lamp := Node3D.new()
	lamp.name = "BrassSconce"
	lamp.position = Vector3(side * 3.02, 2.45, .15)
	lamp.rotation.y = -side * PI / 2
	parent.add_child(lamp)
	Craft.box(lamp, "BackPlate", Vector3(.16, .42, .06), Vector3.ZERO, m.aged, .025)
	Craft.box(lamp, "Arm", Vector3(.035, .035, .27), Vector3(0, -.07, .16), m.brass, .009)
	_cylinder(lamp, "Stem", .025, .29, Vector3(0, .07, .27), m.brass)
	_cylinder(lamp, "GreenShade", .19, .20, Vector3(0, .28, .27), m.green, .095)
	_cylinder(lamp, "ShadeLip", .195, .025, Vector3(0, .178, .27), m.brass)
	_cylinder(lamp, "WarmGlass", .16, .012, Vector3(0, .163, .27), _glow())
	var light := OmniLight3D.new()
	light.name = "SconceLight"
	light.position = Vector3(0, .08, .47)
	light.light_color = Color("f8d5a0")
	light.light_energy = 1.15
	light.omni_range = 3.8
	light.shadow_enabled = false
	lamp.add_child(light)


static func _pendant(parent: Node3D, m: Dictionary) -> void:
	var lamp := Node3D.new()
	lamp.name = "GreenPendant"
	lamp.position = Vector3(0, 3.42, -.45)
	parent.add_child(lamp)
	_cylinder(lamp, "Canopy", .16, .065, Vector3(0, .82, 0), m.aged)
	_cylinder(lamp, "Suspension", .016, .64, Vector3(0, .49, 0), m.dark)
	_cylinder(lamp, "BrassNeck", .075, .14, Vector3(0, .12, 0), m.brass)
	_cylinder(lamp, "GreenShade", .52, .32, Vector3(0, -.09, 0), m.green, .18)
	_cylinder(lamp, "BrassRim", .525, .034, Vector3(0, -.25, 0), m.brass)
	_cylinder(lamp, "OpalUnderside", .47, .012, Vector3(0, -.273, 0), _glow())
	var light := SpotLight3D.new()
	light.name = "WarmTablePool"
	light.position.y = -.31
	light.rotation.x = -PI / 2
	light.light_color = Color("ffe0ac")
	light.light_energy = 2.2
	light.spot_range = 5.7
	light.spot_angle = 72
	light.shadow_enabled = false
	lamp.add_child(light)


static func _cylinder(parent: Node3D, title: String, radius: float, height: float,
		at: Vector3, material: Material, top := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	var view := MeshInstance3D.new()
	view.name = title
	view.mesh = mesh
	view.material_override = material
	view.position = at
	parent.add_child(view)
	return view


static func _glow() -> StandardMaterial3D:
	var material := Craft.material(Color("f8dfad"), .65).duplicate() as StandardMaterial3D
	material.emission_enabled = true
	material.emission = Color("f8dfad")
	material.emission_energy_multiplier = .75
	return material
