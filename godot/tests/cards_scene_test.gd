extends SceneTree
## Scene integration smoke test. No rendered window or synthetic OS input.
## Run: godot --headless --path godot --script res://tests/cards_scene_test.gd

const ROOM_PATH := "res://scenes/room/room.tscn"
const Catalog := preload("res://minigames/cards/card_catalog.gd")
var _checks := 0
var _failures := 0
var _returned := false
var _result: Dictionary = {}
var _games: Node
var _touch: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _launch() -> void:
	_result = await _games.play("cards")
	_returned = true


func _run() -> void:
	Engine.time_scale = 12.0
	Engine.max_fps = 120
	_games = root.get_node("MiniGames")
	_touch = root.get_node("TouchControls")
	var global_game: Node = root.get_node("Game")
	global_game.set_flag("room_visited")
	var packed: PackedScene = load(ROOM_PATH)
	var room: Node = packed.instantiate()
	root.add_child(room)
	current_scene = room
	_expect(room.get_node("Challenge3").minigame_id == "cards", "Challenge 3 launches the card table")
	_expect(room.get_node("Augmented").minigame_id == "cards", "Little Brother also launches the card table")
	call_deferred("_launch")
	for frame in 600:
		if _games.current != null:
			break
		await process_frame
	if _games.current == null:
		_expect(false, "Card scene loads through MiniGames")
		quit(1)
		return
	var game: Node = _games.current
	_expect(paused, "Launching cards pauses the hub")
	_expect(not _touch._enabled, "Card table hides the movement pad")
	_expect(game._entering, "Opening the table starts a 3D entrance")
	var entry_state: Dictionary = game.match_state.snapshot()
	game.table.hand_cards[0].pressed.emit()
	game.table.end_button.pressed.emit()
	_expect(game.match_state.snapshot() == entry_state and game._selected == -1,
		"Entrance locks card selection and turn actions")
	await _entry_complete(game)
	_expect(is_instance_valid(game._dialog), "Rules dialog opens for the first match")
	_expect(game.table.end_button.disabled, "Rules dialog locks table actions")
	_press_dialog(game, "Let's play")
	await process_frame
	_expect(not is_instance_valid(game._dialog), "Tutorial button dismisses the dialog")
	_expect(not game.table.end_button.disabled, "Dismissing tutorial unlocks the table")

	var before: Dictionary = game.match_state.snapshot()
	game.table.hand_cards[0].pressed.emit()
	game.table.enemy_slots[0].pressed.emit()
	_expect(game.match_state.snapshot() == before, "Wrong-side unit targeting does not spend a card")
	game.table.player_slots[0].pressed.emit()
	await _idle(game)
	_expect(game._shown.player[0].get("id", "") == "scout", "Card/slot signals deploy Scout to lane one")
	game.table.hand_cards[1].pressed.emit()
	game.table.player_slots[2].pressed.emit()
	await _idle(game)
	_expect(game._shown.player[2].get("id", "") == "guard", "Second card/slot signals deploy Guard to lane three")
	game.table.end_button.pressed.emit()
	await _idle(game)
	_expect(game._shown.turn == 2, "End-turn button animates into the next player turn")
	_expect(game._shown.enemy[1].get("id", "") == "guard", "Announced enemy arrives in the advertised lane")

	for round_index in 35:
		if game._shown.winner != "":
			break
		for action_index in 12:
			var choice: Vector2i = _choose_play(game.match_state)
			if choice.x < 0:
				break
			var state: Dictionary = game.match_state.snapshot()
			var card: Dictionary = Catalog.get_card(state.hand[choice.x])
			game.table.hand_cards[choice.x].pressed.emit()
			var slots: Array = game.table.enemy_slots if card.kind == "damage" else game.table.player_slots
			slots[choice.y].pressed.emit()
			await _idle(game)
		game.table.end_button.pressed.emit()
		await _idle(game)
	_expect(game._shown.winner == "player", "Starter deck can win through the scene's real button wiring")
	_expect(is_instance_valid(game._dialog), "Victory presents the result dialog")
	_expect(game.table.end_button.disabled, "Finished match prevents further turns")
	_press_dialog(game, "Back to room")
	await process_frame
	_expect(_returned and _result.get("won", false), "Launcher receives the completed win result")
	_expect(not paused and _games.current == null, "Leaving the table restores the hub and clears current game")
	_expect(_touch._enabled, "Leaving the table restores movement controls")
	_expect(global_game.completed_minigames.has("cards"), "Completion is stored in global game state")
	var stand := room.get_node("Challenge3")
	stand._refresh_completed()
	# The card stand replaces the generic orb marker and stays out for rematches.
	_expect(stand.visible and stand.get_node("WalnutCardStand").visible and stand.minigame_id == "cards",
		"Challenge 3 remains visible and replayable after victory")

	# Re-enter, then exit while an animation is active: the hub must not remain paused.
	_returned = false
	call_deferred("_launch")
	for frame in 600:
		if _games.current != null:
			break
		await process_frame
	if _games.current != null:
		game = _games.current
		await _entry_complete(game)
		_press_dialog(game, "Let's play")
		game.table.hand_cards[0].pressed.emit()
		game.table.player_slots[0].pressed.emit()
		_expect(game._busy, "A deployment starts its animation before the exit test")
		game.finish({"won": false, "quit": true})
		await process_frame
		_expect(_returned and not paused and _touch._enabled, "Exit during animation restores normal controls")
		_expect(global_game.completed_minigames.has("cards"), "Quitting a later replay preserves the previous win")
	else:
		_expect(false, "Completed table can be reopened")

	# Entry is cancellable through the same Escape action used during play.
	_returned = false
	call_deferred("_launch")
	for frame in 600:
		if _games.current != null:
			break
		await process_frame
	if _games.current != null:
		game = _games.current
		_expect(game._entering, "Replay begins an entrance before Escape")
		var escape := InputEventAction.new()
		escape.action = "back"
		escape.pressed = true
		Input.parse_input_event(escape)
		await process_frame
		escape.pressed = false
		Input.parse_input_event(escape)
		await process_frame
		_expect(_returned and not paused and _games.current == null and _touch._enabled,
			"Escape during the 3D entrance restores the hub and movement controls")
		_expect(global_game.completed_minigames.has("cards"), "Cancelling an entrance preserves an earlier victory")
	else:
		_expect(false, "Table reopens for entrance cancellation check")
	room.queue_free()
	await process_frame
	print("Card scene: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _entry_complete(game: Node) -> void:
	for frame in 1200:
		if not game._entering:
			return
		await process_frame
	_expect(false, "3D entrance completes within timeout")


func _idle(game: Node) -> void:
	for frame in 3600:
		if not game._busy:
			return
		await process_frame
	_expect(false, "Scene animation completes within timeout")


func _press_dialog(game: Node, label: String) -> void:
	if not is_instance_valid(game._dialog):
		_expect(false, "Expected dialog before pressing " + label)
		return
	for button: Button in game._dialog.find_children("*", "Button", true, false):
		if button.text == label:
			button.pressed.emit()
			return
	_expect(false, "Dialog contains action " + label)


func _choose_play(rules: RefCounted) -> Vector2i:
	var state: Dictionary = rules.snapshot()
	var best_score := -INF
	var choice := Vector2i(-1, -1)
	for index in state.hand.size():
		var card: Dictionary = Catalog.get_card(state.hand[index])
		for lane in 3:
			if rules.legality_error(index, lane) != "":
				continue
			var score: float = card.power * 3.0 + card.health * 0.3 - card.cost * 0.2
			var foe: Dictionary = state.enemy[lane]
			if card.kind == "damage":
				score = 12.0 if foe.hp <= 2 and foe.power > 0 else 2.0
			elif card.kind == "heal":
				score = 4.0
			elif foe.is_empty():
				score += card.power * 2.0
			elif card.power == 0:
				score += foe.power * 2.0
			if score > best_score:
				best_score = score
				choice = Vector2i(index, lane)
	return choice
