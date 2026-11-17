extends SceneTree
## Headless spatial input checks for the physical card table.
## Uses camera projection + real physics raycasts, never OS mouse input.

var _checks := 0
var _failures := 0
var _game: Node
var _games: Node
var _returned := false


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	Engine.time_scale = 8.0
	Engine.max_fps = 120
	root.size = Vector2i(1280, 720)
	_games = root.get_node("MiniGames")
	root.get_node("Game").set_flag("room_visited")
	var room: Node = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	call_deferred("_launch")
	for frame in 600:
		if _games.current != null:
			break
		await process_frame
	if _games.current == null:
		_expect(false, "Physical table launches through the actual hub overlay")
		quit(1)
		return
	_game = _games.current
	var table: Node = _game.table
	_expect(_game._entering, "Table starts with its battle entrance active")
	var entry_state: Dictionary = _game.match_state.snapshot()
	_mouse_press(_screen_point(table.hand_cards[0]))
	await process_frame
	_expect(_game._selected == -1 and _game.match_state.snapshot() == entry_state,
		"Actual pointer input cannot play through the entrance")
	await _entry_complete()
	await _settle()
	_expect(table.camera is Camera3D, "Table has a physical perspective camera")
	_expect(table.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Table uses perspective projection")
	_expect(table.viewport is SubViewport, "Table owns a rendered 3D viewport")
	_expect(table.player_slots[0] is Node3D, "Board cards are physical 3D actors")
	_expect(table.hand_cards[0] is Node3D, "Hand cards are physical 3D actors")
	_expect(table.end_button is Node3D, "End-turn control lives on the table")
	var first_card: Node3D = table.hand_cards[0]
	table.activate_at(_screen_point(first_card))
	_expect(_game._selected == -1, "Rules modal prevents spatial selection behind it")
	_game._close_dialog()
	await _settle()
	_expect(not table.hand.expanded, "Hand starts tucked below the table view")
	_expect(table.intent_glow.active_lanes == [1], "Opening incoming glow marks only the middle lane")
	table.intent_glow.set_intents([{"card": "scout", "lane": 0}, {"card": "heavy", "lane": 2}, {"card": "bolt", "lane": 2}])
	_expect(table.intent_glow.active_lanes == [0, 2], "Multiple upcoming cards mark each destination lane once")
	_expect(table.intent_glow.get_node("IncomingLane1").visible and not table.intent_glow.get_node("IncomingLane2").visible and table.intent_glow.get_node("IncomingLane3").visible,
		"Incoming glow visibility matches multiple destination lanes")
	_expect(table.intent_glow.find_children("*", "Label3D", true, false).is_empty(),
		"Incoming cue contains no card identity text")
	_game._refresh()

	for window_size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(960, 540), Vector2i(688, 921)]:
		root.size = window_size
		await _settle()
		await _tuck_hand()
		for side in ["player", "enemy"]:
			var actors: Array = table.player_slots if side == "player" else table.enemy_slots
			for lane in actors.size():
				_expect(table.pick_actor(_screen_point(actors[lane])) == actors[lane],
					"%s lane %d ray hits its card at %s" % [side, lane + 1, window_size])
		await _reveal_hand()
		_expect(table.hand.expanded, "Moving toward the bottom reveals the hand at %s" % window_size)
		for index in table.hand_cards.size():
			_expect(_inside_play_area(_screen_point(table.hand_cards[index])) and table.pick_actor(_screen_point(table.hand_cards[index])) == table.hand_cards[index],
				"Hand card %d is pickable at %s" % [index + 1, window_size])
		_expect(table.pick_actor(_screen_point(table.end_button, Vector3(0, 0.18, 0))) == table.end_button,
			"Physical end-turn control is pickable at %s" % window_size)
		_expect(table.pick_actor(_screen_point(table.end_button, Vector3(0, .05, .70))) == table.end_button,
			"Engraved end-turn plate is pickable at %s" % window_size)

	# A legal maximum hand must still expose every card's clickable surface.
	_game.match_state._hand.assign(["scout", "striker", "guard", "bolt", "heavy", "medic", "patch", "scout"])
	_game._shown = _game.match_state.snapshot()
	_game._refresh()
	await _settle()
	await _reveal_hand()
	for index in table.hand_cards.size():
		var actor: Node3D = table.hand_cards[index]
		var exposed := false
		for local_point in [Vector3.ZERO, Vector3(0, 0.02, -0.43), Vector3(-0.32, 0.02, -0.43), Vector3(0.32, 0.02, -0.43)]:
			if _inside_play_area(_screen_point(actor, local_point)) and table.pick_actor(_screen_point(actor, local_point)) == actor:
				exposed = true
		_expect(exposed, "Full-hand card %d has an exposed clickable area in the portrait window" % (index + 1))
	_game._start_match()
	root.size = Vector2i(1280, 720)
	await _settle()
	await _reveal_hand()
	await _mouse_click(_screen_point(table.hand_cards[0]))
	_expect(_game._selected == 0, "Real mouse event routing selects once despite touch emulation")
	_expect(not table.hand.expanded, "Selecting a card automatically tucks the hand for targeting")
	await _tuck_hand()
	await _reveal_hand()
	await _mouse_click(_screen_point(table.hand_cards[0]))
	_expect(_game._selected == -1, "A second real mouse click deselects exactly once")
	await _tuck_hand()
	_expect(not table.hand.expanded, "Moving back toward the board tucks the hand")
	await _touch_tap(table.size * Vector2(0.5, 0.95))
	await _hand_settled()
	_expect(table.hand.expanded and _game._selected == -1, "First bottom-edge touch reveals the hand without playing a card")
	await _touch_tap(_screen_point(table.hand_cards[0]))
	_expect(_game._selected == 0, "Real touch routing selects once despite mouse emulation")
	await _touch_tap(table.size * Vector2(0.5, 0.95))
	await _hand_settled()
	await _touch_tap(_screen_point(table.hand_cards[0]))
	_expect(_game._selected == -1, "A second touch tap deselects exactly once")
	var before: Dictionary = _game.match_state.snapshot()
	await _tuck_hand()
	await _reveal_hand()
	await _mouse_click(_screen_point(table.hand_cards[0]))
	_expect(_game._selected == 0, "Ray-based hand click selects the intended card")
	await _mouse_click(_screen_point(table.enemy_slots[0]))
	_expect(_game.match_state.snapshot() == before, "Spatial wrong-side click does not spend a card")

	# Go straight from the raised hand to a friendly lane, without first moving
	# across the enemy row. The retracting hand must not intercept the target click.
	_game._start_match()
	await _tuck_hand()
	await _reveal_hand()
	var previous_speed := Engine.time_scale
	Engine.time_scale = 1.0
	_mouse_press(_screen_point(table.hand_cards[0]))
	await process_frame
	_expect(_game._selected == 0 and not table.hand.expanded,
		"Direct deployment selects a card and immediately retracts the hand")
	_expect(table.pick_actor(_screen_point(table.player_slots[0])) == table.player_slots[0],
		"Retracting hand leaves the friendly lane center clickable")
	_mouse_press(_screen_point(table.player_slots[0]))
	await process_frame
	Engine.time_scale = previous_speed
	_expect(_game._busy, "Direct hand-to-friendly-lane click starts deployment")
	var after_play: Dictionary = _game.match_state.snapshot()
	table.activate_at(_screen_point(table.end_button, Vector3(0, 0.18, 0)))
	_expect(_game.match_state.snapshot() == after_play, "Busy animation blocks physical end-turn clicks")
	await _idle()
	_expect(_game._shown.player[0].get("id", "") == "scout", "Spatial targeting deploys Scout in the selected lane")
	_expect(table.pick_actor(_screen_point(table.player_slots[0])) == table.player_slots[0],
		"Occupied card remains pickable after deployment animation")
	await _mouse_click(_screen_point(table.end_button, Vector3(0, .05, .70)))
	await _idle()
	_expect(_game._shown.turn == 2, "Physical end-turn control advances the match")
	_expect(_game._shown.enemy[1].get("id", "") == "guard", "Telegraphed enemy appears on the 3D table")

	_game._start_match()
	await _tuck_hand()
	await _touch_tap(table.size * Vector2(0.5, 0.95))
	await _hand_settled()
	await _touch_tap(_screen_point(table.hand_cards[0]))
	_expect(_game._selected == 0 and not table.hand.expanded,
		"Touch selection tucks the hand before choosing a target")
	await _touch_tap(_screen_point(table.player_slots[0]))
	await _idle()
	_expect(_game._shown.player[0].get("id", "") == "scout",
		"Touch can deploy directly from a hand card to a friendly lane")
	_game.finish({"won": false, "quit": true})
	await process_frame
	_expect(_returned and not paused, "Leaving the spatial playtest restores the hub")
	room.queue_free()
	await process_frame
	print("Card table input: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _launch() -> void:
	await _games.play("cards")
	_returned = true


func _screen_point(actor: Node3D, offset: Vector3 = Vector3.ZERO) -> Vector2:
	# Independently project a world-space actor point into the resized UI surface.
	var table: Node = _game.table
	var viewport_point: Vector2 = table.camera.unproject_position(actor.to_global(offset))
	return viewport_point * table.size / Vector2(table.viewport.size)


func _inside_play_area(point: Vector2) -> bool:
	return Rect2(Vector2(0, 90), _game.table.size - Vector2(0, 138)).has_point(point)


func _move_pointer(point: Vector2) -> void:
	# parse_input_event enters at window coordinates, before canvas_items scaling.
	point = root.get_final_transform() * point
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)


