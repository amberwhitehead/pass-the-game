extends "res://tests/test_suite.gd"
## Controls through the real pause menu, with real key and mouse events: opening from the
## hall and a minigame, keyboard navigation, capture (ignoring the opening Enter, repeats
## and held keys), conflicts naming the other action, Escape cancelling, Use Escape,
## discard and restore-defaults confirmations, Apply changing play after resume without
## leaking input, saved preferences (missing, corrupt, invalid, failing to save) and hints.

const KeyBindings := preload("res://autoload/key_bindings.gd")
const TEST_PATH := "user://test_controls.cfg"
var _checks := 0
var _failures := 0
var _menu: CanvasLayer
var _controls: CanvasLayer
var _room: Node3D
var _player: Player
var _games: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	KeyBindings.path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	_menu = root.get_node("PauseMenu")
	_controls = _menu.controls
	_games = root.get_node("MiniGames")
	root.get_node("Game").set_flag("room_visited")
	_room = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	_player = _room.get_node("Player")
	await _frames(5)
	await _open_from_hall()
	await _capture_rules()
	await _discard()
	await _apply_and_play()
	await _use_escape_and_defaults()
	await _from_minigame()
	await _hints_follow_bindings()
	_saved_files()
	await _save_failure()
	KeyBindings.apply(KeyBindings.defaults())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("Controls menu: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _open_from_hall() -> void:
	await _tap(KEY_ESCAPE)
	_expect(_menu.is_open() and paused, "Escape pauses the hall")
	_expect(_menu.controls_button.visible, "The pause menu offers Controls")
	await _click(_menu.controls_button)
	_expect(_controls.is_open(), "Clicking Controls opens it")
	_expect(_row("move_up", 0).key.text == "W" and _row("move_up", 1).key.text == "Up",
		"Walk forward shows both of its keys, W and Up")
	_expect(_row("interact", 0).key.text == "E" and _row("interact", 1).key.text == "Enter" and _row("interact", 2).key.text == "F",
		"Interact shows E, Enter and F")
	_expect(_row("back", 0).key.text == "Escape" and _row("back", 1).key.text == "Backspace",
		"Back / pause shows Escape and Backspace")
	_expect(_focus() == _row("move_up", 0).change, "Focus starts on the first Change button")
	await _tap(KEY_DOWN)
	_expect(_focus() != _row("move_up", 0).change and _focus() is Button, "Arrow keys move focus between controls")
	await _tap(KEY_UP)
	_expect(_focus() == _row("move_up", 0).change, "Arrow keys move focus back")


func _capture_rules() -> void:
	await _tap(KEY_ENTER)  # Enter presses the focused Change; its own release must be ignored.
	_expect(_controls.is_capturing() and _row("move_up", 0).key.text == "Press a key…",
		"Enter on Change shows a visible Press a key state")
	_expect(_menu.is_open() and _controls.is_open(), "The Enter that opened capture changed nothing else")
	await _key(KEY_H, true, true)  # A repeat is not a fresh press.
	await _key(KEY_H, false)
	_expect(_controls.is_capturing(), "Key repeat is ignored")
	await _tap(KEY_S)
	_expect(_controls.is_capturing() and "Walk back" in _controls.message.text,
		"A key used elsewhere names that action and keeps waiting")
	_expect(_controls._draft.move_up[0] == KEY_W and _controls._draft.move_down[0] == KEY_S,
		"A conflict changes no binding")
	await _tap(KEY_ESCAPE)
	_expect(not _controls.is_capturing() and _controls.is_open() and _menu.is_open(),
		"Escape cancels capture without closing Controls or the pause menu")
	_expect(_controls._draft.move_up[0] == KEY_W and _focus() == _row("move_up", 0).change,
		"Cancel keeps the key and returns focus to its Change button")
	await _click(_row("move_up", 0).change)
	await _tap(KEY_W)
	_expect(not _controls.is_capturing() and _controls._draft.move_up[0] == KEY_W and not _controls.has_unapplied_changes(),
		"Choosing the same key is harmless")
	await _click(_row("move_up", 0).change)
	await _tap(KEY_K)
	_expect(_controls._draft.move_up[0] == KEY_K and InputMap.action_get_events("move_up").size() > 0,
		"A free key is accepted into the draft")
	_expect(_has_key("move_up", KEY_W) and not _has_key("move_up", KEY_K), "Nothing applies before Apply")


func _discard() -> void:
	await _click(_controls.back_button)
	_expect(_controls.is_open() and _controls.back_button.text == "Discard changes?",
		"Back with unapplied edits asks first")
	await _tap(KEY_ESCAPE)
	_expect(not _controls.is_open() and _menu.is_open(), "Confirming discard returns to the pause menu, not the game")
	_expect(_focus() == _menu.controls_button, "Focus returns to the Controls button")
	_expect(_has_key("move_up", KEY_W) and not _has_key("move_up", KEY_K), "Discarded edits never applied")


func _apply_and_play() -> void:
	var yaw := _player.rotation.y
	var pitch := _player.camera.rotation.x
	await _click(_menu.controls_button)
	await _click(_row("move_up", 0).change)
	await _tap(KEY_K)
	await _click(_row("jump", 0).change)
	await _tap(KEY_SPACE)
	_expect(not _controls.is_capturing() and _controls._draft.jump[0] == KEY_SPACE, "Space on jump is the same key")
	await _click(_row("jump", 0).change)
	await _tap(KEY_J)
	await _click(_controls.apply_button)
	_expect(_has_key("move_up", KEY_K) and not _has_key("move_up", KEY_W) and _has_key("move_up", KEY_UP),
		"Apply makes K walk forward, keeps Up, and drops W")
	_expect(_has_key("jump", KEY_J) and not _has_key("jump", KEY_SPACE), "Apply makes J jump instead of Space")
	_expect(_pad_events("move_up") == 2 and _pad_events("interact") == 1 and is_equal_approx(InputMap.action_get_deadzone("move_up"), 0.2),
		"Gamepad events and deadzones survive the rebinding")
	_expect("saved" in _controls.message.text and FileAccess.file_exists(TEST_PATH), "Apply reports a real save")
	await _click(_controls.back_button)
	_expect(not _controls.is_open() and _menu.is_open(), "Back after Apply returns to pause")
	# Hold the new jump key and walk key through Resume: neither may act until released.
	await _key(KEY_J, true)
	await _key(KEY_K, true)
	var start := _player.position
	await _click(_menu.resume_button)
	_expect(not _menu.is_open() and not paused, "Resume closes the menu")
	await _physics(20)
	_expect(_player.position.distance_to(start) < 0.01 and _player.is_on_floor(),
		"Keys held through Resume do not walk or jump")
	_expect(is_equal_approx(_player.rotation.y, yaw) and is_equal_approx(_player.camera.rotation.x, pitch),
		"Menus, clicks and capture never turned the view")
	await _key(KEY_J, false)
	await _key(KEY_K, false)
	await _key(KEY_K, true)
	await _physics(15)
	await _key(KEY_K, false)
	_expect(_player.position.distance_to(start) > 0.3, "A fresh press of the new forward key walks")
	start = _player.position
	await _key(KEY_W, true)
	await _physics(15)
	await _key(KEY_W, false)
	_expect(_player.position.distance_to(start) < 0.01, "The replaced W key no longer walks")
	await _key(KEY_SPACE, true)
	await _physics(6)
	await _key(KEY_SPACE, false)
	_expect(_player.is_on_floor() and _player.velocity.y <= 0.0, "Space no longer jumps")
	await _key(KEY_J, true)
	await _physics(3)
	await _key(KEY_J, false)
	_expect(_player.velocity.y > 0.0 or not _player.is_on_floor(), "J now jumps")
	await _physics(50)
	_expect(_room.hud._prompt != null and KeyBindings.label("move_up") == "K",
		"Hints read the new key from the bindings")
	_expect("K" in _player.mouse_capture._hint_text() and "J jumps" in _player.mouse_capture._hint_text(),
		"The click-to-look card lists the new keys")


func _use_escape_and_defaults() -> void:
	await _tap(KEY_ESCAPE)
	await _click(_menu.controls_button)
	await _click(_row("back", 0).change)
	await _tap(KEY_Q)
	_expect(_controls._draft.back[0] == KEY_Q, "Back / pause accepts a new key")
	await _click(_row("back", 0).escape)
	_expect(_controls._draft.back[0] == KEY_ESCAPE and not _controls.is_capturing(), "Use Escape restores Escape directly")
	await _click(_row("back", 1).escape)
	_expect(_controls._draft.back[1] == KEY_BACKSPACE and "Back / pause" in _controls.message.text,
		"Use Escape on the other slot is refused, naming the action")
	await _click(_controls.defaults_button)
	_expect(_controls.defaults_button.text != "Restore defaults" and _controls._draft.jump[0] == KEY_J,
		"Restore defaults asks for confirmation first")
	await _click(_controls.defaults_button)
	_expect(_controls._draft == KeyBindings.defaults(), "Confirming restores every default in the draft")
	await _click(_controls.apply_button)
	_expect(_has_key("move_up", KEY_W) and _has_key("jump", KEY_SPACE) and not _has_key("jump", KEY_J),
		"Applied defaults are live again")
	await _click(_controls.back_button)
	await _tap(KEY_ESCAPE)
	_expect(not _menu.is_open(), "Escape still resumes from the pause menu")


func _from_minigame() -> void:
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
	_expect(_menu.is_open() and puzzle.process_mode == Node.PROCESS_MODE_DISABLED, "Escape pauses the minigame")
	await _click(_menu.controls_button)
	_expect(_controls.is_open(), "Controls opens from the minigame pause menu")
	await _tap(KEY_ESCAPE)
	_expect(not _controls.is_open() and _menu.is_open() and _games.current == puzzle,
		"Leaving Controls keeps the minigame paused under the menu")
	await _click(_menu.leave_button)
	for frame in 300:
		if returned[0]:
			break
		await process_frame
	await _frames(2)
	_expect(_games.current == null and not _menu.is_open(), "Leave still exits the minigame")


## Rebind inside a paused puzzle through the menu; every prompt then names the new keys.
func _hints_follow_bindings() -> void:
	var returned := [false]
	var launch := func():
		await _games.play("newton")
		returned[0] = true
	launch.call_deferred()
	for frame in 600:
		if _games.current != null:
			break
		await process_frame
	await _frames(5)
	var puzzle: Node = _games.current
	var hint: Label = puzzle._hud.hint
	_expect("A D" in hint.text or "E / Enter" in hint.text, "The puzzle hint starts with the default keys (%s)" % hint.text)
	await _tap(KEY_ESCAPE)
	await _click(_menu.controls_button)
	await _click(_row("strafe_left", 0).change)
	await _tap(KEY_J)
	await _click(_row("interact", 0).change)
	await _tap(KEY_G)
	await _click(_row("back", 0).change)
	await _tap(KEY_Q)
	await _click(_controls.apply_button)
	await _click(_controls.back_button)
	await _click(_menu.resume_button)
	await _frames(3)
	_expect(("J D" in hint.text or "G / Enter" in hint.text) and not "A D" in hint.text and not "E / Enter" in hint.text,
		"The puzzle hint names the new keys after resuming (%s)" % hint.text)
	puzzle._hud.set_hint("Aligned!   {continue} to continue")
	_expect(hint.text == "Aligned!   G / Enter or Q to continue", "Puzzle continue prompt uses the new keys (%s)" % hint.text)
	puzzle._hud.set_hint("{steer} walk   {reach} reach")
	_expect(hint.text == "J D walk   W S reach", "Puzzle movement prompt uses the current keys (%s)" % hint.text)
	var close: Button = null
	for child in puzzle.get_children():
		if child is Button and child.text == "×":
			close = child
	close.mouse_entered.emit()
	_expect(close.tooltip_text.begins_with("Leave · Q (keyboard)"), "The puzzle close tooltip names the new Back key")
	var rules: String = load("res://minigames/cards/encounter_text.gd").rules(false)
	_expect("Q cancels a selected card" in rules and not "Esc cancels" in rules, "Card table rules name the new Back key")
	var sheet: PanelContainer = load("res://ui/conversation_sheet.gd").new()
	root.add_child(sheet)
	sheet.arrive()
	var pad_in := not Input.get_connected_joypads().is_empty()  # This machine may have a pad plugged in.
	_expect((sheet.glyph.visible and sheet.hint.text.strip_edges() == "CONTINUE") if pad_in else sheet.hint.text == "CLICK  /  CONTINUE",
		"Dialogue shows the pad's R1, or says click, to continue (%s)" % sheet.hint.text)
	sheet.queue_free()
	_expect("J" in _player.mouse_capture._hint_text() and "Q for the menu" in _player.mouse_capture._hint_text(),
		"The click-to-look card names the new keys")
	puzzle.finish({"won": false, "quit": true})
	for frame in 300:
		if returned[0]:
			break
		await process_frame
	KeyBindings.apply(KeyBindings.defaults())
	await _frames(2)


func _saved_files() -> void:
	var file := ProjectSettings.globalize_path(TEST_PATH)
	var custom := KeyBindings.defaults()
	custom.move_up = [KEY_K, KEY_UP]
	_expect(KeyBindings.save(custom) == OK and KeyBindings.load_saved().move_up == [KEY_K, KEY_UP],
		"Saved bindings load back")
	DirAccess.remove_absolute(file)
	_expect(KeyBindings.load_saved() == KeyBindings.defaults(), "A missing file means defaults")
	_write("this is [not a config")
	_expect(KeyBindings.load_saved() == KeyBindings.defaults() and FileAccess.get_file_as_string(TEST_PATH) == "this is [not a config",
		"A corrupt file falls back to defaults and is left untouched")
	_write("[meta]\nformat=1\n[keyboard]\nmove_up=[75]\n")
	_expect(KeyBindings.load_saved() == KeyBindings.defaults(), "A wrong key count falls back to defaults")
	_write("[meta]\nformat=1\n[keyboard]\njump=[\"space\"]\n")
	_expect(KeyBindings.load_saved() == KeyBindings.defaults(), "A non-key value falls back to defaults")
	_write("[meta]\nformat=1\n[keyboard]\njump=[%d]\n" % KEY_W)
	_expect(KeyBindings.load_saved() == KeyBindings.defaults(), "A saved conflict falls back to defaults")
	_write("[keyboard]\njump=[%d]\n" % KEY_J)
	_expect(KeyBindings.load_saved() == KeyBindings.defaults(), "An unknown format falls back to defaults")


func _save_failure() -> void:
	KeyBindings.path = "user://no_such_folder/deeper/controls.cfg"
	await _tap(KEY_ESCAPE)
	await _click(_menu.controls_button)
	await _click(_row("jump", 0).change)
	await _tap(KEY_J)
	await _click(_controls.apply_button)
	_expect("could not be saved" in _controls.message.text and not "Applied and saved" in _controls.message.text,
		"A failed save says so instead of claiming success")
	KeyBindings.path = TEST_PATH
	_menu.close()
	KeyBindings.apply(KeyBindings.defaults())
	await _frames(2)


func _write(text: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _row(action: String, slot: int) -> Dictionary:
	return _controls._rows[action][slot]


func _has_key(action: String, key: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == key:
			return true
	return false


func _pad_events(action: String) -> int:
	var count := 0
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			count += 1
	return count


func _focus() -> Control:
	return root.gui_get_focus_owner()


func _key(key: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	await _frames(2)


func _tap(key: Key) -> void:
	await _key(key, true)
	await _key(key, false)


func _click(button: Control) -> void:
	var scroll := button.get_parent()
	while scroll != null and scroll is not ScrollContainer:
		scroll = scroll.get_parent()
	if scroll != null:  # A player scrolls to a row before clicking it.
		(scroll as ScrollContainer).ensure_control_visible(button)
		await _frames(2)
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


func _physics(count: int) -> void:
	for tick in count:
		await physics_frame


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
