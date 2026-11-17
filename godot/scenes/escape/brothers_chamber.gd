extends RefCounted
## Walkable card-parlour shell. Furnishings and lighting live in brothers_decor.
const Craft := preload("res://minigames/cards/table_craft.gd")
const Geometry := preload("res://scenes/escape/hub_geometry.gd")
const Meshes := preload("res://scenes/escape/hub_meshes.gd")


static func build(room: Node3D) -> void:
	var wood := Craft.surface(Color("302219"), true)
	var rail := Craft.surface(Color("4d3423"), true)
	var dark := Craft.material(Color("171d19"), .9)
	var green := Craft.surface(Color("183e36"))
	var brass := Craft.material(Color("a58954"), .38, .65)
	var aged := Craft.material(Color("66523b"), .58, .5)
	# The visible joinery is shallow cladding; simple collision boxes own the shell.
	Geometry.box(room, Vector3(0, -.1, 0), Vector3(6.4, .2, 6.4), dark, true)
	Geometry.box(room, Vector3(0, 2.25, 3.2), Vector3(6.65, 4.5, .25), dark, true)
	for side in [-1.0, 1.0]:
		Geometry.box(room, Vector3(side * 3.2, 2.25, 0), Vector3(.25, 4.5, 6.4), dark, true)
	Geometry.box(room, Vector3(0, 4.6, 0), Vector3(6.65, .2, 6.65), dark)
	_floor(room, dark, green, brass, aged)
	_wall(room, "RearJoinery", Vector3(0, 0, 3.075), PI, wood, rail, green, brass, aged)
	_wall(room, "LeftJoinery", Vector3(-3.075, 0, 0), PI / 2, wood, rail, green, brass, aged)
	_wall(room, "RightJoinery", Vector3(3.075, 0, 0), -PI / 2, wood, rail, green, brass, aged)
	_front_returns(room, wood, rail, green, brass)
	_ceiling(room, wood, rail, green, aged)


static func _wall(parent: Node3D, title: String, at: Vector3, yaw: float,
		wood: Material, rail: Material, green: Material, brass: Material, aged: Material) -> void:
	var wall := Node3D.new()
	wall.name = title
	wall.position = at
	wall.rotation.y = yaw
	parent.add_child(wall)
	_panel(wall, "WalnutWainscot", Vector2(6.15, 1.25), Vector3(0, .625, .015), wood)
	# Raised panels and their bevels supply depth without a field of tiny trims.
	for x in [-2.28, -.76, .76, 2.28]:
		_panel(wall, "RaisedPanelBorder", Vector2(1.40, .86), Vector3(x, .66, .048), rail)
		_panel(wall, "RaisedPanelInset", Vector2(1.30, .76), Vector3(x, .66, .073), wood)
	for x in [-1.535, 1.535]:
		_panel(wall, "GreenWallBay", Vector2(2.94, 2.74), Vector3(x, 2.73, .025), green)
		for edge in [-1.0, 1.0]:
			Craft.box(wall, "BayInlay", Vector3(.012, 2.64, .012), Vector3(x + edge * 1.42, 2.73, .052), aged, .002)
	for x in [-3.025, 0.0, 3.025]:
		Craft.box(wall, "PanelStile", Vector3(.10, 2.87, .09), Vector3(x, 2.735, .045), wood, .012)
	for row in [[.13, .19, .11], [1.22, .105, .13], [1.32, .035, .09], [4.14, .11, .12], [4.28, .16, .20]]:
		Craft.box(wall, "WallMoulding", Vector3(6.15, row[1], row[2]), Vector3(0, row[0], .055), rail, .015)
	for y in [1.275, 4.08]:
		Craft.box(wall, "BrassPictureRail", Vector3(6.05, .018, .018), Vector3(0, y, .115), brass, .003)


static func _panel(parent: Node3D, title: String, size: Vector2, at: Vector3, material: Material) -> void:
	# The shared tabletop shader uses local XZ. Rotate a horizontal slab into the
	# wall so cloth weave and timber grain retain the table's material definition.
	var panel := Craft.box(parent, title, Vector3(size.x, .035, size.y), at, material, .008)
	panel.rotation.x = PI / 2


