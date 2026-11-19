extends RefCounted
## Exact point optics. The ceiling-fed starter can choose any horizontal azimuth;
## portable prisms always turn left or right by exactly ninety degrees.
##
## A second, later light: the 1955 flashlight (sent through the Workshop's ring) fits the
## lamp socket F. Its own beam is traced separately and only counts at the sun disc by
## Egypt's doorway, which wants sunlight: yellow. It never opens Door 2.

const SOURCE := Vector2.ZERO
const RECEIVER := Vector2(10, 0)
const SOCKETS := {"A": Vector2(2, 2), "B": Vector2(7, -3), "C": Vector2(4, 4), "D": Vector2(9, -1)}
const MOUNTS := {"J": Vector2(5, 0), "K": Vector2(3, 3), "L": Vector2(1, 1), "M": Vector2(8.5, -1.5), "N": Vector2(-7, 5)}
const LAMP_SOCKET := "F"
const LAMP := Vector2(-4, 2)
const SUN_DISC := Vector2(-10.6, 8.6)
const SUN_COLOR := 1   ## Yellow.
const OBSTACLE := Rect2(4.8, 0.6, 2.4, 2.6)
const WORLD_SCALE := 0.72
const ROOM := Rect2(-20.25, -13.5, 30.5555556, 22.2222222)
const ALIGNMENT_TOLERANCE := deg_to_rad(4.0)
const COLORS := {0: Color(0.86, 0.95, 1), 1: Color(1, 0.72, 0.08), 2: Color(0.15, 0.48, 1), 3: Color(0.2, 1, 0.47)}
const SOURCE_TARGETS := [Vector2(10, 0), Vector2(2, 2), Vector2(7, -3), Vector2(9, -1)]
const SOURCE_NAMES := ["receiver", "upper sockets", "socket B", "socket D"]

var source_angle := 0.0
var source_direction := 0:
	set(value):
		source_direction = posmod(value, SOURCE_TARGETS.size())
		source_angle = SOURCE_TARGETS[source_direction].angle()
# Absent entries preserve the simple clockwise/counter-clockwise arrangement.
# Once a player adjusts a head, its absolute angle must remain where they left it.
var head_angles: Dictionary = {}
var items: Dictionary = {"A": "", "B": "", "C": "", "D": "", "J": "lens_yellow", "K": "lens_blue", "L": "", "M": "", "N": "", "F": ""}
var lamp_angle := Vector2(-1, -1).angle()   ## Where the flashlight points; set by its handwheel.
var turns: Dictionary = {"A": -1, "B": -1, "C": -1, "D": -1}


static func world(point: Vector2, height: float = 1.25) -> Vector3:
	return Vector3(3.58 + point.x * WORLD_SCALE, height, -1.72 - point.y * WORLD_SCALE)


func accepts(id: String, item: String) -> bool:
	if item.is_empty():
		return true
	if id == LAMP_SOCKET:
		return item == "flashlight"
	return item == "prism" if SOCKETS.has(id) else item in ["lens_yellow", "lens_blue"]


func rotate(id: String) -> void:
	if id == "S":
		source_direction = (source_direction + 1) % SOURCE_TARGETS.size()
	elif turns.has(id) and items[id] == "prism":
		turns[id] = -int(turns[id])
		head_angles.erase(id)


func save_state() -> Dictionary:
	return {"source_direction": source_direction, "source_angle": source_angle, "head_angles": head_angles.duplicate(), "items": items.duplicate(), "turns": turns.duplicate(), "lamp_angle": lamp_angle}


func restore(state: Dictionary) -> void:
	source_direction = posmod(int(state.get("source_direction", 0)), SOURCE_TARGETS.size())
	var stored_source := float(state.get("source_angle", source_angle))
	if is_finite(stored_source):
		source_angle = wrapf(stored_source, -PI, PI)
	head_angles.clear()
	var stored_heads: Dictionary = state.get("head_angles", {})
	for id: String in stored_heads:
		if SOCKETS.has(id) and is_finite(float(stored_heads[id])):
			head_angles[id] = wrapf(float(stored_heads[id]), -PI, PI)
	var stored_items: Dictionary = state.get("items", {})
	var stored_turns: Dictionary = state.get("turns", {})
	for id: String in items:
		var item := String(stored_items.get(id, items[id]))
		if accepts(id, item):
			items[id] = item
	for id: String in turns:
		turns[id] = 1 if int(stored_turns.get(id, -1)) > 0 else -1
	var stored_lamp := float(state.get("lamp_angle", lamp_angle))
	if is_finite(stored_lamp):
		lamp_angle = wrapf(stored_lamp, -PI, PI)


func trace() -> Dictionary:
	return _trace(SOURCE, Vector2.from_angle(source_angle), RECEIVER, 3, [SUN_DISC, LAMP])


## The flashlight's beam, if it's in its socket: it wins at the sun disc in yellow.
func trace_lamp() -> Dictionary:
	if items.get(LAMP_SOCKET, "") != "flashlight":
		return {"segments": [], "hit": "none", "color": 0, "won": false, "incoming": {}}
	return _trace(LAMP, Vector2.from_angle(lamp_angle), SUN_DISC, SUN_COLOR, [RECEIVER])


