extends SceneTree
## Real hub interactions: reachability, duplicate protection, carrying, and re-entry.
const ROOM := "res://scenes/room/room.tscn"
const Progression := preload("res://minigames/cards/deck_progression.gd")
var checks := 0
var failures := 0
var _game: Node
var _room: Node3D
var _player: Node3D
var _collection_signals := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 120
	_game = root.get_node("Game")
	_game.flags.clear()
	_game.completed_minigames.clear()
	_game.collected_cards.clear()
	_game.card_collected.connect(func(_id: String): _collection_signals += 1)
	check(not _game.collect_card("scout"), "Ordinary cards cannot be collected as discoveries")
	check(not _game.collect_card("unknown"), "Unknown card IDs cannot pollute collection")
	check(_collection_signals == 0 and _game.collected_cards.is_empty(), "Rejected discovery emits no collection event")
	await _load_room()
	var cache: Node3D = _room.get_node("FoundCards")
	check(cache.get_child_count() == 5, "All five discoveries exist in a fresh hall")
	check(not _room.architecture.locked_door.unlocked, "Discoveries are reachable before the optical gate opens")
	# Use the real lens pickup so the held item is conserved, not a synthetic token.
	_room.optics.exchange_item("J")
	check(_room.inventory.held_item == "lens_yellow", "Carry fixture holds an actual room lens")
	var count := 0
	for pickup: Node3D in cache.get_children():
		var at: Vector3 = pickup.global_position
		check(absf(at.x) < 11 and absf(at.z) < 8, "%s is in the main hall, outside side-room gates" % pickup.card_id)
		var stand: Vector3 = at + pickup.global_basis.z * 1.35
		stand.y = 0
		_player.position = stand
		_player.camera.look_at(pickup.get_focus_position(), Vector3.UP)
		await physics_frame
		await physics_frame
		check(_player._can_see(pickup, pickup.get_focus_position()), "%s has unobstructed interaction line of sight" % pickup.card_id)
		check(_player.target == pickup, "%s can be targeted through actual player reach/cone filtering" % pickup.card_id)
		var press := InputEventAction.new()
		press.action = "interact"
		press.pressed = true
		_player._unhandled_input(press)
		count += 1
		check(_game.collected_cards.size() == count and pickup.card_id in _game.collected_cards, "%s joins the deck through the player interact route" % pickup.card_id)
		check(_room.inventory.held_item == "lens_yellow", "Collecting %s preserves the carried lens" % pickup.card_id)
		check(not pickup._available and pickup.collision_layer == 0, "%s disables its target immediately, before its animation ends" % pickup.card_id)
		pickup.interact(_player)
		check(not _game.collect_card(pickup.card_id) and _game.collected_cards.size() == count, "Duplicate %s interaction during animation cannot add a second copy" % pickup.card_id)
		check(_collection_signals == count, "Each accepted discovery emits exactly one signal")
		check(_room.hud._notice.text.contains(str(count) + " / 5"), "Discovery notice shows collection progress")
	check(Progression.owned(_game.collected_cards).size() == 5, "All collected IDs are recognized by shared deck progression")
	check(Progression.build(_game.collected_cards).size() == 17, "Five discoveries join the twelve-card base deck")
	# Re-enter while pickup tweens may still be active: state must already be durable.
	_room.queue_free()
	await process_frame
	await _load_room()
	check(_game.collected_cards.size() == 5, "Room recreation preserves session collection")
	check(_room.get_node("FoundCards").get_child_count() == 0, "Collected cards do not respawn on hub re-entry")
	check(_room.inventory.held_item == "lens_yellow", "Room recreation still preserves the separate carry item")
	_room.queue_free()
	await process_frame
	print("Card pickups: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _load_room() -> void:
	_room = load(ROOM).instantiate()
	root.add_child(_room)
	current_scene = _room
	_player = _room.get_node("Player")
	await physics_frame
	await physics_frame


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