static func _floor(parent: Node3D, dark: Material, green: Material, brass: Material, aged: Material) -> void:
	var groups := {}
	var palette := [Color("3c2c20"), Color("463224"), Color("35291f")]
	# Staggered boards: a handful of shared batches, not one node per plank.
	for row in 16:
		var offset := .76875 if row % 2 else 0.0
		for column in 5:
			var left := maxf(-3.075, -3.075 - offset + column * 1.5375)
			var right := minf(3.075, -3.075 - offset + (column + 1) * 1.5375)
			if right <= left:
				continue
			var width := snappedf(right - left - .012, .0001)
			var tone := (row * 5 + column * 7) % 3
			var key := "%s/%d" % [width, tone]
			if not groups.has(key):
				groups[key] = {"width": width, "tone": tone, "transforms": []}
			groups[key].transforms.append(Transform3D(Basis.IDENTITY, Vector3((left + right) * .5, .008, -3.075 + (row + .5) * .384375)))
	for key: String in groups:
		var group: Dictionary = groups[key]
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = Meshes.chamfer_box(Vector3(group.width, .016, .372), .004)
		batch.instance_count = group.transforms.size()
		for index in batch.instance_count:
			batch.set_instance_transform(index, group.transforms[index])
		var planks := MultiMeshInstance3D.new()
		planks.name = "WalnutFloorboards"
		planks.multimesh = batch
		planks.material_override = Craft.surface(palette[group.tone], true)
		parent.add_child(planks)
	Craft.box(parent, "RunnerBinding", Vector3(4.55, .008, 5.22), Vector3(0, .02, -.12), dark, .002)
	Craft.box(parent, "FeltRunner", Vector3(4.43, .008, 5.10), Vector3(0, .025, -.12), green, .002)
	for side in [-1.0, 1.0]:
		Craft.box(parent, "RunnerSideBorder", Vector3(.018, .003, 4.96), Vector3(side * 2.14, .031, -.12), aged, .001)
		Craft.box(parent, "RunnerEndBorder", Vector3(4.30, .003, .018), Vector3(0, .031, -.12 + side * 2.48), aged, .001)
		var mark := Craft.box(parent, "RunnerDiamond", Vector3(.12, .003, .12), Vector3(0, .032, -.12 + side * 2.29), brass, .001)
		mark.rotation.y = PI / 4


static func _front_returns(parent: Node3D, wood: Material, rail: Material, green: Material, brass: Material) -> void:
	for side in [-1.0, 1.0]:
		_panel(parent, "EntryReturn", Vector2(1.25, 3.0), Vector3(side * 2.425, 2.72, -3.035), green)
		_panel(parent, "EntryReturnWood", Vector2(1.25, 1.25), Vector3(side * 2.425, .625, -2.995), wood)
		Craft.box(parent, "EntryReturnCap", Vector3(1.28, .105, .13), Vector3(side * 2.425, 1.22, -2.975), rail, .015)
		Craft.box(parent, "EntryReturnInlay", Vector3(1.25, .018, .018), Vector3(side * 2.425, 1.275, -2.90), brass, .003)
	Craft.box(parent, "EntryCornice", Vector3(6.15, .16, .20), Vector3(0, 4.28, -3.02), rail, .015)


static func _ceiling(parent: Node3D, wood: Material, rail: Material, green: Material, aged: Material) -> void:
	for x in [-2.02, 0.0, 2.02]:
		for z in [-2.02, 0.0, 2.02]:
			Craft.box(parent, "CofferInset", Vector3(1.88, .035, 1.88), Vector3(x, 4.475, z), green, .008)
	for line in [-3.03, -1.01, 1.01, 3.03]:
		Craft.box(parent, "CofferBeam", Vector3(.13, .20, 6.15), Vector3(line, 4.37, 0), wood, .018)
		Craft.box(parent, "CofferBeam", Vector3(6.15, .20, .13), Vector3(0, 4.37, line), rail, .018)
		Craft.box(parent, "CofferInlay", Vector3(.018, .005, 6.05), Vector3(line, 4.267, 0), aged, .001)
