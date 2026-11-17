extends SceneTree
## The keyboard skip still follows Egypt's real win, trophy and reward lifecycle.
var _checks := 0
var _failures := 0
var _games: Node
var _game: Node
var _sound: Node
var _room: Node
var _result: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 120
	Engine.time_scale = 4.0
	root.size = Vector2i(1280, 720)
	_games = root.get_node("MiniGames")
	_game = root.get_node("Game")
	_sound = root.get_node("Sound")
	_game.flags.clear()
	_game.completed_minigames.clear()
	_game.set_flag("room_visited")
	_room = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	await physics_frame
	var puzzle: Node = await _open()
	if puzzle == null:
		quit(1)
		return
	_expect(not puzzle._solved, "Egypt starts unsolved")
	_key(false)
	await process_frame
	_expect(not puzzle._solved, "Plain L does not skip")
	_key(true, true)
	await process_frame
	_expect(not puzzle._solved, "A different modifier chord does not skip")
	_key(true, false, true)
	await process_frame
	_expect(not puzzle._solved, "Auto-repeat does not trigger the cheat")
	_sound.settings_open = true
	_key(true)
	await process_frame
	_expect(not puzzle._solved, "Sound settings block the cheat")
	_sound.settings_open = false
	_action("interact")
	await process_frame
	_expect(puzzle._grabbed >= 0, "A real interact event grabs a roller")
	_key(true)
	await process_frame
	_expect(puzzle._solved and puzzle._grabbed == -1, "Shift+L solves Egypt and releases the roller")
	for crystal: Dictionary in puzzle._crystals:
		_expect(crystal.mat.emission_enabled and crystal.light.light_energy > 0, "Each crystal visibly lights")
	for pyramid: Dictionary in puzzle._pyramids:
		_expect(pyramid.ok and pyramid.ring.emission_energy_multiplier > 0, "Each pyramid has its solved glow")
	var celebrations := _celebrations(puzzle)
	_expect(celebrations == 1, "Cheat starts the normal ribbon celebration")
	_key(true)
	await process_frame
	_expect(_celebrations(puzzle) == celebrations, "Repeating the cheat cannot duplicate the celebration")
	_action("interact")
	await _returned()
	_expect(_result.get("won", false), "Continue returns a win through MiniGames")
	_expect(_result.get("pyramids", []).size() == 3, "Win carries all three trophy pyramids")
	var colors: Array = []
	for pyramid: Dictionary in _result.get("pyramids", []):
		if pyramid.color not in colors:
			colors.append(pyramid.color)
	_expect(colors.size() == 3, "Trophy preserves three different colors")
	_expect(_game.completed_minigames.has("newton"), "Win is registered in the real game state")
	for frame in 600:
		if _room.reward_reveal.active:
			break
		await process_frame
	_expect(_room.reward_reveal.active, "Leaving the solved puzzle starts the reward camera reveal")
	await create_timer(3.6).timeout
	_expect(_room.reward_pedestal.is_revealed and _room.reward_pedestal.visible, "Normal reveal exposes the pedestal")
	for slot: Node in _room.reward_pedestal.slots:
		_expect(slot.slot_item == "prism" and slot._available, "Both prism rewards are available")
	_expect(not paused and not _room.get_node("Player").cinematic_locked, "Reveal restores hub controls")
	_room.reward_pedestal.slots[0].interact(_room.get_node("Player"))
	_expect(_room.inventory.held_item == "prism", "The first reward can be collected")
	puzzle = await _open()
	if puzzle != null:
		_key(true)
		await process_frame
		_action("back")
		await _returned()
		_expect(_result.get("won", false), "Escape after skipping still returns a win")
		_expect(_room.reward_pedestal.slots[0].slot_item == "", "Replaying cannot refill a collected reward")
	_room.queue_free()
	await process_frame
	print("Egypt skip: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _launch() -> void:
	_result = await _games.play("newton")


func _open() -> Node:
	_result = {}
	_launch.call_deferred()
	for frame in 600:
		if _games.current != null:
			await process_frame
			return _games.current
		await process_frame
	_expect(false, "Egypt loads through the normal minigame launcher")
	return null


func _returned() -> void:
	for frame in 600:
		if _games.current == null:
			await process_frame
			return
		await process_frame
	_expect(false, "The solved puzzle returns to the hub")


func _key(shift: bool, ctrl := false, echo := false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_L
		event.physical_keycode = KEY_L
		event.shift_pressed = shift
		event.ctrl_pressed = ctrl
		event.pressed = pressed
		event.echo = echo and pressed
		Input.parse_input_event(event)


func _action(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


func _celebrations(puzzle: Node) -> int:
	var total := 0
	for child: Node in puzzle._model.get_parent().get_children():
		if child is NewtonTrophy:
			total += 1
	return total


func _expect(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(description)
