extends RefCounted
## The hall's card parlor shares the playable table's furniture materials.
const Chamber := preload("res://scenes/escape/brothers_chamber.gd")
const Decor := preload("res://scenes/escape/brothers_decor.gd")
const Craft := preload("res://minigames/cards/table_craft.gd")
const Sign := preload("res://ui/world_sign.gd")

static func build(room: Node3D) -> void:
	Chamber.build(room)
	Decor.build(room)
	_entry(room)

static func _entry(room: Node3D) -> void:
	var entry := Node3D.new()
	entry.name = "ParlorEntrance"
	entry.position.z = -3.2
	entry.rotation.y = PI
	room.add_child(entry)
	var walnut := Craft.surface(Color("302219"), true)
	var moulding := Craft.surface(Color("4d3423"), true)
	var brass := Craft.material(Color("a58954"), .36, .65)
	var dark := Craft.material(Color("191b18"), .9)
	var jambs := StaticBody3D.new()
	jambs.name = "DoorpostCollision"
	entry.add_child(jambs)
	for side in [-1.0, 1.0]:
		Craft.box(entry, "WalnutDoorpost", Vector3(.24, 3.5, .44), Vector3(side * 1.5, 1.75, 0), walnut)
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = Vector3(.24, 3.5, .44)
		shape.shape = bounds
		shape.position = Vector3(side * 1.5, 1.75, 0)
		jambs.add_child(shape)
		Craft.box(entry, "ReededDoorpost", Vector3(.12, 2.72, .10), Vector3(side * 1.5, 1.88, .24), moulding, .018)
		Craft.box(entry, "BrassDoorBead", Vector3(.018, 2.72, .02), Vector3(side * 1.55, 1.88, .30), brass, .005)
		Craft.box(entry, "DoorPlinth", Vector3(.34, .46, .50), Vector3(side * 1.5, .23, 0), walnut)
		Craft.box(entry, "DoorCapital", Vector3(.38, .13, .50), Vector3(side * 1.5, 3.45, 0), moulding)
	Craft.box(entry, "DoorLintel", Vector3(3.43, .25, .48), Vector3(0, 3.63, 0), walnut)
	Craft.box(entry, "DoorCornice", Vector3(3.65, .08, .57), Vector3(0, 3.80, .02), moulding)
	Craft.box(entry, "LintelInlay", Vector3(2.95, .015, .018), Vector3(0, 3.62, .25), brass, .003)
	var diamond := Craft.box(entry, "DoorDiamond", Vector3(.11, .11, .018), Vector3(0, 3.62, .27), brass, .005)
	diamond.rotation.z = PI / 4
	Craft.box(entry, "BrassThreshold", Vector3(2.75, .016, .34), Vector3(0, .01, 0), brass, .004)
	for step in 3:
		Craft.box(entry, "ThresholdGroove", Vector3(2.65, .005, .012), Vector3(0, .021, -.12 + step * .12), dark, .001)
	Sign.doorway(entry, "03", "The Brothers", "A GAME OF SMALL WAGERS", Vector3(0, 4.12, .22), Sign.GOLD)
