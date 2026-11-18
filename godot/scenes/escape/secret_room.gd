extends Node3D
## An optional Easter egg: an unusual panel on the hall's east wall, near the south-east
## corner, under the inscription "Not every room has a number." Inspecting it moves the
## player to a small room far below the hall; a panel there returns them.
##
## The room is deliberately empty for future developers to build on: add to `room`
## (local origin = the room's floor centre). Visits are scene-local; nothing is saved.
## Teleports happen in the physics step with collision untouched; the player's
## position, facing and pitch are remembered and restored, or the hall entrance is used
## if that spot is blocked.

const Geometry := preload("res://scenes/escape/hub_geometry.gd")
const Sign := preload("res://ui/world_sign.gd")

## Panel on the east wall's inner face, south of Door 2, facing into the hall.
const PANEL_AT := Vector3(10.86, 0, 5.4)
const PANEL_YAW := -PI / 2
## The room sits well below the hall floor (which is solid and 0.24 m thick).
const ROOM_AT := Vector3(0, -6, 0)
const ROOM_HALF := 3.0
const ROOM_HEIGHT := 3.2
const ARRIVAL := Vector3(0, 0.02, 1.5)  # Room-local: clear of every wall, facing the signs.
const ARRIVAL_YAW := 0.0  # Facing -Z, the north wall with the signs.
const HALL_ENTRANCE := {"position": Vector3(-9.5, 0.02, 0.4), "yaw": -PI / 2, "pitch": 0.0}

var inside := false
var entrance: Interactable
var exit: Interactable
var room: Node3D
var _player: Player
var _pending := 0  # +1 go in, -1 come back, applied in the next physics step.
var _return := {}


func configure(player: Player) -> void:
	_player = player


func _ready() -> void:
	name = "SecretRoom"
	_build_entrance()
	_build_room()


func _physics_process(_delta: float) -> void:
	if _pending == 0 or not is_instance_valid(_player):
		return
	var going_in := _pending > 0
	_pending = 0
	if going_in:
		_return = {"position": _player.global_position, "yaw": _player.rotation.y,
			"pitch": _player.camera.rotation.x}
		_place(room.to_global(ARRIVAL), ARRIVAL_YAW, 0.0)
		inside = true
	else:
		var spot: Dictionary = _return
		if spot.is_empty() or _blocked(spot.position + Vector3.UP * .02):
			spot = HALL_ENTRANCE
		_place(spot.position + Vector3.UP * .02, spot.yaw, spot.pitch)
		inside = false


func _place(at: Vector3, yaw: float, pitch: float) -> void:
	_player.global_position = at
	_player.rotation.y = yaw
	_player.camera.rotation.x = pitch
	_player.velocity = Vector3.ZERO
	_player._look_finger = -1
	_player.suppress_held_inputs()  # A key held through the move does nothing until released.
	_player.reset_physics_interpolation()


## True if the player's own capsule would overlap solid geometry at `at`.
func _blocked(at: Vector3) -> bool:
	var collider := _player.get_node("Shape") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = Transform3D(Basis.IDENTITY, at + collider.position)
	query.exclude = [_player.get_rid()]
	query.collide_with_areas = false
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _request(direction: int) -> void:
	if _pending == 0:
		_pending = direction


func _build_entrance() -> void:
	var corner := Node3D.new()
	corner.name = "UnusualPanel"
	corner.position = PANEL_AT
	corner.rotation.y = PANEL_YAW
	add_child(corner)
	entrance = _panel(corner, "Inspect unusual panel", 1)
	Sign.plaque(corner, "Not every room has a number.", "", Vector3(0, 2.0, .05), Vector2(1.7, .3), Sign.GOLD)
	# Short range: enough to light the corner, not through the Brothers' wall 2.6 m away.
	Geometry.lamp(corner, Vector3(0, 2.4, .7), Color(1.0, .88, .7), 2.4, .9)


