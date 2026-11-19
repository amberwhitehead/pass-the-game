extends "res://tests/test_suite.gd"
## Keyboard-and-mouse movement through the real Player scene on a small physics fixture:
## yaw-relative walking and strafing, horizontal walking at both pitch limits, equal straight
## and diagonal speed, jumping (standing, moving, walls, a low ceiling, falling, no air jumps),
## pause preserving a jump without replaying held keys, the remapped keys, emulated touch
## not looking twice, the mouse-capture gate, and the wheel turning with A/D.

var _checks := 0
var _failures := 0
var _player: Player
var _menu: CanvasLayer
const FLOOR_Y := 0.0
const WALL_X := 4.0
const CEILING := Vector3(-8, 2.0, 0)  # Underside of a low slab, 0.3 m above the head.
const LEDGE := Vector3(0, 0.5, 10)  # A 0.5 m platform to walk off.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Four physics ticks per real tick, each still exactly 1/60 s of game time.
	var ticks_per_second := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = ticks_per_second * 4
	Engine.time_scale = 4.0
	_menu = root.get_node("PauseMenu")
	var world := Node3D.new()
	world.name = "MovementFixture"
	root.add_child(world)
	_box(world, Vector3(0, FLOOR_Y - 0.1, 0), Vector3(40, 0.2, 40))
	_box(world, Vector3(WALL_X + 0.1, 1.5, 0), Vector3(0.2, 3, 40))
	_box(world, CEILING + Vector3(0, 0.1, 0), Vector3(3, 0.2, 3))
	_box(world, LEDGE + Vector3(0, -0.25, 0), Vector3(3, 0.5, 3))  # Top surface at LEDGE.y.
	_player = load("res://scenes/room/player.tscn").instantiate()
	world.add_child(_player)
	await _ticks(10)
	_expect(_player.is_on_floor(), "The player stands on collision rather than floating")
	_keys()
	await _facing()
	await _pitch_limits()
	await _speeds()
	await _jumping()
	await _pause_resume()
	await _touch_and_mouse()
	await _capture_gate()
	await _wheel()
	_release_all()
	world.queue_free()
	await _space_near_interactable()
	Engine.physics_ticks_per_second = ticks_per_second
	print("Player movement: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _keys() -> void:
	_expect(_key(KEY_SPACE).is_action("jump") and not _key(KEY_SPACE).is_action("interact"),
		"Space jumps and no longer interacts")
	for key: Key in [KEY_E, KEY_ENTER, KEY_F]:
		_expect(_key(key).is_action("interact"), "%s still interacts" % OS.get_keycode_string(key))
	_expect(_key(KEY_A).is_action("strafe_left") and not _key(KEY_A).is_action("move_left"),
		"A strafes instead of turning")
	_expect(_key(KEY_D).is_action("strafe_right") and not _key(KEY_D).is_action("move_right"),
		"D strafes instead of turning")
	_expect(_key(KEY_LEFT).is_action("move_left") and _key(KEY_RIGHT).is_action("move_right"),
		"Arrow keys still turn")
	var dpad := InputEventJoypadButton.new()
	dpad.button_index = JOY_BUTTON_DPAD_LEFT
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = -1.0
	var pad_a := InputEventJoypadButton.new()
	pad_a.button_index = JOY_BUTTON_A
	_expect(dpad.is_action("move_left") and stick.is_action("strafe_left") and pad_a.is_action("interact"),
		"Gamepad bindings are unchanged")


func _facing() -> void:
	await _place(Vector3.ZERO, PI / 2)
	var yaw := _player.rotation.y
	var moved := await _hold(["move_up"], 30)
	_expect(moved.normalized().dot(Vector3.LEFT) > 0.99, "After turning 90 degrees, W walks the new facing")
	moved = await _hold(["move_down"], 30)
	_expect(moved.normalized().dot(Vector3.RIGHT) > 0.99, "S walks straight back along the new facing")
	moved = await _hold(["strafe_right"], 30)
	_expect(moved.normalized().dot(Vector3.FORWARD) > 0.99, "D strafes to the facing's right")
	moved = await _hold(["strafe_left"], 30)
	_expect(moved.normalized().dot(Vector3.BACK) > 0.99, "A strafes to the facing's left")
	_expect(is_equal_approx(_player.rotation.y, yaw), "Strafing never changes yaw")


func _pitch_limits() -> void:
	for pitch in [_player.max_pitch, -_player.max_pitch]:
		await _place(Vector3.ZERO, 0.0)
		_player.look(Vector2(0, -100000 * signf(pitch)), _player.mouse_sensitivity)
		_expect(is_equal_approx(_player.camera.rotation.x, pitch), "Looking clamps at the pitch limit (%.1f)" % pitch)
		var moved := await _hold(["move_up"], 30)
		_expect(absf(moved.y) < 0.005, "Walking at pitch %.1f stays on the ground plane" % pitch)
		_expect(absf(_horizontal_speed() - _player.speed) < 0.05 or absf(moved.length() / (30.0 / 60.0) - _player.speed) < 0.2,
			"Walking at pitch %.1f keeps full speed" % pitch)
	_player.camera.rotation.x = 0.0


func _speeds() -> void:
	await _place(Vector3.ZERO, 0.0)
	_press(["move_up"])
	await _ticks(3)
	var straight := _horizontal_speed()
	_press(["strafe_right"])
	await _ticks(3)
	var diagonal := _horizontal_speed()
	_release_all()
	_expect(absf(straight - _player.speed) < 0.01, "Walking straight moves at the configured speed")
	_expect(absf(diagonal - straight) < 0.01, "Diagonal input is no faster than straight")
	await _place(Vector3.ZERO, 0.0)
	_press(["move_up"])
	await _ticks(2)
	var yaw := _player.rotation.y
	var lowest := INF
	for tick in 30:
		_player.look(Vector2(12, 4), _player.mouse_sensitivity)
		await physics_frame
		lowest = minf(lowest, _horizontal_speed())
	_release_all()
	_expect(not is_equal_approx(_player.rotation.y, yaw) and lowest > _player.speed - 0.01,
		"Moving and looking work together without losing speed")
	_player.camera.rotation.x = 0.0


func _jumping() -> void:
	await _place(Vector3.ZERO, 0.0)
	var peak := await _jump_peak(false)
	_expect(absf(peak - _player.jump_height) < 0.06, "A standing jump rises about %.2f m (%.3f)" % [_player.jump_height, peak])
	_expect(_player.is_on_floor() and absf(_player.position.y - FLOOR_Y) < 0.02, "The jump lands back on the floor")
	await _place(Vector3.ZERO, 0.0)
	_press(["jump"])
	await _ticks(2)
	_release(["jump"])
	await _ticks(8)
	var rising := _player.velocity.y
	_expect(rising > 0.0 and not _player.is_on_floor(), "Fixture is rising before the second press")
	_press(["jump"])
	await _ticks(2)
	_expect(_player.velocity.y < rising, "A press in the air adds no extra jump")
	await _ticks(60)
	_expect(_player.is_on_floor(), "Landing still happens with jump held")
	await _ticks(20)
	_expect(_player.is_on_floor() and absf(_player.position.y) < 0.02, "Holding jump does not bounce again")
	_release_all()
	await _place(Vector3.ZERO, 0.0)
	_press(["move_up"])
	await _ticks(2)
	var start := _player.position
	_press(["jump"])
	await _ticks(1)
	var airborne_speed := INF
	for tick in 15:
		await physics_frame
		if not _player.is_on_floor():
			airborne_speed = minf(airborne_speed, _horizontal_speed())
	_release_all()
	await _ticks(40)
	_expect(_player.position.z < start.z - 1.0 and airborne_speed > _player.speed - 0.05,
		"A running jump carries forward momentum")
	await _place(Vector3(WALL_X - 1.0, 0, 0), -PI / 2)
	await _hold(["move_up"], 60)
	_expect(_player.position.x < WALL_X - 0.34 and _player.position.x > WALL_X - 0.5, "Walls stop the capsule")
	_press(["move_up", "jump"])
	await _ticks(30)
	_release_all()
	_expect(_player.position.x < WALL_X - 0.34, "Jumping into a wall does not pass through it")
	await _ticks(40)
	await _place(Vector3(-3, 3, 0), 0.0, false)
	await _ticks(70)
	_expect(_player.is_on_floor() and absf(_player.position.y) < 0.02, "Falling lands on the floor")
	await _place(CEILING * Vector3(1, 0, 1), 0.0)
	peak = await _jump_peak(false)
	_expect(peak + 1.7 <= CEILING.y + 0.03, "A low ceiling stops the head (peak %.3f)" % peak)
	_expect(_player.is_on_floor(), "After hitting the ceiling the player falls back down")
	# Walk off a ledge: no snap down, a real fall that keeps its momentum, then a landing.
	await _place(LEDGE, 0.0)
	_expect(_player.is_on_floor() and absf(_player.position.y - LEDGE.y) < 0.02, "The player stands on the ledge")
	_press(["move_up"])
	var left_ledge := false
	var fell_moving := false
	for tick in 90:
		await physics_frame
		if not _player.is_on_floor() and _player.position.y < LEDGE.y - 0.05:
			left_ledge = true
			fell_moving = fell_moving or _horizontal_speed() > _player.speed - 0.05
	_release_all()
	await _ticks(30)
	_expect(left_ledge and fell_moving, "Walking off the ledge falls while still moving forward")
	_expect(_player.is_on_floor() and absf(_player.position.y - FLOOR_Y) < 0.02, "The fall lands on the floor below")
	# A modal lock in mid-air must not freeze the jump in place.
	await _place(Vector3.ZERO, 0.0)
	_press(["jump"])
	await _ticks(4)
	_release_all()
	_player.interaction_locked = true
	await _ticks(60)
	_expect(_player.is_on_floor(), "A lock taken mid-jump still lets gravity land the player")
	_player.interaction_locked = false


func _pause_resume() -> void:
	await _place(Vector3.ZERO, 0.0)
	_press(["move_up"])
	await _ticks(3)
	_press(["jump"])
	await _ticks(5)
	_player.look(Vector2(40, -20), _player.mouse_sensitivity)
	var yaw := _player.rotation.y
	var pitch := _player.camera.rotation.x
	var vertical := _player.velocity.y
	var at := _player.position
	_expect(not _player.is_on_floor() and vertical > 0.0, "Fixture is mid-jump and moving before pausing")
	_menu.open_hall()
	await _ticks(30)
	_expect(_player.position.is_equal_approx(at) and is_equal_approx(_player.velocity.y, vertical),
		"Pause freezes the jump in progress")
	_player.look(Vector2.ZERO, 0.0)
	_menu.close()  # W and Space are still held from before the menu.
	await physics_frame
	_expect(_player.velocity.y < vertical and _player.velocity.y > vertical - 1.0,
		"Resuming continues the same jump")
	_expect(is_equal_approx(_player.rotation.y, yaw) and is_equal_approx(_player.camera.rotation.x, pitch),
		"Resuming keeps yaw and pitch without a snap")
	await _ticks(60)
	_expect(_player.is_on_floor(), "The resumed jump lands")
	var landed := _player.position
	await _ticks(20)
	_expect(_player.position.distance_to(landed) < 0.01, "Keys held through the menu do not walk or jump after resuming")
	_release_all()
	await _ticks(2)
	var moved := await _hold(["move_up"], 10)
	_expect(moved.length() > 0.3, "A fresh press after release moves again")
	# Space used to press Resume must not jump.
	_menu.open_hall()
	_press(["jump"])
	await process_frame
	_menu.close()
	await _ticks(10)
	_release_all()
	_expect(_player.is_on_floor() and absf(_player.position.y) < 0.02, "Space pressed in the menu does not jump on resume")


func _touch_and_mouse() -> void:
	await _place(Vector3.ZERO, 0.0)
	var yaw := _player.rotation.y
	var touch := InputEventScreenTouch.new()
	touch.device = InputEvent.DEVICE_ID_EMULATION
	touch.pressed = true
	touch.position = Vector2(640, 300)
	_player._input(touch)
	var drag := InputEventScreenDrag.new()
	drag.device = InputEvent.DEVICE_ID_EMULATION
	drag.relative = Vector2(100, 0)
	_player._input(drag)
	_expect(is_equal_approx(_player.rotation.y, yaw) and _player._look_finger == -1,
		"Mouse drags emulated as touch do not turn the view a second time")
	touch.device = 0
	_player._input(touch)
	drag.device = 0
	_player._input(drag)
	_expect(is_equal_approx(_player.rotation.y, yaw - 100 * _player.drag_sensitivity), "Real touch drag-to-look still works")
	touch.pressed = false
	_player._input(touch)
	var motion := InputEventMouseMotion.new()
	motion.screen_relative = Vector2(50, 0)
	motion.relative = Vector2(50, 0)
	yaw = _player.rotation.y
	_player._input(motion)
	_expect(is_equal_approx(_player.rotation.y, yaw), "An uncaptured mouse does not look")


func _capture_gate() -> void:
	var capture := _player.mouse_capture
	_expect(not capture.keyboard_mouse and not capture.blocks_input(), "Headless runs never wait for a cursor")
	capture.keyboard_mouse = true
	await _place(Vector3.ZERO, 0.0)
	_expect(capture.wants_capture() and capture.blocks_input() and _player._frozen(),
		"Keyboard/mouse play without capture blocks the player")
	var moved := await _hold(["move_up"], 10)
	_expect(moved.length() < 0.001, "Blocked keyboard input does not walk")
	await process_frame
	_expect(capture._card.visible, "The click-to-continue card shows while capture is missing")
	_menu.open_hall()
	_expect(not capture.wants_capture(), "The pause menu gets the cursor")
	_menu.close()
	var sound := root.get_node("Sound")
	sound.settings_open = true
	_expect(not capture.wants_capture(), "Sound settings get the cursor")
	sound.settings_open = false
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	capture._input(pad)
	_expect(not capture.keyboard_mouse and not capture.blocks_input(), "Switching to a gamepad needs no capture")
	await process_frame
	_expect(not capture._card.visible, "The card hides for gamepad play")


func _wheel() -> void:
	await _place(Vector3.ZERO, 0.0)
	var aim: Node = load("res://scenes/escape/optics_aiming.gd").new()
	aim.configure(_player)
	root.add_child(aim)
	var targets: Array[float] = []
	aim.begin("S", 0.0, targets)
	var at := _player.position
	_press(["strafe_right"])
	for frame in 10:
		await process_frame
	_release_all()
	_expect(aim.raw_angle < -0.01, "D turns a held wheel while the player is locked")
	_expect(_player.position.distance_to(at) < 0.001, "The locked player does not strafe")
	aim.finish()
	aim.queue_free()


## In the real hall, facing a talking NPC: a real Space key event jumps without talking;
## a real E key event still starts the conversation.
func _space_near_interactable() -> void:
	root.get_node("Game").set_flag("room_visited")
	var room: Node3D = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	var player: Player = room.get_node("Player")
	var npc: NPC = room.get_node("Egyptian")
	var dialogue := root.get_node("Dialogue")
	await _ticks(5)
	for direction: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		player.global_position = npc.global_position + direction * 1.6
		player.global_position.y = 0.0
		player.velocity = Vector3.ZERO
		var to := npc.global_position - player.global_position
		player.rotation.y = atan2(-to.x, -to.z)
		player.camera.rotation.x = -0.15
		await _ticks(6)
		if player.target == npc:
			break
	_expect(player.target == npc, "Fixture faces the Egyptian closely enough to interact")
	await _real_key(KEY_SPACE)
	await _ticks(3)
	_expect(not dialogue.active, "Space beside an NPC does not start the conversation")
	_expect(player.velocity.y > 0.0 or not player.is_on_floor(), "Space beside an NPC jumps")
	await _ticks(60)
	await _real_key(KEY_E)
	await _ticks(2)
	_expect(dialogue.active, "E beside the NPC still starts the conversation")
	dialogue.active = false
	dialogue._panel.visible = false
	room.queue_free()
	await _ticks(2)


func _real_key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await _ticks(3)


func _jump_peak(hold_after: bool) -> float:
	var peak := _player.position.y
	_press(["jump"])
	await _ticks(2)  # A quick, realistic tap.
	if not hold_after:
		_release(["jump"])
	for tick in 70:
		await physics_frame
		peak = maxf(peak, _player.position.y)
	_release_all()
	return peak


func _place(at: Vector3, yaw: float, settle := true) -> void:
	_release_all()
	_player.position = at
	_player.rotation.y = yaw
	_player.velocity = Vector3.ZERO
	_player.camera.rotation.x = 0.0
	if settle:
		await _ticks(4)


func _hold(actions: Array, ticks: int) -> Vector3:
	var start := _player.position
	_press(actions)
	await _ticks(ticks)
	_release(actions)
	await _ticks(1)
	return _player.position - start


func _press(actions: Array) -> void:
	for action: String in actions:
		Input.action_press(action)


func _release(actions: Array) -> void:
	for action: String in actions:
		Input.action_release(action)


func _release_all() -> void:
	for action in InputMap.get_actions():
		Input.action_release(action)


func _ticks(count: int) -> void:
	for tick in count:
		await physics_frame


func _horizontal_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func _key(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	return event


func _box(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
