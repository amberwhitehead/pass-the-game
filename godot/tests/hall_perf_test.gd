extends "res://tests/test_suite.gd"
## Walking round the hall stays cheap: the hall spot is saved when the player stops (and
## at most every 30 s while moving), not every few seconds, since each save is a file write
## and, on the Web, an IndexedDB sync; and the interaction caption, updated every frame,
## doesn't redraw or restyle its badges unless what it shows changes. The shader warm-up
## specks come and go as the hall opens.

const SaveGame := preload("res://autoload/save_game.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = root.get_node("Game")
	SaveGame.slot_prefix = "user://test_hall_perf_slot_"
	game.new_game(0)
	game.set_flag("room_visited")
	var room = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	var player = room.get_node("Player")
	_expect(player.camera.has_node("ShaderWarmup"), "The outline and laser shaders are warmed as the hall opens")
	for i in 10:
		await process_frame
	_expect(not player.camera.has_node("ShaderWarmup"), "...and the specks are gone a few frames later")

	var spots := [0]
	game.flag_changed.connect(func(f: String, _v: Variant): if f == "hall_spot": spots[0] += 1)
	Input.action_press("move_up")
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 5000:
		player.rotation.y += 0.02  # Round and round, never into a wall for long.
		await process_frame
	Input.action_release("move_up")
	_expect(spots[0] == 0, "Five seconds of walking writes no hall spot (%d)" % spots[0])
	start = Time.get_ticks_msec()
	while spots[0] == 0 and Time.get_ticks_msec() - start < 3000:
		await process_frame
	_expect(spots[0] == 1, "Stopping saves the spot once, shortly after (%d)" % spots[0])

	var plaque = room.hud._prompt
	room.hud.process_mode = Node.PROCESS_MODE_DISABLED  # Its own updates would hide the caption.
	plaque.visible = true
	plaque.modulate.a = 1.0
	plaque.present("Adjust prism B", "pad:r1:playstation", false, "Take prism from B", "pad:r2:playstation")
	await process_frame
	var redraws := [0]
	var badge: Control = plaque.key.get_parent()
	badge.draw.connect(func(): redraws[0] += 1)
	for i in 30:
		plaque.present("Adjust prism B", "pad:r1:playstation", false, "Take prism from B", "pad:r2:playstation")
		await process_frame
	_expect(redraws[0] == 0, "An unchanged prompt doesn't redraw its badge every frame (%d)" % redraws[0])
	plaque.present("Take prism from B", "Click", false)
	await process_frame
	_expect(redraws[0] > 0 and plaque.key.visible and plaque.key.text == "Click", "A changed prompt does update")

	room.queue_free()
	await process_frame
	SaveGame.erase(SaveGame.slot_path(0))
	game.autosave = false
	game.save_path = ""
	print("Hall perf: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _expect(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(description)
