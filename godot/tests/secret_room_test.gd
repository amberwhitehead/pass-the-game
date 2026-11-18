extends "res://tests/test_suite.gd"
## The Easter egg in the real hall with real key events: the panel and its inscription
## are where a player can reach them, the normal prompt and Interact (including a
## remapped key) enter, the arrival is clear and faces the exact signs, a held key does
## not bounce back, pause works inside, Return restores position and view (or the safe
## entrance when blocked), carried items and progress survive, and repeat visits work.

const KeyBindings := preload("res://autoload/key_bindings.gd")
var _checks := 0
var _failures := 0
var _room: Node3D
var _player: Player
var _secret: Node3D
var _menu: CanvasLayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_menu = root.get_node("PauseMenu")
	root.get_node("Game").set_flag("room_visited")
	_room = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	_player = _room.get_node("Player")
	_secret = _room.get_node("SecretRoom")
	await _physics(5)
	_layout()
	await _enter_and_return()
	await _held_and_pause()
	await _blocked_return()
	await _remapped_and_repeat()
	KeyBindings.apply(KeyBindings.defaults())
	print("Secret room: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _layout() -> void:
	var labels := _labels(_secret)
	_expect("Not every room has a number." in labels, "The inscription reads exactly")
	_expect("You found an Easter Egg!" in labels and "This room should be developed by other developers." in labels,
		"Both room signs read exactly")
	_expect("Return to the hall" in labels and _secret.exit.prompt == "Return to the hall", "The return panel is labelled")
	_expect(_secret.entrance.prompt == "Inspect unusual panel", "The entrance prompt")
	_expect(_secret.room.global_position.y <= -6.0, "The room is far below the hall floor")
	var panel_top: Vector3 = _secret.entrance.get_focus_position()
	_expect(panel_top.x < 10.86 and absf(panel_top.y - 1.15) < .01, "The panel's focus point is in front of the wall at chest height")
	for label: Label3D in _all_labels(_secret):
		_expect(not label.no_depth_test, "Sign '%s' is depth-tested" % label.text.left(24))
	_expect(not Game.flags.has("secret_room"), "Nothing about the room is saved")


func _enter_and_return() -> void:
	_room.inventory.held_item = "prism"
	var flags_before: Dictionary = Game.flags.duplicate(true)
	await _stand_at_panel(Vector3(9.3, 0, 5.4), -0.2)
	_expect(_player.target == _secret.entrance, "Standing 1.5 m from the panel targets it")
	await _physics(2)
	_expect(_room.hud._prompt.visible and _secret.entrance.prompt in _room.hud._prompt.title.text,
		"The normal prompt shows 'Inspect unusual panel'")
	var before := {"position": _player.global_position, "yaw": _player.rotation.y, "pitch": _player.camera.rotation.x}
	await _tap(KEY_E)
	await _physics(3)
	_expect(_secret.inside and _player.global_position.y < -5.5, "Interact enters the room")
	_expect(is_equal_approx(_player.rotation.y, 0.0) and is_zero_approx(_player.camera.rotation.x), "Arrival faces the signs")
	_expect(_player.velocity.length() < .5 and _player.is_on_floor(), "Arrival stands still on the room's floor")
	_expect(_player.target != _secret.exit, "The return panel is not targeted on arrival")
	# Walk about: walls are solid.
	await _hold(KEY_A, 90)
	_expect(absf(_player.global_position.x) < 2.7 and _player.global_position.y < -5.5, "Walls stop the player inside the room")
	await _walk_to_exit()
	_expect(_player.target == _secret.exit, "The return panel can be reached and targeted")
	await _tap(KEY_E)
	await _physics(3)
	_expect(not _secret.inside and _player.global_position.distance_to(before.position) < .1,
		"Return puts the player back where they were")
	_expect(is_equal_approx(_player.rotation.y, before.yaw) and is_equal_approx(_player.camera.rotation.x, before.pitch),
		"Return restores the facing and pitch")
	await _physics(20)
	_expect(_player.is_on_floor() and absf(_player.global_position.y) < .05, "The hall floor holds after returning")
	_expect(_room.inventory.held_item == "prism" and Game.flags == flags_before, "Carried item and progress are unchanged")
	_room.inventory.held_item = ""


func _held_and_pause() -> void:
	await _stand_at_panel(Vector3(9.3, 0, 5.4), -0.2)
	await _key(KEY_E, true)
	await _physics(3)
	for repeat in 10:  # Holding E sends repeats, never a fresh press.
		await _key(KEY_E, true, true)
	await _physics(5)
	_expect(_secret.inside, "Holding Interact through entry does not bounce back")
	await _key(KEY_E, false)
	await _tap(KEY_ESCAPE)
	_expect(_menu.is_open() and paused, "Pause works inside the room")
	var at := _player.global_position
	await _physics(10)
	await _tap(KEY_ESCAPE)
	await _physics(3)
	_expect(not paused and _secret.inside and _player.global_position.distance_to(at) < .05,
		"Resuming keeps the player in the room")
	await _walk_to_exit()
	await _tap(KEY_E)
	await _physics(3)
	_expect(not _secret.inside, "Return still works after pausing")


func _blocked_return() -> void:
	await _stand_at_panel(Vector3(9.3, 0, 5.4), -0.2)
	var spot := _player.global_position
	await _tap(KEY_E)
	await _physics(3)
	var block := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 2, 1)
	shape.shape = box
	block.add_child(shape)
	block.position = spot + Vector3.UP
	_room.add_child(block)
	await _physics(2)
	await _walk_to_exit()
	await _tap(KEY_E)
	await _physics(3)
	_expect(not _secret.inside and _player.global_position.distance_to(Vector3(-9.5, 0, .4)) < .1,
		"A blocked return spot sends the player to the hall entrance")
	block.queue_free()
	await _physics(2)


