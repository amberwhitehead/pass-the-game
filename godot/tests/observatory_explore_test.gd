extends "res://tests/test_suite.gd"
## Real-interface exploration of the Observatory: drives the actual minigame through
## its input actions and _unhandled_input, and checks the observable contract.
const OMath := preload("res://minigames/observatory/observatory_math.gd")

var _checks := 0
var _failures := 0
var _game: Node
var _puzzle: Node


func _initialize() -> void:
	_run.call_deferred()


func _expect(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: " + msg)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = code
	e.physical_keycode = code
	return e


func _open(resume := {}) -> Node:
	_puzzle = load("res://minigames/observatory/observatory.tscn").instantiate()
	_puzzle.resume_state = resume
	root.add_child(_puzzle)
	current_scene = _puzzle
	return _puzzle


func _close() -> void:
	if is_instance_valid(_puzzle):
		_puzzle.queue_free()
	_puzzle = null


func _run() -> void:
	Engine.max_fps = 120
	Engine.time_scale = 4.0
	root.size = Vector2i(1280, 720)
	_game = root.get_node("Game")
	_game.flags.clear()
	_game.completed_minigames.clear()
	_game.collected_cards.clear()

	# --- 1. grab + turn every control through real input ---
	_expect(InputMap.has_action("interact"), "the interact action exists")
	_expect(_key(KEY_E).is_action_pressed("interact"), "E matches the interact action")
	_open()
	await physics_frame
	_puzzle._theta = 2.75  # Valve A: a knob, not a button
	_puzzle._update_camera(0.0)
	await process_frame
	_expect(_puzzle._focus >= 0, "a control is focused when the camera faces it")
	var first_focus: int = _puzzle._focus
	_puzzle._unhandled_input(_key(KEY_E))
	_expect(_puzzle._grabbed == first_focus, "E grabs the focused control")
	var before: float = float(_puzzle._controls[first_focus].get("value", 0.0))
	Input.action_press("move_down")
	for i in 20:
		_puzzle._process(0.03)
	Input.action_release("move_down")
	_expect(float(_puzzle._controls[first_focus].get("value", 0.0)) != before, "W/S turns the grabbed control")
	# A/D orbits while still grabbed
	var theta_before: float = _puzzle._theta
	Input.action_press("strafe_right")
	for i in 10:
		_puzzle._process(0.03)
	Input.action_release("strafe_right")
	_expect(absf(_puzzle._theta - theta_before) > 0.01, "A/D orbits the view while a control is grabbed")
	_expect(_puzzle._grabbed == first_focus, "the grab survives orbiting")
	_puzzle._unhandled_input(_key(KEY_E))
	_expect(_puzzle._grabbed < 0, "E releases the grabbed control")
	_close()

	# --- 2. clamp: a valve cannot exceed its range ---
	_open()
	await physics_frame
	# find ValveA index and force-grab it
	var vi := -1
	for i in _puzzle._controls.size():
		if _puzzle._controls[i].id == "v1":
			vi = i
	_puzzle._grabbed = vi
	_puzzle._controls[vi]["value"] = 1.0
	Input.action_press("move_down")
	for i in 40:
		_puzzle._process(0.03)
	Input.action_release("move_down")
	_expect(float(_puzzle._controls[vi].value) <= 1.0001, "valve clamps at its maximum")
	_expect(float(_puzzle._controls[vi].value) >= 0.9999, "valve reaches its maximum")
	_close()

	# --- 3. crank interlock: not ready → no layer; ready → layer ---
	_open()
	await physics_frame
	_puzzle._layer = 0
	# not resolved, so crank should refuse
	_puzzle._az = 99.0
	_puzzle._controls[6]["value"] = 0.9
	_puzzle._grabbed = 6  # crank
	Input.action_press("move_down")
	for i in 20:
		_puzzle._process(0.05)
	Input.action_release("move_down")
	_expect(_puzzle._layer == 0, "crank refuses a layer while the telescope is unresolved")
	# resolve + clean, then crank
	var s = OMath.sigil(_puzzle._sigil_target)
	_puzzle._az = s.az
	_puzzle._el = s.el
	_puzzle._focusv = s.focus
	_puzzle._v1 = s.v1
	_puzzle._v2 = s.v2
	_expect(_puzzle._crank_ready(), "crank is ready when resolved and clean")
	_puzzle._controls[6]["value"] = 0.9
	Input.action_press("move_down")
	for i in 20:
		_puzzle._process(0.05)
	Input.action_release("move_down")
	_expect(_puzzle._layer == 1, "crank advances a layer when ready")
	_close()

	# --- 4. failed inscription resets the plate; successful one collects ---
	_open()
	await physics_frame
	_puzzle._layer = OMath.LAYERS
	for i in OMath.LAYERS:
		_puzzle._plate[i] = true
	_puzzle._plate[0] = false  # one void layer
	_puzzle._try_inscribe()
	_expect(_puzzle._layer == 0 and not _puzzle._collected[0], "a void layer is rejected and clears the plate")
	for i in OMath.LAYERS:
		_puzzle._plate[i] = true
	_puzzle._layer = OMath.LAYERS
	_puzzle._try_inscribe()
	_expect(_puzzle._collected[0], "a clean plate inscribes")
	_close()

	# --- 4b. two-hand reset: covers, arming, four-second wait ---
	_open()
	await physics_frame
	_puzzle._layer = 2
	_puzzle._press_reset("a")
	_expect(bool(_puzzle._reset_cover_open["a"]), "the first press opens the cover")
	_puzzle._press_reset("a")
	_expect(bool(_puzzle._reset_armed["a"]) and _puzzle._reset_glow == "b", "pressing again arms A and makes B glow")
	_expect(absf(_puzzle._reset_timer - 4.0) < 0.01, "the partner glows for four seconds")
	_puzzle._press_reset("b")
	_expect(_puzzle._layer == 2, "pressing the partner too soon does nothing")
	_puzzle._update_reset(4.1)
	_expect(_puzzle._reset_glow == "", "the glow ends after four seconds")
	_puzzle._press_reset("b")
	_expect(_puzzle._layer == 0, "the second press after the wait resets the plate")
	_expect(not bool(_puzzle._reset_cover_open["a"]) and not bool(_puzzle._reset_cover_open["b"]), "the covers close after a reset")
	_close()

	# --- 5. save/resume round-trip mid-forge ---
	_open()
	await physics_frame
	_puzzle._sigil_target = 2
	_puzzle._az = 0.7
	_puzzle._el = -0.3
	_puzzle._focusv = 0.8
	_puzzle._v1 = 0.2
	_puzzle._v2 = 0.9
	_puzzle._layer = 2
	_puzzle._plate[0] = true
	_puzzle._plate[1] = true
	var saved: Dictionary = _puzzle.save_state()
	_close()
	_open(saved)
	await physics_frame
	_expect(int(_puzzle._sigil_target) == 2, "resume restores the selected sigil")
	_expect(absf(_puzzle._az - 0.7) < 0.001 and absf(_puzzle._el + 0.3) < 0.001, "resume restores the aim")
	_expect(absf(_puzzle._focusv - 0.8) < 0.001, "resume restores focus")
	_expect(absf(_puzzle._v1 - 0.2) < 0.001 and absf(_puzzle._v2 - 0.9) < 0.001, "resume restores the valves")
	_expect(int(_puzzle._layer) == 2 and bool(_puzzle._plate[0]) and bool(_puzzle._plate[1]), "resume restores layer progress")
	_close()

	# --- 6. full run: all sigils collected grants every card and wins ---
	_open()
	await physics_frame
	for i in OMath.SIGIL_COUNT:
		var sig = OMath.sigil(i)
		_puzzle._sigil_target = i
		_puzzle._az = sig.az; _puzzle._el = sig.el; _puzzle._focusv = sig.focus
		_puzzle._v1 = sig.v1; _puzzle._v2 = sig.v2
		_puzzle._layer = 0
		for j in OMath.LAYERS:
			_puzzle._advance_layer()
		_puzzle._try_inscribe()
	for i in OMath.SIGIL_COUNT:
		_expect(_puzzle._collected[i], "sigil %d collected in a full run" % i)
		_expect(_game.collected_cards.has(OMath.sigil(i).card), "sigil %d grants its card" % i)
	_puzzle._process(0.1)
	_expect(_puzzle._solved, "all sigils solve the game")
	_close()

	print("Observatory explore: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)