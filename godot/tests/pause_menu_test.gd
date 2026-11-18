extends SceneTree
## The Escape menu through real input: hall pause, priority for existing back actions,
## minigame freeze/resume/leave, solved puzzles leaving directly, and quitting to title.
const SaveGame := preload("res://autoload/save_game.gd")
var _checks := 0
var _failures := 0
var _games: Node
var _game: Node
var _menu: CanvasLayer
var _touch: Node
var _room: Node3D
var _result: Dictionary = {}
var _returned := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 120
	Engine.time_scale = 4.0
	root.size = Vector2i(1280, 720)
	_games = root.get_node("MiniGames")
	_game = root.get_node("Game")
	_menu = root.get_node("PauseMenu")
	_touch = root.get_node("TouchControls")
	SaveGame.slot_prefix = "user://test_pause_slot_"
	_game.flags.clear()
	_game.completed_minigames.clear()
	_game.set_flag("room_visited")
	_room = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	await physics_frame
	await _hall()
	await _priority()
	await _minigame()
	await _solved_leaves()
	await _quit_to_title()
	SaveGame.erase(SaveGame.slot_path(0))
	print("Pause menu: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _hall() -> void:
	_expect(not _menu.is_open() and not paused, "The hall starts unpaused without a menu")
	await _escape()
	_expect(_menu.is_open() and paused, "Escape in the hall opens the menu and pauses the game")
	_expect(_menu.resume_button.has_focus(), "Resume has keyboard and gamepad focus")
	_expect(_menu.quit_button.visible and not _menu.leave_button.visible, "The hall menu offers Quit to title, not Leave")
	_expect(not _touch.is_enabled(), "The touch pad hides under the menu")
	await _escape()
	_expect(not _menu.is_open() and not paused and _touch.is_enabled(), "Escape again resumes and restores touch controls")
	await _escape()
	_menu.resume_button.pressed.emit()
	await process_frame
	_expect(not _menu.is_open() and not paused, "Resume closes the menu")


func _priority() -> void:
	_room.optics.begin_aim("S")
	_expect(not _room.optics.aiming.active_id.is_empty(), "Fixture holds the source wheel")
	await process_frame
	await _escape()
	_expect(_room.optics.aiming.active_id.is_empty() and not _menu.is_open(), "Escape releases a held wheel before any menu")
	_room.get_node("/root/Sound").settings_open = true
	await _escape()
	_expect(not _menu.is_open(), "Escape never opens the menu over Sound settings")
	_room.get_node("/root/Sound").settings_open = false


func _minigame() -> void:
	var puzzle: Node = await _open("newton")
	_expect(puzzle != null, "Egypt opens")
	await _escape()
	_expect(_menu.is_open() and puzzle.process_mode == Node.PROCESS_MODE_DISABLED, "Escape in a minigame opens the menu and freezes it")
	_expect(_menu.leave_button.visible and _menu.leave_button.text == "Leave Egypt Fractal" and not _menu.quit_button.visible,
		"The minigame menu offers to leave that minigame")
	_expect(_games.current == puzzle and not _returned, "Opening the menu does not leave the minigame")
	await _escape()
	_expect(not _menu.is_open() and puzzle.process_mode == Node.PROCESS_MODE_ALWAYS and _games.current == puzzle,
		"Escape again resumes the same minigame")
	await _escape()
	_menu.leave_button.pressed.emit()
	await _until_returned()
	_expect(_returned and _result.get("quit", false) and not _result.get("won", true), "Leave exits the minigame unsolved")
	_expect(not _menu.is_open() and _games.current == null and not paused, "Leaving returns to a running hall")


func _solved_leaves() -> void:
	var puzzle: Node = await _open("turing")
	puzzle._solved = true
	await _escape()
	await _until_returned()
	_expect(_returned and not _menu.is_open() and _result.get("won", false), "Escape on a solved puzzle leaves with the win, as its HUD says")


func _quit_to_title() -> void:
	_game.new_game(0)
	_game.set_flag("before_quit")
	await _escape()
	_menu.quit_button.pressed.emit()
	for frame in 300:
		if current_scene != null and current_scene.name == "Title":
			break
		await process_frame
	_expect(current_scene != null and current_scene.name == "Title", "Quit to title opens the title screen")
	_expect(not paused and not _menu.is_open(), "The title screen is not left paused")
	_expect(SaveGame.read(SaveGame.slot_path(0)).get("flags", {}).has("before_quit") and not _game.autosave,
		"Quitting saves progress first and stops autosave")


func _open(id: String) -> Node:
	_returned = false
	_result = {}
	_launch.call_deferred(id)
	for frame in 600:
		if _games.current != null:
			await process_frame
			return _games.current
		await process_frame
	return null


func _launch(id: String) -> void:
	_result = await _games.play(id)
	_returned = true


func _until_returned() -> void:
	for frame in 300:
		if _returned:
			break
		await process_frame
	await process_frame


func _escape() -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = "back"
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
