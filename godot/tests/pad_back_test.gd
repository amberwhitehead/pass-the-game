extends "res://tests/test_suite.gd"
## Every minigame on a controller in a later slot than 0 (Chrome put a DualSense in slot
## 2): Y (Triangle) opens the pause menu and closes it again, and B (Circle) closes
## whatever the game has open, then leaves straight to the hall like the × button.

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
	await _aliases()
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
	await _button(JOY_BUTTON_Y)
	_expect(_menu.is_open(), "Triangle opens the pause menu in %s" % id)
	await _button(JOY_BUTTON_Y)
	_expect(not _menu.is_open() and _games.current != null, "Triangle again closes it, still in %s" % id)
	# B first closes whatever is open (a card table opens on its rules), then leaves.
	var presses := 0
	while presses < 3 and _games.current != null:
		await _button(JOY_BUTTON_B)
		presses += 1
	await _until_returned()
	_expect(_returned and _games.current == null and not _menu.is_open(), "Circle leaves %s for the hall" % id)


## L1 and R2 act as A: each press arrives as an A press from the same pad.
func _aliases() -> void:
	var seen: Array = []
	var watch := func(ev: InputEvent):
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_A and ev.device == PAD:
			seen.append(ev.pressed)
	var probe := _Probe.new()
	probe.seen = watch
	root.add_child(probe)
	await _button(JOY_BUTTON_LEFT_SHOULDER)
	_expect(seen == [true, false], "L1 presses and releases A (%s)" % [seen])
	seen.clear()
	for v in [0.2, 0.7, 0.9, 0.5, 0.1]:  # A half press doesn't count; past 0.6 presses, under 0.3 releases.
		var m := InputEventJoypadMotion.new()
		m.device = PAD
		m.axis = JOY_AXIS_TRIGGER_RIGHT
		m.axis_value = v
		Input.parse_input_event(m)
		await process_frame
		await process_frame
	_expect(seen == [true, false], "R2 presses A once and releases it once (%s)" % [seen])
	probe.queue_free()
	var l1 := InputEventJoypadButton.new()
	l1.device = PAD
	l1.button_index = JOY_BUTTON_LEFT_SHOULDER
	l1.pressed = true
	var l2 := InputEventJoypadMotion.new()
	l2.device = PAD
	l2.axis = JOY_AXIS_TRIGGER_LEFT
	l2.axis_value = 1.0
	var r1 := InputEventJoypadButton.new()
	r1.device = PAD
	r1.button_index = JOY_BUTTON_RIGHT_SHOULDER
	r1.pressed = true
	_expect(r1.is_action("jump") and not l1.is_action("jump") and not l2.is_action("jump") and l2.is_action("secondary"),
		"R1 jumps, L1 interacts and L2 is the second action (take)")


class _Probe extends Node:
	var seen: Callable
	func _input(ev: InputEvent) -> void:
		seen.call(ev)


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