func _build_room() -> void:
	room = Node3D.new()
	room.name = "EasterEggRoom"
	room.position = ROOM_AT
	add_child(room)
	var floor := Geometry.material(Color(0.045, 0.065, 0.08), 0.4)
	var tile := Geometry.surface(Color(0.20, 0.235, 0.245), 0.42, .51)
	var wall := Geometry.surface(Color(0.10, 0.13, 0.15), 0.3, .62)
	Geometry.floor_tiles(room, Vector3.ZERO, Vector2(ROOM_HALF * 2, ROOM_HALF * 2), floor, tile)
	for side in [-1.0, 1.0]:
		Geometry.box(room, Vector3(side * (ROOM_HALF + .12), ROOM_HEIGHT / 2, 0),
			Vector3(.25, ROOM_HEIGHT, ROOM_HALF * 2 + .5), wall, true)
		Geometry.box(room, Vector3(0, ROOM_HEIGHT / 2, side * (ROOM_HALF + .12)),
			Vector3(ROOM_HALF * 2 + .5, ROOM_HEIGHT, .25), wall, true)
	Geometry.box(room, Vector3(0, ROOM_HEIGHT + .12, 0), Vector3(ROOM_HALF * 2 + .5, .25, ROOM_HALF * 2 + .5), wall, true)
	# Lights cast no shadows here, so the range stays short of the hall floor 6 m above.
	Geometry.lamp(room, Vector3(0, 1.6, 0), Color(.9, .92, 1.0), 4.8, 1.4)
	var back := -ROOM_HALF + .01  # The north wall's inner face.
	Sign.plaque(room, "You found an Easter Egg!", "", Vector3(-.6, 2.05, back), Vector2(3.4, .6), Sign.GOLD)
	Sign.plaque(room, "This room should be developed by other developers.", "", Vector3(-.6, 1.3, back), Vector2(3.4, .42), Sign.GOLD)
	var way_out := Node3D.new()
	way_out.name = "ReturnPanel"
	way_out.position = Vector3(2.05, 0, back)
	room.add_child(way_out)
	exit = _panel(way_out, "Return to the hall", -1)
	Sign.plaque(way_out, "Return to the hall", "", Vector3(0, 1.95, .05), Vector2(1.1, .3), Sign.GOLD)


## A recessed brass-framed panel with a handle; local +Z faces the player.
func _panel(parent: Node3D, prompt: String, direction: int) -> Interactable:
	var panel := SecretPanel.new()
	panel.prompt = prompt
	panel.interacted.connect(_request.bind(direction))
	parent.add_child(panel)
	return panel


class SecretPanel extends Interactable:
	const Geometry := preload("res://scenes/escape/hub_geometry.gd")
	const Sign := preload("res://ui/world_sign.gd")
	var _frame: Array[MeshInstance3D] = []
	var _focus: Vector3

	func _ready() -> void:
		super()
		collision_layer = 1
		collision_mask = 0
		monitoring = false
		var bounds := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(.8, 1.2, .3)
		bounds.shape = box
		bounds.position = Vector3(0, 1.15, .2)  # In front of the wall, so line of sight reaches it.
		add_child(bounds)
		var dark := Geometry.surface(Color("101a1d"), .3, .7)
		Geometry.box(self, Vector3(0, 1.15, .02), Vector3(.7, 1.1, .03), dark)
		for edge: Array in [[Vector3(0, 1.72, .045), Vector3(.8, .05, .04)], [Vector3(0, .58, .045), Vector3(.8, .05, .04)],
				[Vector3(-.375, 1.15, .045), Vector3(.05, 1.19, .04)], [Vector3(.375, 1.15, .045), Vector3(.05, 1.19, .04)]]:
			var strip := Geometry.box(self, edge[0], edge[1], Geometry.material(Color("8c7448"), .72))
			_frame.append(strip)
		# A recessed seam and a pull handle: the shape, not just the colour, sets it apart.
		Geometry.box(self, Vector3(0, 1.15, .04), Vector3(.012, 1.0, .01), Geometry.material(Color("05090a")))
		Geometry.box(self, Vector3(.22, 1.15, .1), Vector3(.035, .3, .035), Geometry.material(Color("b89a5e"), .8))
		for y in [1.02, 1.28]:
			Geometry.box(self, Vector3(.22, y, .07), Vector3(.03, .03, .06), Geometry.material(Color("b89a5e"), .8))

	func get_focus_position() -> Vector3:
		return to_global(Vector3(0, 1.15, .12))

	func _on_focus_changed(value: bool) -> void:
		for strip in _frame:
			var material := strip.material_override as StandardMaterial3D
			material.emission_enabled = value
			material.emission = Sign.GOLD
			material.emission_energy_multiplier = .45
