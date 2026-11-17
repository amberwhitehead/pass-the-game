extends RefCounted
## Physical square chambers surrounding a clear central escape-room floor.
## Reuses the original challenge/NPC nodes through the returned placement map.

const Geometry := preload("res://scenes/escape/hub_geometry.gd")
const Details := preload("res://scenes/escape/hub_details.gd")
const Sign := preload("res://ui/world_sign.gd")
const Door := preload("res://scenes/escape/escape_door.gd")
const BrothersRoom := preload("res://scenes/escape/brothers_room.gd")
const HEIGHT := 5.5
const ROOM_HALF := 3.2
const OPENING_HALF := 1.6
const OPENING_HEIGHT := 3.5
const ROOM_SPECS := [
	{"id": "egypt", "center": Vector3(-6, 0, -11.2), "side": "north", "title": "01   EGYPT FRACTAL", "accent": Color(0.95, 0.68, 0.28), "station": "Challenge4", "npc": "Egyptian"},
	{"id": "future_north", "center": Vector3(2, 0, -11.2), "side": "north", "title": "06   OBSERVATORY", "accent": Color(0.77, 0.48, 0.9), "station": "Challenge6", "npc": "MetricA"},
	{"id": "challenge1", "center": Vector3(-7, 0, 11.2), "side": "south", "title": "04   WORKSHOP", "accent": Color(0.95, 0.53, 0.27), "station": "Challenge1", "npc": "Engineer"},
	{"id": "challenge2", "center": Vector3(0, 0, 11.2), "side": "south", "title": "05   CALENDAR", "accent": Color(0.41, 0.81, 0.65), "station": "Challenge2", "npc": "Mayan"},
	{"id": "cards", "center": Vector3(7, 0, 11.2), "side": "south", "title": "03   THE BROTHERS", "accent": Color(0.93, 0.74, 0.34), "station": "Challenge3", "npc": "Augmented"},
	{"id": "roman", "center": Vector3(14.2, 0, 0), "side": "east", "title": "02   ROMAN FLOW", "accent": Color(0.35, 0.85, 0.7), "station": "Challenge5", "npc": "Roman"},
]


