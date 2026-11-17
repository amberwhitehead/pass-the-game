extends Node3D
## Optical state owns the route; the aiming director borrows player input only
## while a handwheel is engaged. Runtime beam updates reuse rendering resources.

signal solved
signal message(text: String)
signal changed
signal aiming_changed(active: bool, hint: String)

const Model := preload("res://scenes/escape/optics_model.gd")
const Art := preload("res://scenes/escape/optics_art.gd")
const Device := preload("res://scenes/escape/optics_device.gd")
const Beams := preload("res://scenes/escape/optics_beams.gd")
const Aiming := preload("res://scenes/escape/optics_aiming.gd")
const Hardware := preload("res://scenes/escape/optics_hardware.gd")
const OpticsSound := preload("res://audio/optics_sound.gd")

var model := Model.new()
var devices: Dictionary = {}
var result: Dictionary = {}
var inventory: Node
var aiming: Node
var _player: Node
var _beams: Node3D
var _receiver: MeshInstance3D
var _receiver_label: Label3D
var _receiver_materials: Dictionary = {}
var _was_solved := false
var _last_hint := ""


func configure(carry: Node, player: Node = null) -> void:
	inventory = carry
	_player = player


func _ready() -> void:
	name = "Optics"
	model.restore(Game.get_flag("escape_optics_state", {}))
	_was_solved = bool(Game.get_flag("escape_prism_solved", false))
	_build_obstacle()
	_build_receiver()
	var emitter_mat := Art.material(Color(0.75, 0.9, 1), true)
	Art.cylinder(self, 0.24, 0.18, Model.world(Model.SOURCE, 4.8), emitter_mat)
	_add_device("S", Model.SOURCE, "starter")
	for id: String in Model.SOCKETS:
		_add_device(id, Model.SOCKETS[id], "prism")
	for id: String in Model.MOUNTS:
		_add_device(id, Model.MOUNTS[id], "lens")
	_beams = Beams.new()
	add_child(_beams)
	aiming = Aiming.new()
	aiming.name = "Aiming"
	aiming.configure(_player)
	aiming.adjusted.connect(_on_aim_adjusted)
	aiming.finished.connect(_on_aim_finished)
	add_child(aiming)
	add_child(OpticsSound.new())
	if inventory != null:
		inventory.changed.connect(_on_inventory_changed)
	refresh()


func _add_device(id: String, point: Vector2, kind: String) -> void:
	var device := Device.new()
	device.name = id
	device.device_id = id
	device.kind = kind
	device.position = Model.world(point, 0)
	device.scale = Vector3(.60, 1.0, .60)
	device.exchange_requested.connect(exchange_item)
	device.turn_requested.connect(begin_aim)
	add_child(device)
	devices[id] = device


func exchange_item(id: String) -> void:
	if inventory == null or not model.items.has(id):
		return
	var held := String(inventory.held_item)
	var item := String(model.items[id])
	if not model.accepts(id, held):
		Sound.play("unavailable", self)
		message.emit("That needs a %s. Your held item stays safe." % ["prism" if Model.SOCKETS.has(id) else "colored lens"])
		return
	if held.is_empty() and item.is_empty():
		message.emit("An empty prism socket. The pyramid's reward will fit here." if Model.SOCKETS.has(id) else "An empty lens mount. Move a colored lens here.")
		return
	model.items[id] = inventory.exchange(item)
	var at: Vector3 = devices[id].global_position + Vector3.UP
	if not item.is_empty():
		Sound.play_at("pickup", at, self)
	if not held.is_empty():
		Sound.play_at("place", at, self)
	if Model.SOCKETS.has(id) and String(model.items[id]).is_empty():
		model.head_angles.erase(id)
	message.emit("%s · %s" % [id, "item taken" if String(model.items[id]).is_empty() else "item placed"])
	refresh()


func rotate_prism(id: String) -> void:
	# Deterministic convenience for tests and future scripted setup. World handles
	# use begin_aim(), which never steps directly between these presets.
	model.rotate(id)
	refresh()