func lamp_snap_angles() -> Array[float]:
	var angles: Array[float] = []
	var points: Array = [SUN_DISC]
	points.append_array(SOCKETS.values())
	points.append_array(MOUNTS.values())
	for point: Vector2 in points:
		angles.append((point - LAMP).angle())
	return angles


## Follows one beam. `goal` is the receiver that counts (as "receiver") when reached in
## `goal_color`; `stops` are other fixtures that simply block it.
func _trace(start: Vector2, start_direction: Vector2, goal: Vector2, goal_color: int, stops: Array) -> Dictionary:
	var origin := start
	var direction := start_direction
	var color := 0
	var segments: Array[Dictionary] = []
	var incoming: Dictionary = {}
	var visited: Dictionary = {}
	for _step in 24:
		var nearest := _room_distance(origin, direction)
		var hit := "wall"
		var blocked := _rectangle_distance(origin, direction, OBSTACLE)
		if blocked > 0.01 and blocked < nearest:
			nearest = blocked
			hit = "obstacle"
		var candidates: Dictionary = {"receiver": goal}
		for k in stops.size():
			candidates["stop%d" % k] = stops[k]
		for id: String in SOCKETS:
			if items[id] == "prism":
				candidates[id] = SOCKETS[id]
		for id: String in MOUNTS:
			if not String(items[id]).is_empty():
				candidates[id] = MOUNTS[id]
		for id: String in candidates:
			var relative: Vector2 = candidates[id] - origin
			var distance := relative.dot(direction)
			if distance > 0.02 and distance < nearest and absf(relative.cross(direction)) < 0.06:
				nearest = distance
				hit = id
		var endpoint := origin + direction * nearest
		segments.append({"from": origin, "to": endpoint, "color": color})
		if hit.begins_with("stop"):
			hit = "obstacle"
		if hit in ["receiver", "obstacle", "wall"]:
			return {"segments": segments, "hit": hit, "color": color, "won": hit == "receiver" and color == goal_color, "incoming": incoming}
		var loop_key := "%s:%s:%s" % [hit, direction.snapped(Vector2(0.001, 0.001)), color]
		if visited.has(loop_key):
			return {"segments": segments, "hit": "loop", "color": color, "won": false, "incoming": incoming}
		visited[loop_key] = true
		if SOCKETS.has(hit):
			incoming[hit] = direction
			var outgoing := Vector2(-direction.y, direction.x) * int(turns[hit])
			if head_angles.has(hit):
				var head := float(head_angles[hit])
				var left := direction.angle() + PI / 2
				var right := direction.angle() - PI / 2
				var left_error := absf(angle_difference(head, left))
				var right_error := absf(angle_difference(head, right))
				if minf(left_error, right_error) > ALIGNMENT_TOLERANCE:
					return {"segments": segments, "hit": "misaligned", "color": color, "won": false, "incoming": incoming, "alignment_id": hit}
				outgoing = Vector2(-direction.y, direction.x) * (1 if left_error < right_error else -1)
			direction = outgoing
		else:
			color |= 1 if items[hit] == "lens_yellow" else 2
		origin = endpoint
	return {"segments": segments, "hit": "loop", "color": color, "won": false, "incoming": incoming}


func source_snap_angles() -> Array[float]:
	var angles: Array[float] = []
	var points: Array = [RECEIVER]
	points.append_array(SOCKETS.values())
	for id: String in MOUNTS:
		if id != "N":   # The lamp's mount: the ceiling source has no business aiming there.
			points.append(MOUNTS[id])
	for point: Vector2 in points:
		var candidate := point.angle()
		var duplicate := false
		for angle in angles:
			duplicate = duplicate or absf(angle_difference(angle, candidate)) < 0.0001
		if not duplicate:
			angles.append(candidate)
	return angles


func head_angle(id: String, incoming: Vector2 = Vector2.ZERO) -> float:
	if head_angles.has(id):
		return float(head_angles[id])
	if incoming == Vector2.ZERO:
		incoming = Vector2(1, 1).normalized() if id in ["A", "C"] else Vector2(1, -1).normalized()
	return (Vector2(-incoming.y, incoming.x) * int(turns[id])).angle()


func _room_distance(origin: Vector2, direction: Vector2) -> float:
	var distance := 100.0
	for axis in 2:
		if absf(direction[axis]) > 0.0001:
			var edge: float = ROOM.end[axis] if direction[axis] > 0 else ROOM.position[axis]
			var candidate := (edge - origin[axis]) / direction[axis]
			if candidate > 0.01:
				distance = minf(distance, candidate)
	return distance


func _rectangle_distance(origin: Vector2, direction: Vector2, box: Rect2) -> float:
	var enter := -INF
	var leave := INF
	for axis in 2:
		if absf(direction[axis]) < 0.0001:
			if origin[axis] < box.position[axis] or origin[axis] > box.end[axis]:
				return -1.0
		else:
			var first := (box.position[axis] - origin[axis]) / direction[axis]
			var second := (box.end[axis] - origin[axis]) / direction[axis]
			enter = maxf(enter, minf(first, second))
			leave = minf(leave, maxf(first, second))
	if leave < enter or leave < 0:
		return -1.0
	return maxf(0.0, enter)
