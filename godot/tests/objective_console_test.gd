extends "res://tests/test_suite.gd"
## The objective console by the hall's entrance: it shows the current objective, follows
## the flags as they change, and when used turns its laser toward that objective's place
## and blinks it three times. The old top-left objective panel is gone.

const Objectives := preload("res://scenes/escape/objectives.gd")

var _checks := 0
var _failures := 0
var _game: Node
var _room: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.time_scale = 4.0
	root.size = Vector2i(1280, 720)
	_game = root.get_node("Game")
	_game.autosave = false
	_game.save_path = ""
	_game.flags.clear()
	_game.set_flag("room_visited")
	_room = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	await physics_frame
	var console: Node3D = _room.objective_console
	_expect(console != null and console.is_in_group("interactable"), "The console stands in the hall and can be used")
	_expect(console.global_position.y == 0.0 and console.global_position.distance_to(_room.get_node("Player").global_position) < 4.0,
		"It stands on the floor near where the player comes in")
	_expect(console._text.text == Objectives.current().text and "EGYPT" in console._chapter.text, "It shows the first objective")
	_expect(not _hud_mentions("FIELD NOTES"), "The top-left objective panel is gone")
	var pads := not Input.get_connected_joypads().is_empty()  # This machine may have a pad plugged in.
	_expect(_room.hud._interact_label().begins_with("pad:r1:") if pads else _room.hud._interact_label() == "Click", "The prompt says Click, or shows R1 with a controller plugged in")
	_expect(_room.hud._secondary_label().begins_with("pad:r2:") if pads else _room.hud._secondary_label() == "Right-click", "...and Right-click, or R2, for a second action")
	var drift := InputEventJoypadMotion.new()
	drift.device = 2
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = 0.08
	Input.parse_input_event(drift)
	await process_frame
	_expect(_room.hud._interact_key != "pad", "A drifting stick doesn't count as using the controller")
	var press := InputEventJoypadButton.new()
	press.device = 2
	press.button_index = JOY_BUTTON_DPAD_UP
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	press.pressed = false
	Input.parse_input_event(press)
	await process_frame
	_expect(_room.hud._interact_label().begins_with("pad:r1:") != Input.get_connected_joypads().is_empty(),
		"The prompt says R1 only while a controller is plugged in")
	var key := InputEventKey.new()
	key.keycode = KEY_SHIFT
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame

	await _r2_taps()
	await _shrugs()
	await _aim_at_stands()
	await _point_at(console, _room.get_node("Challenge4").global_position, "Egypt's station")

	_game.set_flag("escape_prism_solved")
	await process_frame
	_expect("ROMAN" in console._chapter.text, "Solving the beam updates the console")
	await _point_at(console, _room.get_node("Challenge5").global_position, "Roman Flow's station")

	_room.queue_free()
	await process_frame
	_game.flags.clear()
	Engine.time_scale = 1.0
	print("Objective console: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _point_at(console: Node3D, place: Vector3, what: String) -> void:
	console.interact(_room.get_node("Player"))
	await process_frame
	_expect(console.pointing, "Using it starts pointing at %s" % what)
	for frame in 600:
		if not console.pointing:
			break
		await process_frame
	var pivot: Node3D = console._pivot
	var aim := -pivot.global_basis.z
	var want := (place + Vector3(0, 1.0, 0) - pivot.global_position).normalized()
	_expect(aim.dot(want) > 0.99, "The laser turns toward %s (%.3f)" % [what, aim.dot(want)])
	_expect(console.blinks_done == 3 and not console._beam.visible, "It blinks three times at %s, then goes dark" % what)


## Looking straight at a stand targets that stand, even when a neighbour's knob is nearer
## in angle; the target gets a white outline, and the stand wears its letter.
func _aim_at_stands() -> void:
	var player = _room.get_node("Player")
	var devices: Dictionary = _room.optics.devices
	# Stand M beside D was the worst case: from its D side the old angle-only rule picked
	# D's knob more than half the time. Walk round each and look straight at its body.
	for id in ["M", "D", "K", "A"]:
		var dev: Node3D = devices[id]
		var body: Vector3 = dev.global_position + Vector3(0, 0.55, 0)
		var views := 0
		var wrong: Array = []
		for r in [1.2, 1.7]:
			for k in 16:
				var ang: float = TAU * k / 16.0
				var spot: Vector3 = dev.global_position + Vector3(cos(ang), 0, sin(ang)) * r
				player.global_position = Vector3(spot.x, 0, spot.z)
				player.velocity = Vector3.ZERO
				await physics_frame
				var to: Vector3 = body - player.camera.global_position
				player.rotation.y = atan2(-to.x, -to.z)
				player.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
				await physics_frame
				await physics_frame
				var hit: Dictionary = player._crosshair_hit(-player.camera.global_basis.z)
				if hit.is_empty() or not dev.is_ancestor_of(hit.collider):
					continue  # Something else is in the way from here.
				views += 1
				var got = player.target.outline_root().get("device_id") if player.target != null else null
				if got != id:
					wrong.append("%s from r%.1f/%d" % [got, r, k])
		_expect(views > 10 and wrong.is_empty(), "Looking straight at stand %s targets it (%d views; wrong: %s)" % [id, views, wrong])
		if player.target != null:
			var outlined := 0
			for m in player.target.outline_root().find_children("*", "MeshInstance3D", true, false):
				if (m as MeshInstance3D).material_overlay != null:
					outlined += 1
			_expect(outlined > 3, "The targeted stand is outlined (%d meshes)" % outlined)
		var letters := dev.find_children("*", "Label3D", true, false).filter(func(l): return l.text == id)
		_expect(letters.size() == 1, "Stand %s wears its letter" % id)
	player.global_position = Vector3(-9.5, 0, .4)
	for f in 3: await physics_frame


## Trying something that does nothing here gets a shrug: B on a controller with nothing to
## go back from (instead of the menu), using nothing, an empty mount with empty hands.
## Square is the second action, like R2.
func _shrugs() -> void:
	var player = _room.get_node("Player")
	var hands: Array = player.get_tree().get_nodes_in_group("player_feedback")
	_expect(hands.size() == 1, "The hands listen for shrugs")
	var b := InputEventJoypadButton.new()
	b.device = 2
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	hands[0].shrug_t = -1.0
	_room._unhandled_input(b)
	_expect(hands[0].shrug_t >= 0.0 and not root.get_node("PauseMenu").is_open(), "Circle with nothing to go back from shrugs, no menu")
	hands[0].shrug_t = -1.0
	_room.optics.exchange_item("C")  # An empty prism socket, empty hands.
	_expect(hands[0].shrug_t >= 0.0, "Using an empty socket with empty hands shrugs")
	var square := InputEventJoypadButton.new()
	square.device = 2
	square.button_index = JOY_BUTTON_X
	square.pressed = true
	_expect(square.is_action("secondary"), "Square is the second action, like R2")


## R2 is analog: a tap that rises and falls between two game ticks still takes, once;
## a trigger hovering around the threshold doesn't take twice.
func _r2_taps() -> void:
	var player = _room.get_node("Player")
	var dummy := _Taker.new()
	dummy.secondary_prompt = "Take it"
	_room.add_child(dummy)
	for values in [[0.0, 0.8, 0.0], [0.0, 0.4, 0.3, 0.38, 0.32, 0.0]]:
		dummy.taken = 0
		for v in values:
			player.target = dummy  # Normally set by looking at it each tick.
			var m := InputEventJoypadMotion.new()
			m.device = 2
			m.axis = JOY_AXIS_TRIGGER_RIGHT
			m.axis_value = v
			player._unhandled_input(m)
		_expect(dummy.taken == 1, "R2 %s takes exactly once (%d)" % [values, dummy.taken])
	dummy.queue_free()


class _Taker extends Interactable:
	var taken := 0
	func secondary(_p: Node3D) -> void:
		taken += 1


func _hud_mentions(text: String) -> bool:
	for label in _room.hud.find_children("*", "Label", true, false):
		if text in (label as Label).text:
			return true
	return false


func _expect(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(description)