func _reveal_hand() -> void:
	_move_pointer(_game.table.size * Vector2(0.5, 0.92))
	await _hand_settled()


func _tuck_hand() -> void:
	_move_pointer(_game.table.size * Vector2(0.5, 0.40))
	await _hand_settled()


func _hand_settled() -> void:
	for frame in 600:
		await process_frame
		if _game.table.hand.is_settled():
			await _settle()
			return
	_expect(false, "Hand reveal or tuck completes within timeout")


func _entry_complete() -> void:
	for frame in 1200:
		if not _game._entering:
			return
		await process_frame
	_expect(false, "Table entrance completes within timeout")


func _mouse_press(point: Vector2) -> void:
	_move_pointer(point)
	point = root.get_final_transform() * point
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		click.pressed = down
		Input.parse_input_event(click)


func _mouse_click(point: Vector2) -> void:
	_mouse_press(point)
	await _settle()


func _touch_tap(point: Vector2) -> void:
	point = root.get_final_transform() * point
	for down in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = point
		touch.pressed = down
		Input.parse_input_event(touch)
	await _settle()


func _settle() -> void:
	for frame in 4:
		await physics_frame
		await process_frame


func _idle() -> void:
	for frame in 2400:
		if not _game._busy:
			await _settle()
			return
		await process_frame
	_expect(false, "Table animation completes within timeout")
