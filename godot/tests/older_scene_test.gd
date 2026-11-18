extends "res://tests/test_suite.gd"
## Actual hub launcher, four-lane picking, two-target spell input, and event playback.
const Catalog := preload("res://minigames/cards/card_catalog.gd")
var checks := 0
var failures := 0
var game: Node
var games: Node
var returned := false
var result: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _launch() -> void:
	result = await games.play("cards_older")
	returned = true

func _run() -> void:
	Engine.time_scale = 10
	Engine.max_fps = 120
	root.size = Vector2i(1280, 720)
	games = root.get_node("MiniGames")
	var room: Node = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	check(room.get_node("OlderBrother").minigame_id == "cards_older", "Older brother is reachable in the existing card chamber")
	check(room.get_node("Augmented").minigame_id == "cards", "Little brother retains his own encounter")
	_launch.call_deferred()
	for frame in 1200:
		if games.current != null:
			break
		await process_frame
	game = games.current
	if game == null:
		check(false, "Older encounter launches")
		quit(1)
		return
	check(game.opponent_id == "older_brother" and game._entering, "Older scene uses the live entrance")
	for frame in 1200:
		if not game._entering:
			break
		await process_frame
	check(not game._entering and is_instance_valid(game._dialog), "Older entrance completes into its rules")
	_press("Let's play")
	await process_frame
	check(game._shown.player.size() == 4 and game.table.player_slots.size() == 4, "Rules and physical board both have four lanes")
	check(game._shown.hand.size() == 5 and game._shown.deck_count == 7 and game._shown.energy == 3, "Older base opening has five cards, seven draws, and three Attention")
	for window: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(960, 540), Vector2i(688, 921)]:
		root.size = window
		await process_frame
		await physics_frame
		if window.x * 9 == window.y * 16:
			check(is_equal_approx(game.table.camera.fov, 48.0), "Desktop camera framing remains unchanged at %s" % window)
		for side in ["player", "enemy"]:
			for lane in 4:
				var actor: Node3D = game.table.slot(side, lane)
				var point: Vector2 = game.table.camera.unproject_position(actor.global_position)
				check(Rect2(Vector2.ZERO, game.table.size).has_point(point), "%s lane %d stays on screen at %s" % [side, lane, window])
				check(game.table.pick_actor(point) == actor, "%s lane %d remains pickable at %s" % [side, lane, window])
		var bell: Node3D = game.table.end_button
		var bell_point: Vector2 = game.table.camera.unproject_position(bell.to_global(Vector3(0, .1, 0)))
		check(Rect2(Vector2.ZERO, game.table.size).has_point(bell_point), "Older bell stays visible at %s" % window)
		check(game.table.pick_actor(bell_point) == bell, "Older bell remains reachable at %s" % window)
		var attention: Node3D = game.table._attention
		for corner: Vector3 in [Vector3(-.665, .06, -.715), Vector3(.665, .06, .715)]:
			check(Rect2(Vector2.ZERO, game.table.size).has_point(game.table.camera.unproject_position(attention.to_global(corner))), "Attention counter stays visible at %s" % window)
	root.size = Vector2i(1280, 720)
	await process_frame

	# Preserve wounded unit identity and spent interception through the real two-click flow.
	_clear_fixture()
	var bruiser: Dictionary = game.match_state._make_unit("bruiser")
	bruiser.hp = 3
	var sentinel: Dictionary = game.match_state._make_unit("sentinel")
	sentinel.intercept_ready = false
	game.match_state._player[0] = bruiser
	game.match_state._player[1] = sentinel
	game.match_state._hand.assign(["switcheroo"])
	_sync()
	var before: Dictionary = game.match_state.snapshot()
	game.table.hand_cards[0].pressed.emit()
	game.table.player_slots[0].pressed.emit()
	check(game._swap_source == 0 and game.match_state.snapshot() == before, "First swap target does not spend or mutate the match")
	game.table.player_slots[3].pressed.emit()
	check(game.match_state.snapshot() == before and game._swap_source == 0, "Invalid second target preserves the pending spell")
	var escape := InputEventAction.new()
	escape.action = "back"
	escape.pressed = true
	game._unhandled_input(escape)
	check(game._swap_source == -1 and not game._done, "Escape cancels the pending source without leaving")
	game.table.player_slots[0].pressed.emit()
	game.table.player_slots[1].pressed.emit()
	check(game._busy, "Successful swap locks input during physical motion")
	await _idle()
	check(game._shown.player[1].uid == bruiser.uid and game._shown.player[1].hp == 3, "Swap preserves wounded creature identity")
	check(game._shown.player[0].uid == sentinel.uid and not game._shown.player[0].intercept_ready, "Swap preserves Sentinel readiness")
	check(game._shown.energy == before.energy - 1 and game._shown.hand.is_empty(), "Switcheroo spends one card and one Attention exactly once")
	for lane in 4:
		check(game.table.slot("player", lane).position.is_equal_approx(game.table.lane_position("player", lane)), "Swap restores physical lane %d anchor" % lane)

	# Reproduce the promised bait: left attack pulls Sentinel, Forkshot hits two openings.
	_clear_fixture()
	game.match_state._player[0] = game.match_state._make_unit("bruiser")
	game.match_state._player[2] = game.match_state._make_unit("forkshot")
	game.match_state._enemy[1] = game.match_state._make_unit("sentinel")
	game.match_state._enemy[2] = game.match_state._make_unit("defender")
	_sync()
	game.table.end_button.pressed.emit()
	await _idle()
	check(game._shown.enemy[0].get("id") == "sentinel" and game._shown.enemy[1].is_empty(), "Interception moves and renders the guard into the threatened lane")
	check(game._shown.enemy[0].hp == 6, "Intercepted attack damages the moving guard")
	check(game._shown.balance == 2, "Forkshot attacks the two actual diagonal openings")
	check(game.table.enemy_slots[0].card_data.id == "sentinel" and game.table.enemy_slots[1].is_empty, "Scene actors agree with post-interception state")
	check(game._shown.turn == 2 and game._shown.energy == 4, "Combat settles into the next older turn")

	# A finished older match records the correct encounter and restores the caller.
	_clear_fixture()
	game.match_state._balance = 11
	game.match_state._player[3] = game.match_state._make_unit("bruiser")
	_sync()
	game.table.end_button.pressed.emit()
	await _idle()
	check(game._shown.winner == "player" and is_instance_valid(game._dialog), "Older victory reaches the result panel")
	_press("Back to room")
	await process_frame
	check(returned and result.get("won", false) and result.get("opponent") == "older_brother", "Victory reports the correct brother")
	check(not paused and games.current == null and root.get_node("TouchControls")._enabled, "Older exit restores the hub and movement")
	check(root.get_node("Game").completed_minigames.has("cards_older"), "Older victory is recorded separately")
	room.queue_free()
	await process_frame
	print("Older scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _clear_fixture() -> void:
	for lane in 4:
		game.match_state._player[lane] = {}
		game.match_state._enemy[lane] = {}
	game.match_state._hand.clear()
	game.match_state._intent = {}
	game.match_state._balance = 0
	game.match_state._energy = 3
	game.match_state._turn = 1
	game._selected = -1
	game._swap_source = -1

func _sync() -> void:
	game._shown = game.match_state.snapshot()
	game._refresh()

func _idle() -> void:
	for frame in 2400:
		if not game._busy:
			return
		await process_frame
	check(false, "Older animation settles within timeout")

func _press(copy: String) -> void:
	if is_instance_valid(game._dialog):
		for button: Button in game._dialog.find_children("*", "Button", true, false):
			if button.text == copy:
				button.pressed.emit()
				return
	check(false, "Dialog exposes " + copy)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
