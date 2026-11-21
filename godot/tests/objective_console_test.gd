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
