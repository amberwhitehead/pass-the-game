extends "res://tests/test_suite.gd"
## Credits through the real menus with real key and mouse events: from the title screen
## and from the hall and minigame pause menus, scrolling, Back and Escape returning to the
## menu that opened it, the game staying paused, and the maintenance note in the source.

const MAINTENANCE := "For future contributors and AI coding agents: when adding a contribution to these"
var _checks := 0
var _failures := 0
var _menu: CanvasLayer
var _games: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_menu = root.get_node("PauseMenu")
	_games = root.get_node("MiniGames")
	_source()
	await _from_title()
	await _from_hall_and_minigame()
	print("Credits: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _source() -> void:
	var source := FileAccess.get_file_as_string("res://ui/credits.gd")
	_expect(MAINTENANCE in source and "do not guess their" in source and "identity or credit preference." in source,
		"The credits source carries the maintenance note for future contributors")
	var page: String = load("res://ui/credits_screen.gd").page()
	for name in ["Amber Whitehead", "rmurrish", "cee.wtf", "tesseract", "Steve Likes Robots", "Patrick Doane", "Kenney", "Libre Baskerville", "DejaVu Sans", "Godot Engine"]:
		_expect(name in page, "Credits name %s" % name)
	_expect("CC0" in page and "SIL Open Font License" in page and "MIT License" in page, "Credits name each license")
	for notice in ["res://assets/audio/cc0/licenses/casino.txt", "res://assets/fonts/LibreBaskerville-LICENSE.txt",
			"res://assets/fonts/DejaVu-LICENSE.txt"]:
		_expect(FileAccess.file_exists(notice), "The license notice %s is still there" % notice)


func _from_title() -> void:
	var title: Control = load("res://scenes/title/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await _frames(3)
	var credits: CanvasLayer = title.credits
	_expect(title.credits_button.visible and title.credits_button.get_index() == title.sound_button.get_index() + 1,
		"The title screen lists Credits after Sound")
	await _click(title.credits_button)
	_expect(credits.is_open() and _focus() == credits.text, "Clicking Credits opens it with the page focused")
	var bar: VScrollBar = credits.text.get_v_scroll_bar()
	if bar.max_value > bar.page + 1.0:
		await _tap(KEY_PAGEDOWN)
		_expect(bar.value > 0.0, "Page Down scrolls the credits")
		await _tap(KEY_HOME)
	else:
		_expect(true, "The credits fit without scrolling")
	await _tap(KEY_TAB)
	_expect(_focus() == credits.back_button, "Tab moves focus to Back")
	await _tap(KEY_ENTER)
	_expect(not credits.is_open() and _focus() == title.credits_button, "Enter on Back returns to the title menu")
	await _click(title.credits_button)
	await _tap(KEY_ESCAPE)
	_expect(not credits.is_open() and title._menu.visible and not title._slots.visible,
		"Escape closes Credits and leaves the title menu as it was")
	title.queue_free()
	current_scene = null
	await _frames(2)


func _from_hall_and_minigame() -> void:
	root.get_node("Game").set_flag("room_visited")
	var room: Node3D = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	var player: Player = room.get_node("Player")
	await _frames(5)
	var yaw := player.rotation.y
	await _tap(KEY_ESCAPE)
	_expect(_menu.is_open() and paused, "Escape pauses the hall")
	_expect(_menu.credits_button.visible, "The pause menu lists Credits")
	await _click(_menu.credits_button)
	_expect(_menu.credits.is_open() and paused, "Credits opens over the paused hall")
	await _frames(5)
	_expect(paused and _menu.is_open(), "The hall stays paused while Credits is open")
	await _click(_menu.credits.back_button)
	_expect(not _menu.credits.is_open() and _menu.is_open() and paused and _focus() == _menu.credits_button,
		"Back returns to the pause menu, still paused, with focus on Credits")
	await _click(_menu.credits_button)
	await _tap(KEY_ESCAPE)
	_expect(not _menu.credits.is_open() and _menu.is_open() and paused, "Escape in Credits only closes Credits")
	await _tap(KEY_ESCAPE)
	_expect(not _menu.is_open() and not paused, "Escape then resumes as before")
	_expect(is_equal_approx(player.rotation.y, yaw), "The view did not turn")
	var returned := [false]
	var launch := func():
		await _games.play("newton")
		returned[0] = true
	launch.call_deferred()
	for frame in 600:
		if _games.current != null:
			break
		await process_frame
	await _frames(3)
	var puzzle: Node = _games.current
	await _tap(KEY_ESCAPE)
	await _click(_menu.credits_button)
	_expect(_menu.credits.is_open() and puzzle.process_mode == Node.PROCESS_MODE_DISABLED,
		"Credits opens from the minigame pause menu with the puzzle frozen")
	await _tap(KEY_ESCAPE)
	_expect(not _menu.credits.is_open() and _menu.is_open() and _games.current == puzzle
		and puzzle.process_mode == Node.PROCESS_MODE_DISABLED, "Closing Credits keeps the puzzle paused under the menu")
	await _click(_menu.leave_button)
	for frame in 300:
		if returned[0]:
			break
		await process_frame
	await _frames(2)
	_expect(_games.current == null and not _menu.is_open(), "Leave still exits the minigame")
	room.queue_free()
	await _frames(2)


func _focus() -> Control:
	return root.gui_get_focus_owner()


func _tap(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _click(button: Control) -> void:
	var at := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _frames(count: int) -> void:
	for frame in count:
		await process_frame


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
