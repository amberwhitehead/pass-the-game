extends Node3D
## The carried item and shared lightweight world-item meshes.

const Inventory := preload("res://scenes/escape/carry_inventory.gd")
const Art := preload("res://scenes/escape/optics_art.gd")
var _inventory: Node
var _camera: Camera3D
var _item: Node3D


func configure(inventory: Node, camera: Camera3D) -> void:
	_inventory = inventory
	_camera = camera
	if get_parent() == null:
		camera.add_child(self)
	elif get_parent() != camera:
		reparent(camera)
	position = Vector3(0.43, -0.32, -0.85)
	rotation = Vector3(-0.12, -0.3, -0.1)
	scale = Vector3.ONE * 0.60
	if not inventory.changed.is_connected(_update_item):
		inventory.changed.connect(_update_item)
	_update_item(inventory.held_item)


## Moves the carried item into a hand (the first-person hands' grip) instead of floating
## in front of the camera. Positions are in the grip's own (rig) units.
func attach_to(anchor: Node3D) -> void:
	reparent(anchor, false)
	position = Vector3(0, -0.02, -0.04)
	rotation = Vector3(-0.1, -0.25, 0.0)
	scale = Vector3.ONE * 0.42


func _update_item(item: String) -> void:
	if is_instance_valid(_item):
		remove_child(_item)
		_item.queue_free()
	_item = build_item(item)
	add_child(_item)
	visible = not item.is_empty()


func _process(_delta: float) -> void:
	if _inventory == null:
		return
	var player := _camera.get_parent()
	var cinematic := player is Player and bool(player.get("cinematic_locked"))
	# Stays in hand during a conversation: the box is at the bottom, clear of it.
	visible = not _inventory.held_item.is_empty() and not cinematic \
		and not MiniGames.is_running()


static func build_item(item: String) -> Node3D:
	var visual := Node3D.new()
	visual.name = "ItemVisual"
	if item.is_empty():
		return visual
	if item == "prism":
		Art.mesh(visual, Art.prism_mesh(), Vector3.ZERO, Art.glass(Color(.35, .75, .88)))
		var metal := Art.material(Color(.46, .57, .61), false, true)
		Art.rounded_box(visual, Vector3(.40, .055, .31), Vector3(0, -.20, 0), metal, .014)
		for x: float in [-.16, .16]:
			Art.rounded_box(visual, Vector3(.055, .11, .33), Vector3(x, -.16, 0), metal, .012)
		visual.rotation.y = PI / 5.0
	elif item == "flashlight":
		# A red 1950s flashlight with a chrome head, pointing forward.
		var red := Art.material(Color(.75, .16, .12), false, false)
		var chrome := Art.material(Color(.82, .85, .86), false, true)
		var body := Art.cylinder(visual, .075, .42, Vector3(0, 0, .05), red)
		body.rotation.x = PI / 2.0
		var head := Art.cylinder(visual, .11, .12, Vector3(0, 0, -.2), chrome)
		head.rotation.x = PI / 2.0
		var glass := Art.cylinder(visual, .095, .02, Vector3(0, 0, -.265), Art.material(Color(1, .96, .8), true))
		glass.rotation.x = PI / 2.0
		Art.box(visual, Vector3(.04, .03, .08), Vector3(0, .08, .08), chrome)
	else:
		var tint := Color(1.0, .78, .16) if item == "lens_yellow" else Color(.15, .5, 1.0)
		var lens := Art.cylinder(visual, .22, .045, Vector3.ZERO, Art.glass(tint))
		lens.rotation.x = PI / 2.0
		var brass := Art.material(Color(.66, .48, .24), false, true)
		var ring := Art.ring(visual, .215, .265, Vector3.ZERO, brass)
		ring.rotation.x = PI / 2.0
		for angle: float in [0, PI * .5, PI, PI * 1.5]:
			var at := Vector3(cos(angle) * .244, sin(angle) * .244, .024)
			var bolt := Art.cylinder(visual, .013, .018, at, Art.material(Color(.37, .44, .48), false, true))
			bolt.rotation.x = PI / 2.0
	return visual
