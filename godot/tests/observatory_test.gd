extends "res://tests/test_suite.gd"
const OMath := preload("res://minigames/observatory/observatory_math.gd")
## Scene-level smoke test for the Observatory's Aetheric Sigil Press.
var _checks := 0
var _failures := 0
var _game: Node
var _puzzle: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 120
	Engine.time_scale = 4.0
	root.size = Vector2i(1280, 720)
	_game = root.get_node("Game")
	_game.flags.clear()
	_game.completed_minigames.clear()
	_game.collected_cards.clear()
	_puzzle = load("res://minigames/observatory/observatory.tscn").instantiate()
	root.add_child(_puzzle)
	current_scene = _puzzle
	await physics_frame
	_expect(not _puzzle._solved, "Observatory starts unsolved")
	_expect(_puzzle._count_collected() == 0, "No sigils collected at start")

	# Forge the first sigil: tune telescope to resolved, valves to clean, crank 4 layers, inscribe.
	var s = OMath.sigil(0)
	_puzzle._sigil_target = 0
	_puzzle._az = s.az
	_puzzle._el = s.el
	_puzzle._focusv = s.focus
	_puzzle._v1 = s.v1
	_puzzle._v2 = s.v2
	for c in _puzzle._controls:
		match c.id:
			"sigil": c.value = 0.0
			"az": c.value = s.az
			"el": c.value = s.el
			"focus": c.value = s.focus
			"v1": c.value = s.v1
			"v2": c.value = s.v2
	_puzzle._layer = 0
	for i in OMath.LAYERS:
		_puzzle._advance_layer()
	_expect(_puzzle._layer == _puzzle.LAYERS, "Four layers solidified")
	_expect(OMath.all_clean(_puzzle._plate), "Plate is clean")
	_puzzle._try_inscribe()
	_expect(_puzzle._collected[0], "First sigil collected")
	_expect(_game.collected_cards.has(s.card), "Sigil grants its bonus card")

	# Collect remaining sigils.
	for i in range(1, OMath.SIGIL_COUNT):
		var ss = OMath.sigil(i)
		_puzzle._sigil_target = i
		_puzzle._az = ss.az; _puzzle._el = ss.el; _puzzle._focusv = ss.focus
		_puzzle._v1 = ss.v1; _puzzle._v2 = ss.v2
		for c in _puzzle._controls:
			match c.id:
				"sigil": c.value = float(i)
				"az": c.value = ss.az
				"el": c.value = ss.el
				"focus": c.value = ss.focus
				"v1": c.value = ss.v1
				"v2": c.value = ss.v2
		_puzzle._layer = 0
		for j in OMath.LAYERS:
			_puzzle._advance_layer()
		_puzzle._try_inscribe()
		_expect(_puzzle._collected[i], "Sigil %d collected" % i)

	_puzzle._process(0.1)
	_expect(_puzzle._solved, "All sigils collected solves the game")
	print("Observatory: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _expect(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: " + msg)


func _key() -> void:
	pass