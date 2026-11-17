extends SceneTree
## Physical rooms, one-item ownership, reward lifecycle, and persistent optics.
## Run: godot --headless --path godot --script res://tests/escape_hub_test.gd

const ROOM := "res://scenes/room/room.tscn"
var _checks := 0
var _failures := 0
var _room: Node3D
var _player: Node3D
var _game: Node
var _games: Node
var _touch: Node
var _reveal_finishes := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 120
	Engine.time_scale = 6.0
	root.size = Vector2i(1280, 720)
	_game = root.get_node("Game")
	_games = root.get_node("MiniGames")
	_touch = root.get_node("TouchControls")
	_game.flags.clear()
	_game.completed_minigames.clear()
	await _load_room()
	await _test_architecture()
	_test_desktop_controls()
	_test_inventory()
	await _test_rewards()
	await _test_solution()
	await _test_reload()
	_room.queue_free()
	await process_frame
	print("Escape hub: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _load_room() -> void:
	_room = load(ROOM).instantiate()
	root.add_child(_room)
	current_scene = _room
	_player = _room.get_node("Player")
	await physics_frame
	await physics_frame


func _test_architecture() -> void:
	_expect(_room.architecture.rooms.size() == 6, "The hall has six separate side rooms")
	_expect(_room.architecture.stations.size() == 12, "All six stations and their NPCs receive room placements")
	for node_name: String in _room.architecture.stations:
		var position: Vector3 = _room.architecture.stations[node_name].position
		_expect(_room.get_node(node_name).position.is_equal_approx(position), node_name + " is in its side room")
	for x in [-6.0, 2.0]:
		_expect(not _ray(Vector3(x, 1.2, -7), Vector3(x, 1.2, -10)), "North doorway %s is walkable" % x)
	for x in [-7.0, 0.0, 7.0]:
		_expect(not _ray(Vector3(x, 1.2, 7), Vector3(x, 1.2, 10)), "South doorway %s is walkable" % x)
	_expect(_gate_blocks(), "Room 2 begins physically locked")
	_expect(_ray(Vector3(-10, 1.2, 0), Vector3(-12, 1.2, 0)), "West exit blocks leaving the world")
	_expect(_ray(Vector3(-8, 1.2, -7), Vector3(-8, 1.2, -10)), "Wall beside Egypt's doorway has collision")
	var receiver: Vector3 = _room.optics._receiver.global_position
	var door: Vector3 = _room.architecture.locked_door.global_position
	_expect(absf(receiver.x - door.x) < 0.4 and absf(receiver.z - door.z) < 2.0, "The optical receiver sits at Door 2's frame")
	_expect(not _ray(Vector3(-9, 0.6, 0), Vector3(3, 0.6, 0)), "The central hall remains clear for future escape-room interactions")
	for device: Node3D in _room.optics.devices.values():
		_expect(device.position.x > 3.0, "Optical hardware stays in the compact east-side installation")
	for id: String in _room.architecture.rooms:
		var at: Vector3 = _room.architecture.rooms[id]
		_expect(_ray(at + Vector3.UP * 2, at - Vector3.UP), id + " has a supporting floor")
	_player.position = Vector3(10.0, 0, 0)
	await physics_frame
	var roman: Node3D = _room.get_node("Challenge5")
	_expect(not _player._can_see(roman, roman.get_focus_position()), "A sealed doorway blocks interacting with the Roman station")
	_player.position = Vector3(-8, 0, -7)
	await physics_frame
	var egyptian: Node3D = _room.get_node("Egyptian")
	_expect(not _player._can_see(egyptian, egyptian.get_focus_position()), "The solid side wall blocks NPC interaction")
	_player.position = Vector3(-6, 0, -9.2)
	_player.rotation.y = 0.0
	await physics_frame


func _test_desktop_controls() -> void:
	_touch._awake = false
	_touch.set_enabled(true)
	var emulated := InputEventScreenTouch.new()
	emulated.device = -1
	emulated.position = Vector2(640, 360)
	emulated.pressed = true
	_touch._input(emulated)
	_expect(not _touch._awake and not _touch._root.visible, "Mouse-emulated dragging does not expose mobile controls")
	var real_touch := InputEventScreenTouch.new()
	real_touch.device = 0
	real_touch.position = Vector2(640, 360)
	real_touch.pressed = true
	_touch._input(real_touch)
	_expect(_touch._awake and _touch._root.visible, "Actual touch still enables the mobile controls")
	_touch._awake = false
	_touch.set_enabled(true)


func _test_inventory() -> void:
	_expect(_room.inventory.held_item == "", "The player starts with an empty hand")
	_expect(_counts() == {"prism": 2, "lens_yellow": 1, "lens_blue": 1}, "Exactly two lenses and two reserved reward prisms exist")
	_expect(not _room.reward_pedestal.visible, "The reward pedestal is hidden before a win")
	_room.reward_pedestal.slots[0].interact(_player)
	_expect(_room.inventory.held_item == "", "Hidden reward slots cannot give items early")
	_room.optics.exchange_item("J")
	_expect(_room.inventory.held_item == "lens_yellow" and _room.optics.model.items.J == "", "Taking a lens transfers ownership to the single hand")
	_room.optics.exchange_item("K")
	_expect(_room.inventory.held_item == "lens_blue" and _room.optics.model.items.K == "lens_yellow", "Taking an occupied compatible mount swaps its item with the hand")
	var state: Dictionary = _room.optics.model.save_state()
	_room.optics.exchange_item("A")
	_expect(_room.inventory.held_item == "lens_blue" and _room.optics.model.save_state() == state, "A lens cannot replace a prism or disappear on an incompatible exchange")
	_room.optics.exchange_item("J")
	_expect(_room.inventory.held_item == "" and _room.optics.model.items.J == "lens_blue", "An empty matching mount frees the hand without a separate tray")
	_room.optics.exchange_item("K")
	_room.optics.exchange_item("L")
	_room.optics.exchange_item("J")
	_room.optics.exchange_item("M")
	_expect(_room.optics.model.items.L == "lens_yellow" and _room.optics.model.items.M == "lens_blue", "Both lenses can be moved using only one carried item")
	_expect(_counts() == {"prism": 2, "lens_yellow": 1, "lens_blue": 1}, "Pickup, swap and placement conserve every item without parking furniture")
	_expect(not _room.architecture.locked_door.unlocked, "Correct lens positions alone do not unlock Room 2")


func _test_rewards() -> void:
	_games.ended.emit("newton", {"won": false, "quit": true})
	_games.ended.emit("cards", {"won": true})
	await process_frame
	_expect(not _game.get_flag("escape_rewards_revealed") and not _room.reward_pedestal.visible, "Quitting Egypt or winning a different game grants no prism reward")
	_player.camera.rotation.x = -0.08
	_player.camera.fov = 71.0
	var pose: Transform3D = _player.camera.transform
	var fov: float = _player.camera.fov
	_room.reward_reveal.finished.connect(func(): _reveal_finishes += 1)
	_games.ended.emit("newton", {"won": true})
	for frame in 30:
		if _room.reward_reveal.active:
			break
		await process_frame
	_expect(_room.reward_reveal.active and _player.cinematic_locked, "A first Egypt win begins the camera reveal and freezes movement")
	_expect(not paused and not _touch._enabled, "The reveal keeps the world running while hiding movement controls")
	await create_timer(0.30).timeout
	_expect(not _player.camera.transform.is_equal_approx(pose), "The reward camera moves over time instead of jumping scenes")
	_escape()
	await process_frame
	await physics_frame
	_expect(not _room.reward_reveal.active and not _player.cinematic_locked, "Escape cancels the camera move and unlocks the player")
	_expect(_player.camera.transform.is_equal_approx(pose) and is_equal_approx(_player.camera.fov, fov), "Cancellation restores the exact camera pose and field of view")
	_expect(_touch._enabled and not paused, "Cancellation restores movement controls without leaving the tree paused")
	_expect(_room.reward_pedestal.is_revealed and _room.reward_pedestal.visible, "Skipping the reveal still exposes the reward")
	_expect(_room.reward_pedestal.slots[0]._available and _room.reward_pedestal.slots[1]._available, "Both reward cradles become interactable after skipping")
	_games.ended.emit("newton", {"won": true})
	_games.ended.emit("newton", {"won": true})
	await process_frame
	_expect(not _room.reward_reveal.active and _reveal_finishes == 1, "Repeated wins do not replay the reward sequence")
	# Exercise normal completion independently, including pre-existing caller state.
	_touch.set_enabled(false)
	_player.cinematic_locked = true
	_room.reward_reveal.play()
	await create_timer(3.6).timeout
	_expect(not _room.reward_reveal.active and _player.cinematic_locked and not _touch._enabled, "Natural completion preserves caller input lock and touch visibility")
	_expect(_player.camera.transform.is_equal_approx(pose) and is_equal_approx(_player.camera.fov, fov), "Natural completion restores the camera exactly")
	_player.cinematic_locked = false
	_touch.set_enabled(true)
	_expect(_counts() == {"prism": 2, "lens_yellow": 1, "lens_blue": 1}, "Reveal cancellation and replay cannot duplicate rewards")


func _test_solution() -> void:
	_room.reward_pedestal.slots[0].interact(_player)
	_expect(_room.inventory.held_item == "prism" and _room.reward_pedestal.slots[0].slot_item == "", "A reward prism can be carried out of its cradle")
	_room.optics.exchange_item("A")
	_room.reward_pedestal.slots[1].interact(_player)
	_room.optics.exchange_item("B")
	_expect(_room.inventory.held_item == "" and _room.optics.model.items.A == "prism" and _room.optics.model.items.B == "prism", "Two separate trips install both prisms")
	_room.optics.rotate_prism("S")
	_expect(not _room.optics.result.won, "Correct sockets with the wrong B orientation still fail")
	_room.optics.rotate_prism("B")
	_expect(_room.optics.result.won and _room.optics.result.color == 3, "The actual controller traces the intended green solution")
	_expect(_game.get_flag("escape_prism_solved") and _room.architecture.locked_door.unlocked, "The solved signal reaches the real door and progression flag")
	_expect(_gate_blocks(), "Opening keeps its collision until the leaves clear")
	await create_timer(1.4).timeout
	await physics_frame
	_expect(_room.architecture.locked_door.is_open and not _gate_blocks(), "The animated doorway becomes physically walkable")
	_player.position = Vector3(10, 0, 0)
	await physics_frame
	var roman: Node3D = _room.get_node("Challenge5")
	_expect(_player._can_see(roman, roman.get_focus_position()), "The open doorway permits seeing the Roman station")
	_room.optics.exchange_item("B")
	_expect(_room.inventory.held_item == "prism" and not _room.optics.result.won, "A placed prism remains recoverable after solving")
	_expect(_room.architecture.locked_door.is_open and _game.get_flag("escape_prism_solved"), "Removing a prism does not relock a completed door")
	_games.ended.emit("newton", {"won": true})
	await process_frame
	_expect(_room.reward_pedestal.slots[0].slot_item == "" and _room.reward_pedestal.slots[1].slot_item == "", "Winning Egypt again never refills emptied reward cradles")


func _test_reload() -> void:
	var state: Dictionary = _room.optics.model.save_state()
	var expected_counts := _counts()
	_room.queue_free()
	await process_frame
	await _load_room()
	_expect(_room.inventory.held_item == "prism", "The held item survives a room reload")
	_expect(_room.optics.model.save_state() == state, "Lens positions, prism placement and turn settings survive a room reload")
	_expect(_room.reward_pedestal.is_revealed and _room.reward_pedestal.slots[0].slot_item == "" and _room.reward_pedestal.slots[1].slot_item == "", "Reload restores an exposed, already-collected reward pedestal")
	_expect(_room.architecture.locked_door.is_open and not _gate_blocks(), "Reload restores the completed door without replaying its animation")
	_expect(not _room.reward_reveal.active and not _player.cinematic_locked, "Reload does not repeat the reward camera move")
	_expect(_counts() == expected_counts, "Scene reconstruction conserves all items without duplicating the held prism")
	_room.reward_pedestal.slots[0].interact(_player)
	_expect(_room.inventory.held_item == "" and _room.reward_pedestal.slots[0].slot_item == "prism", "An emptied reward cradle remains usable as storage")
	_room.reward_pedestal.slots[0].interact(_player)
	_expect(_room.inventory.held_item == "prism" and _counts() == expected_counts, "Stored rewards can be recovered without item loss")


func _counts() -> Dictionary:
	var counts := {"prism": 0, "lens_yellow": 0, "lens_blue": 0}
	var items: Array = _room.optics.model.items.values()
	items.append(_room.inventory.held_item)
	for slot: Node in _room.reward_pedestal.slots:
		items.append(slot.slot_item)
	for item: String in items:
		if counts.has(item):
			counts[item] += 1
	return counts


func _gate_blocks() -> bool:
	return _ray(Vector3(10, 1.2, 0), Vector3(12, 1.2, 0))


func _ray(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [_player.get_rid()])
	return not _room.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _escape() -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = "back"
		event.pressed = pressed
		Input.parse_input_event(event)


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