func begin_aim(id: String) -> void:
	if not devices.has(id) or (id != "S" and model.items.get(id, "") != "prism"):
		return
	var incoming: Vector2 = result.get("incoming", {}).get(id, Vector2.ZERO)
	var angle: float = model.source_angle if id == "S" else model.head_angle(id, incoming)
	var targets: Array[float] = []
	if id == "S":
		targets = model.source_snap_angles()
	elif incoming != Vector2.ZERO:
		targets.assign([incoming.angle() - PI / 2, incoming.angle() + PI / 2])
	else:
		targets.assign([angle, wrapf(angle + PI, -PI, PI)])
	devices[id].set_adjusting(true, false)
	aiming.begin(id, angle, targets)


func end_aim() -> void:
	if is_instance_valid(aiming):
		aiming.finish()


func _on_aim_adjusted(angle: float, snapped: bool) -> void:
	var id: String = aiming.active_id
	if id == "S":
		model.source_angle = angle
	else:
		model.head_angles[id] = angle
	devices[id].set_head_angle(angle, true)
	devices[id].set_adjusting(true, snapped)
	refresh(false)
	var hint := "%s · %d° · %s\n{turn} to turn · {interact} to finish · {back} to leave" % [id, roundi(rad_to_deg(angle)), "snapped" if snapped else "adjusting"]
	if result.hit == "misaligned":
		hint = "%s · align the inlet with the beam\n{turn} to turn · {interact} to finish · {back} to leave" % id
	if hint != _last_hint:
		_last_hint = hint
		aiming_changed.emit(true, hint)


func _on_aim_finished(id: String) -> void:
	if is_instance_valid(devices.get(id)):
		devices[id].set_adjusting(false, false)
	_last_hint = ""
	if is_inside_tree():
		refresh()
		aiming_changed.emit(false, "")


func refresh(persist := true) -> void:
	if not is_node_ready():
		return
	result = model.trace()
	_beams.draw_trace(result)
	_refresh_devices()
	_receiver.material_override = _receiver_materials[result.color if result.hit == "receiver" else -1]
	_receiver_label.text = "02 · OPEN" if _was_solved else "GREEN REQUIRED"
	if persist:
		Game.set_flag("escape_optics_state", model.save_state())
	if result.won and not _was_solved:
		Sound.play_at("receiver", Model.world(Model.RECEIVER), self)
		_was_solved = true
		Game.set_flag("escape_prism_solved")
		_receiver_label.text = "02 · OPEN"
		message.emit("Green received. Door 2 is opening!")
		solved.emit()
	changed.emit()


func _on_inventory_changed(_item: String = "") -> void:
	_refresh_devices()


func _refresh_devices() -> void:
	var held := String(inventory.held_item) if inventory != null else ""
	for id: String in devices:
		var item := "prism" if id == "S" else String(model.items[id])
		var incoming: Vector2 = result.get("incoming", {}).get(id, Vector2.ZERO)
		# Absolute heads must not briefly tween toward the legacy relative turn
		# before their saved angle is applied again on every source adjustment.
		var visual_incoming := Vector2.ZERO if model.head_angles.has(id) else incoming
		devices[id].update_state(item, held, int(model.turns.get(id, -1)), visual_incoming)
		if id == "S":
			devices[id].point_source(Vector2.from_angle(model.source_angle))
		elif model.head_angles.has(id):
			devices[id].set_head_angle(float(model.head_angles[id]), true)


func _build_receiver() -> void:
	var assembly: Dictionary = Hardware.build_receiver(self, Model.world(Model.RECEIVER))
	_receiver = assembly.core
	_receiver_label = assembly.label
	for color: int in Model.COLORS:
		_receiver_materials[color] = Art.material(Model.COLORS[color], true)
	_receiver_materials[-1] = Art.material(Color(.04, .14, .08), true)


func _build_obstacle() -> void:
	var center: Vector2 = Model.OBSTACLE.get_center()
	var size := Vector3(Model.OBSTACLE.size.x * Model.WORLD_SCALE, 2.4, Model.OBSTACLE.size.y * Model.WORLD_SCALE)
	Hardware.build_engine(self, Model.world(center, size.y / 2), size)