static func build(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "EscapeArchitecture"
	parent.add_child(root)
	var mats := {
		"wall": Geometry.surface(Color(0.10, 0.13, 0.15), 0.3, .62),
		"frame": Geometry.surface(Color(0.18, 0.22, 0.24), 0.65, .34),
		"floor": Geometry.material(Color(0.045, 0.065, 0.08), 0.4),
		"tile": Geometry.surface(Color(0.20, 0.235, 0.245), 0.42, .51),
		"ceiling": Geometry.surface(Color(0.08, 0.105, 0.12), 0.25, .75),
		"light": Geometry.material(Color(0.58, 0.79, 0.87), 0.0, 1.4),
	}
	Geometry.floor_tiles(root, Vector3.ZERO, Vector2(22, 16), mats.floor, mats.tile)
	_wall_with_openings(root, -11.0, 11.0, -8.0, true, [-6.0, 2.0], mats.wall)
	_wall_with_openings(root, -11.0, 11.0, 8.0, true, [-7.0, 0.0, 7.0], mats.wall)
	_wall_with_openings(root, -8.0, 8.0, 11.0, false, [0.0], mats.wall)
	_wall_with_openings(root, -8.0, 8.0, -11.0, false, [0.0], mats.wall)
	# The legacy west door has visual leaves but no blocking body.
	Geometry.box(root, Vector3(-11.18, 1.75, 0), Vector3(0.15, 3.5, 3.2), mats.wall, true)
	Geometry.box(root, Vector3(0, HEIGHT + 0.1, 0), Vector3(22.4, 0.2, 16.4), mats.ceiling)
	for x in [-7.0, 0.0, 7.0]:
		Geometry.box(root, Vector3(x, HEIGHT - 0.12, 0), Vector3(0.22, 0.25, 16), mats.frame)
		Geometry.box(root, Vector3(x, HEIGHT - 0.26, 0), Vector3(0.085, 0.035, 13.8), mats.light)
	for x in [-6.0, 6.0]:
		for z in [-4.5, 4.5]:
			Geometry.lamp(root, Vector3(x, HEIGHT - 0.7, z), Color(0.76, 0.87, 0.94) if x > 0 else Color(1.0, 0.86, 0.68), 12.0, 1.1)
	Details.build(root)
	Sign.plaque(root, "REFRACTION HALL", "A PLACE BETWEEN TESTS", Vector3(7.2, 4.02, -7.73), Vector2(4.7, .73), Sign.GOLD)
	var result := {"root": root, "stations": {}, "rooms": {}, "locked_door": null}
	for spec in ROOM_SPECS:
		_build_room(root, spec, mats)
		result.rooms[spec.id] = spec.center
		_place_station(result.stations, spec)
	var door := Door.new()
	door.name = "RomanGate"
	door.position = Vector3(11, 0, 0)
	door.rotation.y = -PI / 2.0
	root.add_child(door)
	result.locked_door = door
	return result


static func _wall_with_openings(parent: Node3D, first: float, last: float,
		fixed: float, along_x: bool, doors: Array, mat: Material) -> void:
	var cursor := first
	for center: float in doors:
		_wall_segment(parent, cursor, center - OPENING_HALF, fixed, along_x, mat)
		var at := Vector3(center, (HEIGHT + OPENING_HEIGHT) / 2.0, fixed) if along_x \
			else Vector3(fixed, (HEIGHT + OPENING_HEIGHT) / 2.0, center)
		var size := Vector3(OPENING_HALF * 2, HEIGHT - OPENING_HEIGHT, 0.28) if along_x \
			else Vector3(0.28, HEIGHT - OPENING_HEIGHT, OPENING_HALF * 2)
		Geometry.box(parent, at, size, mat, true)
		cursor = center + OPENING_HALF
	_wall_segment(parent, cursor, last, fixed, along_x, mat)


static func _wall_segment(parent: Node3D, first: float, last: float,
		fixed: float, along_x: bool, mat: Material) -> void:
	if last <= first:
		return
	var middle := (first + last) / 2.0
	var at := Vector3(middle, HEIGHT / 2.0, fixed) if along_x else Vector3(fixed, HEIGHT / 2.0, middle)
	var size := Vector3(last - first, HEIGHT, 0.28) if along_x else Vector3(0.28, HEIGHT, last - first)
	Geometry.box(parent, at, size, mat, true)


static func _build_room(parent: Node3D, spec: Dictionary, mats: Dictionary) -> void:
	var room := Node3D.new()
	room.name = str(spec.id).to_pascal_case() + "Chamber"
	room.position = spec.center
	parent.add_child(room)
	if spec.id == "cards":
		BrothersRoom.build(room)
		return
	var accent: Color = spec.accent
	var strip := Geometry.material(accent, 0.0, 1.3)
	var wall := Geometry.surface(Color(0.12, 0.15, 0.17).lerp(accent, 0.10), 0.25, .62)
	var floor := Geometry.surface(Color(0.20, 0.23, 0.24).lerp(accent, 0.10), 0.30, .5)
	Geometry.floor_tiles(room, Vector3.ZERO, Vector2(6.4, 6.4), mats.floor, floor)
	Geometry.box(room, Vector3(0, 4.6, 0), Vector3(6.65, 0.2, 6.65), mats.ceiling)
	var inward := Vector3.BACK
	var yaw := 0.0
	match spec.side:
		"south":
			inward = Vector3.FORWARD
			yaw = PI
		"east":
			inward = Vector3.LEFT
			yaw = -PI / 2.0
	var tangent := Vector3(inward.z, 0, -inward.x)
	# Three full walls; the fourth is the already-split main-room wall.
	for side: float in [-1.0, 1.0]:
		var side_wall := tangent * side * ROOM_HALF + Vector3.UP * 2.25
		var wall_size := Vector3(0.25, 4.5, 6.4) if spec.side != "east" else Vector3(6.4, 4.5, 0.25)
		Geometry.box(room, side_wall, wall_size, wall, true)
	var back_size := Vector3(6.65, 4.5, 0.25) if spec.side != "east" else Vector3(0.25, 4.5, 6.65)
	Geometry.box(room, -inward * ROOM_HALF + Vector3.UP * 2.25, back_size, wall, true)
	# A single inset accent panel anchors each chamber's station.
	var back_panel := Geometry.box(room, -inward * 3.05 + Vector3.UP * 2.1,
		Vector3(4.4, 2.8, 0.06), mats.frame)
	back_panel.rotation.y = yaw
	var rear_strip := Geometry.box(room, -inward * 2.99 + Vector3.UP * 3.65,
		Vector3(4.4, 0.045, 0.045), strip)
	rear_strip.rotation.y = yaw
	Geometry.lamp(room, Vector3(0, 3.9, 0), accent.lightened(0.4), 5.6, 1.25)
	var light_panel := Geometry.box(room, Vector3(0, 4.47, 0), Vector3(2.2, 0.04, 0.55), strip)
	light_panel.rotation.y = yaw
	var entry := inward * ROOM_HALF
	var frame := Node3D.new()
	frame.position = entry
	frame.rotation.y = yaw
	room.add_child(frame)
	for side: float in [-1.0, 1.0]:
		Geometry.box(frame, Vector3(side * 1.5, 1.75, 0), Vector3(0.2, 3.5, 0.42), mats.frame, true)
		Geometry.box(frame, Vector3(side * 1.5, 1.75, 0.225), Vector3(0.045, 3.05, 0.035), strip)
	Geometry.box(frame, Vector3(0, 3.58, 0), Vector3(3.2, 0.16, 0.42), mats.frame)
	Geometry.box(frame, Vector3(0, 3.58, 0.225), Vector3(2.95, 0.045, 0.035), strip)
	var titles: Dictionary = {"egypt": "Egypt Fractal", "future_north": "Observatory", "challenge1": "Workshop", "challenge2": "Calendar", "cards": "The Brothers", "roman": "Roman Flow"}
	var subtitles: Dictionary = {"egypt": "LIGHT / FORM / PATTERN", "future_north": "BEYOND THE KNOWN", "challenge1": "IDEAS UNDER CONSTRUCTION", "challenge2": "THE SHAPE OF TIME", "cards": "A GAME OF SMALL WAGERS", "roman": "ORDER THROUGH FLOW"}
	Sign.doorway(frame, String(spec.title).left(2), titles[spec.id], subtitles[spec.id], Vector3(0, 4.12, .22), accent)
	Geometry.box(frame, Vector3(0, 0.014, 0), Vector3(2.8, 0.015, 0.18), strip)
	for side in [-1.0, 1.0]:
		Geometry.box(frame, Vector3(side * 1.72, 1.75, -.06), Vector3(.10, 3.48, .12), mats.frame)
	# Thin entrance tread ribs stay flush to the floor, without adding blockers.
	for step in 3:
		Geometry.box(frame, Vector3(0, .018, -.28 - step * .12), Vector3(2.7, .012, .035), mats.frame)


static func _place_station(stations: Dictionary, spec: Dictionary) -> void:
	var center: Vector3 = spec.center
	var station_offset := Vector3(0, 0, -0.9)
	var npc_offset := Vector3(-1.95, 0, -0.4)
	var yaw := 0.0
	match spec.side:
		"south":
			station_offset = Vector3(0, 0, 0.9)
			npc_offset = Vector3(-1.85, 0, 0.6)
			yaw = PI
		"east":
			station_offset = Vector3(0.9, 0, 0)
			npc_offset = Vector3(0.6, 0, -1.85)
			yaw = -PI / 2.0
	stations[spec.station] = {"position": center + station_offset, "rotation_y": yaw}
	stations[spec.npc] = {"position": center + npc_offset, "rotation_y": yaw}