func _remapped_and_repeat() -> void:
	var bindings := KeyBindings.defaults()
	bindings.interact = [KEY_G, KEY_ENTER, KEY_F]
	KeyBindings.apply(bindings)
	await _stand_at_panel(Vector3(9.3, 0, 5.4), -0.2)
	await _tap(KEY_E)
	await _physics(3)
	_expect(not _secret.inside, "The replaced E key no longer opens the panel")
	await _tap(KEY_G)
	await _physics(3)
	_expect(_secret.inside, "The remapped Interact key opens the panel")
	await _walk_to_exit()
	await _tap(KEY_G)
	await _physics(3)
	_expect(not _secret.inside, "The remapped key returns too")
	for visit in 2:
		await _stand_at_panel(Vector3(9.3, 0, 5.4), -0.2)
		await _tap(KEY_G)
		await _physics(3)
		await _walk_to_exit()
		await _tap(KEY_G)
		await _physics(3)
	_expect(not _secret.inside and _player.global_position.y > -1.0, "Repeat visits come and go cleanly")


func _stand_at_panel(at: Vector3, pitch: float) -> void:
	_player.global_position = at
	_player.velocity = Vector3.ZERO
	var to: Vector3 = _secret.entrance.get_focus_position() - at
	_player.rotation.y = atan2(-to.x, -to.z)
	_player.camera.rotation.x = pitch
	await _physics(6)


func _walk_to_exit() -> void:
	var stand: Vector3 = _secret.exit.get_focus_position() + Vector3(0, 0, 1.4)
	stand.y = _secret.room.global_position.y
	_player.global_position = stand
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	_player.camera.rotation.x = -0.2
	await _physics(6)


func _labels(node: Node) -> PackedStringArray:
	var found: PackedStringArray = []
	for label: Label3D in _all_labels(node):
		found.append(label.text)
	return found


func _all_labels(node: Node) -> Array[Label3D]:
	var found: Array[Label3D] = []
	for child in node.find_children("*", "Label3D", true, false):
		found.append(child as Label3D)
	return found


func _key(key: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	await _physics(2)


func _tap(key: Key) -> void:
	await _key(key, true)
	await _key(key, false)


func _hold(key: Key, ticks: int) -> void:
	await _key(key, true)
	await _physics(ticks)
	await _key(key, false)


func _physics(count: int) -> void:
	for tick in count:
		await physics_frame


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
