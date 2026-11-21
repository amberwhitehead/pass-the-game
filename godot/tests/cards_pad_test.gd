extends "res://tests/test_suite.gd"
## The card tables on a controller, through the real input path from a pad in slot 2
## (Chrome put a DualSense there): A presses the rules dialog's button, the D-pad wakes
## the focus in the hand, A selects a card and jumps to its target, A plays it, B cancels
## a selection, X (Square) rings the bell, Options opens the rules, moving the mouse hands back control,
## and Older Brother's four lanes plus the bell are all reachable.

const ROOM_PATH := "res://scenes/room/room.tscn"
const Pad := preload("res://minigames/cards/table_pad.gd")
const PAD := 2
var _checks := 0
var _failures := 0
var _games: Node
var _returned := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.time_scale = 12.0
	Engine.max_fps = 120
	_games = root.get_node("MiniGames")
	root.get_node("Game").set_flag("room_visited")
	var room: Node = load(ROOM_PATH).instantiate()
	root.add_child(room)
	current_scene = room
	await _little_brother()
	await _older_brother()
	room.queue_free()
	await process_frame
	print("Cards pad: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _little_brother() -> void:
	var game: Node = await _open("cards")
	if game == null:
		return
	var table: Control = game.table
	_expect(is_instance_valid(game._dialog), "The rules open first")
	await _press(JOY_BUTTON_A)
	_expect(not is_instance_valid(game._dialog), "A presses the rules dialog's button")

	await _press(JOY_BUTTON_DPAD_DOWN)
	_expect(table.pad_active, "A D-pad press hands the table to the controller")
	_expect(game.pad.row == Pad.HAND and table._hovered == table.hand_cards[0], "Focus starts on the first card in the hand")
	_expect(table.hand.expanded, "Focusing the hand raises it")
	_expect(table.hud.inspector.visible, "The focused card is shown in the inspector")

	await _press(JOY_BUTTON_A)
	_expect(game._selected == 0, "A selects the focused card")
	_expect(game.pad.row == Pad.PLAYER and game.pad.index == 0, "...and the focus jumps to its first legal lane")
	await _press(JOY_BUTTON_A)
	await _idle(game)
	_expect(game._shown.player[0].get("id", "") == "scout", "A plays Scout into lane one")
	await process_frame
	_expect(game.pad.row == Pad.HAND, "After the play the focus goes back to the hand")

	await _press(JOY_BUTTON_A)
	_expect(game._selected >= 0, "Another card selected")
	await _press(JOY_BUTTON_B)
	_expect(game._selected == -1 and _games.current == game and not root.get_node("PauseMenu").is_open(),
		"B cancels a selected card rather than opening the menu")

	await _press(JOY_BUTTON_DPAD_UP)
	_expect(game.pad.row == Pad.PLAYER, "Up from the hand reaches your lanes")
	for i in 4:
		await _press(JOY_BUTTON_DPAD_RIGHT)
	_expect(table._hovered == table.end_button, "Right along your lanes ends at the bell")
	await _press(JOY_BUTTON_DPAD_UP)
	_expect(game.pad.row == Pad.ENEMY and game.pad.index == table.lane_count - 1, "Up from the bell reaches his last lane")

	var turn: int = game._shown.turn
	await _press(JOY_BUTTON_X)
	await _idle(game)
	_expect(int(game._shown.turn) == turn + 1, "X rings the bell and the turn resolves")

	await _press(JOY_BUTTON_START)
	_expect(is_instance_valid(game._dialog), "Options opens the rules")
	await _press(JOY_BUTTON_B)
	_expect(not is_instance_valid(game._dialog), "B closes them")

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(10, 10)
	motion.relative = Vector2(30, 0)
	Input.parse_input_event(motion)
	await process_frame
	_expect(not table.pad_active, "Moving the mouse hands the table back to it")
	await _leave(game)


func _older_brother() -> void:
	var game: Node = await _open("cards_older")
	if game == null:
		return
	var table: Control = game.table
	await _press(JOY_BUTTON_A)
	_expect(not is_instance_valid(game._dialog), "A dismisses Older Brother's rules")
	await _press(JOY_BUTTON_DPAD_UP)
	_expect(table.pad_active and table.lane_count == 4, "Older Brother's table has four lanes")
	await _press(JOY_BUTTON_DPAD_UP)
	for i in 6:
		await _press(JOY_BUTTON_DPAD_RIGHT)
	_expect(table._hovered == table.end_button, "His bell is reachable past the fourth lane")
	await _leave(game)


func _open(id: String) -> Node:
	_returned = false
	_launch.call_deferred(id)
	for frame in 600:
		if _games.current != null:
			break
		await process_frame
	var game: Node = _games.current
	if game == null:
		_expect(false, "%s opens" % id)
		return null
	for frame in 1200:
		if not game._entering:
			break
		await process_frame
	_expect(not game._entering, "%s's entrance finishes" % id)
	await process_frame
	return game


func _launch(id: String) -> void:
	await _games.play(id)
	_returned = true


func _leave(game: Node) -> void:
	game.finish({"won": false, "quit": true})
	for frame in 600:
		if _returned:
			break
		await process_frame
	await process_frame


func _press(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = PAD
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame


func _idle(game: Node) -> void:
	await process_frame
	for frame in 3600:
		if not game._busy:
			return
		await process_frame
	_expect(false, "The table finishes animating")


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
