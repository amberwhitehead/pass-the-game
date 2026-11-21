extends "res://tests/test_suite.gd"
## Leaving mid-minigame keeps progress for the next visit, through the real launcher, the
## pause menu and the save file. Wins clear it. Roman Flow's GPU simulation stops while
## paused. Card matches resume by exact replay and refuse replays that no longer match.
const SaveGame := preload("res://autoload/save_game.gd")
const Catalog := preload("res://minigames/cards/card_catalog.gd")
var _checks := 0
var _failures := 0
var _games: Node
var _game: Node
var _menu: CanvasLayer
var _room: Node3D
var _result: Dictionary = {}
var _returned := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 120
	Engine.time_scale = 6.0
	root.size = Vector2i(1280, 720)
	_games = root.get_node("MiniGames")
	_game = root.get_node("Game")
	_menu = root.get_node("PauseMenu")
	SaveGame.slot_prefix = "user://test_resume_slot_"
	_game.new_game(0)
	_game.set_flag("room_visited")
	_room = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	await physics_frame
	await _egypt()
	await _roman()
	await _cards()
	await _interrupted()
	await _quit_from_minigame()
	SaveGame.erase(SaveGame.slot_path(0))
	_game.autosave = false
	print("Minigame resume: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _egypt() -> void:
	var puzzle: Node = await _open("newton")
	_set_value(puzzle, "re", 3.25)
	_set_value(puzzle, "rot", -45.0)
	puzzle._theta = 1.0
	await _leave_through_menu()
	var saved: Dictionary = _game.minigame_progress("newton")
	_expect(is_equal_approx(saved.get("values", {}).get("re", 0.0), 3.25), "Leaving Egypt keeps its roller values")
	_reload_save()
	puzzle = await _open("newton")
	_expect(is_equal_approx(puzzle._value("re"), 3.25) and is_equal_approx(puzzle._value("rot"), -45.0) \
		and is_equal_approx(puzzle._theta, 1.0), "Egypt reopens where it was left, even after reloading the save")
	puzzle._solved = true
	await _escape()
	await _until_returned()
	_expect(_result.get("won", false) and _game.minigame_progress("newton").is_empty(), "Winning clears Egypt's saved progress")
	puzzle = await _open("newton")
	_expect(is_equal_approx(puzzle._value("re"), 6.0), "After a win, Egypt starts fresh")
	await _leave_through_menu()


func _roman() -> void:
	var puzzle: Node = await _open("turing")
	_set_value(puzzle, "feed", 0.031)
	puzzle._add_piece(1, Vector2(0.5, 0.2), true)
	puzzle._held = puzzle._add_piece(0, Vector2(-0.4, 0.1), false)
	await _escape()
	_expect(_menu.is_open() and _sim_mode(puzzle) == SubViewport.UPDATE_DISABLED, "The pause menu stops Roman Flow's GPU simulation")
	await _escape()
	_expect(_sim_mode(puzzle) == SubViewport.UPDATE_ALWAYS, "Resuming restarts the simulation")
	await _leave_through_menu()
	var pins: Array = _game.minigame_progress("turing").get("pins", [])
	_expect(pins.size() == 1 and pins[0].kind == 1, "Placed pins are kept; a carried pin returns to its tray")
	_reload_save()
	puzzle = await _open("turing")
	var placed: Array = puzzle._pieces.filter(func(pc): return pc.placed)
	_expect(placed.size() == 1 and placed[0].kind == 1 and placed[0].pos.is_equal_approx(Vector2(0.5, 0.2)) \
		and is_equal_approx(puzzle._value("feed"), 0.031), "Roman Flow reopens with its rollers and pins")
	await _leave_through_menu()


func _cards() -> void:
	var table: Node = await _open("cards_older")
	await _settle(table)
	table._close_dialog()
	_play_any_creature(table)
	await _settle(table)
	table._end_turn()
	await _settle(table)
	var before: Dictionary = table.match_state.snapshot()
	_expect(before.turn == 2, "Card fixture reaches turn 2")
	await _leave_through_menu()
	_expect(not _game.minigame_progress("cards_older").is_empty(), "Leaving a card match keeps it")
	_game.collect_card("champion")  # A find after leaving must not change the saved match.
	_reload_save()
	table = await _open("cards_older")
	await _settle(table)
	_expect(table._resumed and table.match_state.snapshot() == before, "The card match resumes exactly, with its original deck")
	_expect(not is_instance_valid(table._dialog), "A resumed match skips the rules introduction")
	await _leave_through_menu()

	var progress: Dictionary = _game.minigame_progress("cards_older")
	progress.snapshot.balance += 1
	_game.set_minigame_progress("cards_older", progress)
	table = await _open("cards_older")
	await _settle(table)
	_expect(not table._resumed and table.match_state.snapshot().turn == 1, "A replay that no longer matches deals a fresh match")
	table._close_dialog()
	await _leave_through_menu()
	_expect(_game.minigame_progress("cards_older").is_empty(), "Leaving an untouched match keeps nothing")


## A page closed or reloaded mid-minigame gives no warning: progress is snapshotted every
## few seconds, the save remembers which minigame was open, and the next hall reopens it.
## The player's spot in the hall comes back too.
func _interrupted() -> void:
	var player: Node3D = _room.get_node("Player")
	player.position = Vector3(2.0, 0.0, 3.0)
	player.rotation.y = 1.0
	_room.resume.save_spot()
	var puzzle: Node = await _open("newton")
	_expect(_game.get_flag(_games.RESUME_FLAG, "") == "newton", "The save notes that Egypt is open")
	_set_value(puzzle, "re", 2.5)
	await create_timer(_games.CAPTURE_EVERY + 0.5).timeout
	_game.save_now()
	var on_disk: Dictionary = SaveGame.read(SaveGame.slot_path(0)).get("flags", {})
	_expect(on_disk.get(_games.RESUME_FLAG, "") == "newton" \
		and is_equal_approx(on_disk.get("minigame_progress", {}).get("newton", {}).get("values", {}).get("re", 0.0), 2.5),
		"Without leaving, the save already holds Egypt's progress and that it was open")
	await _leave_through_menu()
	_expect(_game.get_flag(_games.RESUME_FLAG, "") == "", "Leaving on purpose clears it")

	# What a reload finds: that save, loaded into a fresh hall.
	_game.set_flag(_games.RESUME_FLAG, "newton")
	_reload_save()
	_room.queue_free()
	_room = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	player = _room.get_node("Player")
	_expect(player.position.distance_to(Vector3(2.0, 0.0, 3.0)) < 0.01 and is_equal_approx(player.rotation.y, 1.0),
		"The hall puts the player back where they stood")
	_returned = false
	for frame in 600:
		if _games.current != null:
			break
		await process_frame
	_expect(_games.current != null and _games.current_title() == "Egypt Fractal", "...and reopens Egypt")
	if _games.current != null:
		_expect(is_equal_approx(_games.current._value("re"), 2.5), "...where it was")
		await _escape()
		_menu.leave_button.pressed.emit()
		for frame in 600:
			if _games.current == null:
				break
			await process_frame
		for frame in 3:
			await process_frame


func _quit_from_minigame() -> void:
	var puzzle: Node = await _open("newton")
	_set_value(puzzle, "a", 1.7)
	await _escape()
	_expect(_menu.quit_button.visible and _menu.leave_button.visible, "The minigame menu offers Leave and Quit to title")
	_menu.quit_button.pressed.emit()
	for frame in 300:
		if current_scene != null and current_scene.name == "Title":
			break
		await process_frame
	var saved: Dictionary = SaveGame.read(SaveGame.slot_path(0)).get("flags", {}).get("minigame_progress", {})
	_expect(current_scene != null and current_scene.name == "Title" and not paused, "Quit to title from a minigame reaches the title screen")
	_expect(is_equal_approx(saved.get("newton", {}).get("values", {}).get("a", 0.0), 1.7), "Quitting to title saves the minigame's progress")


func _set_value(puzzle: Node, id: String, value: float) -> void:
	for c in puzzle._controls:
		if c.id == id:
			c["value"] = value
	puzzle._apply_params()


func _sim_mode(puzzle: Node) -> int:
	return puzzle._stages[0].vp.render_target_update_mode


## Writes the save, forgets everything in memory, and loads it back.
func _reload_save() -> void:
	_game.save_now()
	_game.autosave = false
	_game.flags.clear()
	_game.completed_minigames.clear()
	_game.collected_cards.clear()
	_expect(_game.load_slot(0), "The save reloads")


func _play_any_creature(table: Node) -> void:
	var state: Dictionary = table.match_state.snapshot()
	for i in state.hand.size():
		var card: Dictionary = Catalog.get_card(state.hand[i])
		if card.kind != "unit" or card.cost > state.energy:
			continue
		for lane in state.player.size():
			if state.player[lane].is_empty():
				table._choose_card(i)
				table._choose_lane("player", lane)
				return
	_expect(false, "Card fixture finds a playable creature")


func _settle(table: Node) -> void:
	for frame in 2400:
		if not table._entering and not table._busy:
			return
		await process_frame
	_expect(false, "Card table settles")


func _open(id: String) -> Node:
	_returned = false
	_result = {}
	_launch.call_deferred(id)
	for frame in 600:
		if _games.current != null:
			await process_frame
			return _games.current
		await process_frame
	_expect(false, "%s opens" % id)
	return null


func _launch(id: String) -> void:
	_result = await _games.play(id)
	_returned = true


func _leave_through_menu() -> void:
	await _escape()
	_expect(_menu.is_open(), "Escape opens the menu in %s" % _games.current_title())
	_menu.leave_button.pressed.emit()
	await _until_returned()


func _until_returned() -> void:
	for frame in 600:
		if _returned:
			break
		await process_frame
	for frame in 3:
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
