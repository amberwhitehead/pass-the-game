extends "res://tests/test_suite.gd"
## Circle (pad B) gets you out of every minigame, from a controller in a later slot than
## 0 (Chrome put a DualSense in slot 2): B opens the pause menu, the D-pad reaches Leave,
## Cross presses it, and the player is back in the hall. Also: B in the menu resumes.

const PAD := 2

var _checks := 0
var _failures := 0
var _games: Node
var _menu: CanvasLayer
var _returned := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.time_scale = 4.0
	root.size = Vector2i(1280, 720)
	_games = root.get_node("MiniGames")
	_menu = root.get_node("PauseMenu")
	for id: String in _games.REGISTRY:
		await _check(id)
	Engine.time_scale = 1.0
	print("Pad back: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _check(id: String) -> void:
	_returned = false
	_launch.call_deferred(id)
	for frame in 600:
		if _games.current != null and not _games._launching:
			break
		await process_frame
	# Wait until the player is seated: during a card table's walk-up, B cancels it.
	for frame in 600:
		if _games.current == null or not _games.current.get("_entering"):
			break
		await process_frame
	for frame in 30:
		await process_frame
	if not _expect(_games.current != null, "%s opens" % id):
		return
	# B first closes whatever is open (a card table opens on its rules), then the menu.
	var presses := 0
	while presses < 3 and not _menu.is_open() and _games.current != null:
		await _button(JOY_BUTTON_B)
		presses += 1
	if not _expect(_menu.is_open(), "Circle opens the pause menu in %s" % id):
		if _games.current != null:
			_games.current.finish({"won": false, "quit": true})
		await _until_returned()
		return
	await _button(JOY_BUTTON_B)
	_expect(not _menu.is_open() and _games.current != null, "Circle again resumes %s" % id)
	await _button(JOY_BUTTON_B)
	# Walk the focus to Leave with the D-pad, then press Cross.
	for step in 8:
		if _menu.leave_button.has_focus():
			break
		await _button(JOY_BUTTON_DPAD_DOWN)
	_expect(_menu.leave_button.has_focus(), "The D-pad reaches Leave in %s" % id)
	await _button(JOY_BUTTON_A)
	await _until_returned()
	_expect(_returned and _games.current == null and not _menu.is_open(), "Cross on Leave returns to the hall from %s" % id)


func _launch(id: String) -> void:
	await _games.play(id)
	_returned = true


func _until_returned() -> void:
	for frame in 600:
		if _returned:
			break
		await process_frame
	for frame in 3:
		await process_frame


func _button(button: JoyButton) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = PAD
		ev.button_index = button
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
		await process_frame


func _expect(ok: bool, description: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(description)
	return ok
