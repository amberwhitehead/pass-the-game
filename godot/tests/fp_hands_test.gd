extends "res://tests/test_suite.gd"
## The first-person hands in the hall: they exist on the camera inside the collision
## capsule, swing while walking and settle when still, reach on interact, wave when a
## conversation opens, hold the carried item in the right hand, and hide in a minigame.
## The HUD no longer has an "In your hand" panel.

var _checks := 0
var _failures := 0
var _room: Node3D
var _player: Node3D
var _hands: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game: Node = root.get_node("Game")
	game.play_unsaved({"flags": {"room_visited": true}})
	_room = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	_player = _room.get_node("Player")
	await create_timer(1.0).timeout  # Land from the spawn first.
	_hands = _room.hands

	# Built, on the camera, and inside the capsule so they never poke into walls.
	_expect(_hands != null and _hands.get_parent() == _player.camera, "The hands hang from the camera")
	_expect(_hands.right.get_meta("fingers").size() == 4 and _hands.left.get_meta("fingers").size() == 4, "Each hand has four fingers")
	var farthest := 0.0
	var far_name := ""
	for part in _hands.find_children("*", "MeshInstance3D", true, false):
		var d: float = _player.camera.to_local((part as Node3D).global_position).length()
		if d > farthest:
			farthest = d
			far_name = str(part.get_path())
	_expect(farthest < 0.33, "Every part sits inside the player's 0.35 m capsule (farthest %.2f, %s)" % [farthest, far_name])
	_expect(_hands.visible, "Visible in the hall")
	var hud_text := _all_text(_room.hud)
	_expect(not "IN YOUR HAND" in hud_text, "The HUD's In your hand panel is gone")

	# Walking swings them; standing still settles them.
	var rest: Vector3 = _hands.right.position
	Input.action_press("move_up")
	var spread := 0.0
	for i in 60:
		await physics_frame
		spread = maxf(spread, _hands.right.position.distance_to(rest))
	Input.action_release("move_up")
	_expect(spread > 0.01, "Walking swings the hands (moved %.3f)" % spread)
	await create_timer(1.5).timeout
	_expect(_hands.right.position.distance_to(rest) < 0.006, "Standing still, they settle back")

	# Interacting reaches a hand out.
	var target: Node = null
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Interactable:
			target = node
			break
	var before: Vector3 = _hands.right.position
	_player.reached.emit(target)
	var reached := 0.0
	var tip_far := 0.0
	for i in 30:
		await create_timer(0.02).timeout
		reached = maxf(reached, _hands.right.position.distance_to(before))
		for finger: Node3D in _hands.right.get_meta("fingers"):
			tip_far = maxf(tip_far, _player.camera.to_local(finger.get_child(0).global_position).length())
	_expect(reached > 0.06, "Interacting reaches the right hand out (%.3f)" % reached)
	_expect(tip_far < 0.35, "Even mid-reach it stays inside the capsule (%.2f)" % tip_far)
	await create_timer(0.6).timeout

	# A conversation opens with a wave of the left hand.
	var dialogue: Node = root.get_node("Dialogue")
	dialogue.say("Tester", ["Hello."])
	await create_timer(0.5).timeout
	_expect(_hands.wave_t >= 0.0 and _hands.left.position.y > _hands.right.position.y + 0.1, "A conversation opens with a raised, waving left hand")
	var roll: float = _hands.left.rotation.z
	await create_timer(0.1).timeout
	_expect(not is_equal_approx(roll, _hands.left.rotation.z), "...that rocks side to side")
	await _press_interact()
	await _press_interact()
	await _frames(5)
	_expect(not dialogue.active, "The conversation closes")

	# Holding: the item sits in the right hand, fingers curled; that hand reaches to place it.
	_room.inventory.exchange("prism")
	await _frames(5)
	var held: Node3D = _hands.grip.get_child(0) if _hands.grip.get_child_count() > 0 else null
	_expect(held != null and held.visible and held.get_child_count() > 0, "The carried prism sits in the right hand's grip")
	_expect(_hands.holding and (_hands.right.get_meta("fingers")[0] as Node3D).rotation.x < -0.8, "The right hand's fingers curl round it")
	var right_held: Vector3 = _hands.right.position
	_player.reached.emit(target)
	reached = 0.0
	for i in 30:
		await create_timer(0.02).timeout
		reached = maxf(reached, _hands.right.position.distance_to(right_held))
	await create_timer(0.6).timeout
	_expect(reached > 0.06, "Holding something, the right hand reaches out to place it")
	_room.inventory.exchange("")
	await _frames(5)
	_expect(not _hands.holding and not held.visible, "Put down, the hand is empty again")

	# Hidden while a minigame has the screen.
	var games: Node = root.get_node("MiniGames")
	var result := {}
	var launch := func(): result.merge(await games.play("newton"))
	launch.call_deferred()
	for i in 600:
		if games.current != null:
			break
		await process_frame
	await _frames(3)
	_expect(games.current != null and not _hands.visible, "Hidden while a minigame runs")
	if games.current != null:
		games.current.finish({"won": false, "quit": true})
	for i in 300:
		if games.current == null:
			break
		await process_frame
	await _frames(3)
	_expect(_hands.visible, "Back in the hall, they return")

	_room.queue_free()
	await process_frame
	game.autosave = false
	print("First-person hands: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _press_interact() -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = "interact"
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


func _all_text(node: Node) -> String:
	var out := ""
	for child in node.find_children("*", "Label", true, false):
		out += (child as Label).text + "\n"
	return out


func _expect(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(description)
