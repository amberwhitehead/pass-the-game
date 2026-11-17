extends SceneTree
## Real card actors and animation lifecycles, without launching the room/tutorial.
var _effects: GDScript
var _checks := 0
var _failures := 0
var _completed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 120
	_effects = load("res://minigames/cards/table_effects.gd")
	var table := Fixture.new()
	root.add_child(table)
	await process_frame
	var guard: Node3D = table.slot("enemy", 1)
	var destination: Node3D = table.slot("enemy", 0)
	var origin := guard.position
	var target := destination.position
	var defender := _card("sentinel", "Sentinel")
	guard.configure(defender)
	var intercept := {"type": "intercept", "side": "enemy", "lane": 1, "target_side": "enemy", "target_lane": 0}
	_completed = false
	_animate_before(table, intercept)
	await create_timer(.10).timeout
	_check(guard.position.x < origin.x and guard.position.x > target.x, "Sentinel visibly travels toward the threatened lane before completion")
	_check(guard.position.y > origin.y, "Intercept lifts the card off its mat")
	_check(guard.card_data == defender and destination.is_empty, "Movement animation cannot mutate card identity or rule state")
	await _wait_motion()
	_check(guard.position.is_equal_approx(origin) and destination.position.is_equal_approx(target), "Intercept restores both slot transforms before applying the snapshot")
	guard.set_empty("Lane 2", "enemy")
	destination.configure(defender)
	_check(destination.card_data.id == "sentinel" and guard.is_empty, "Post-interception snapshot occupies the intended destination")

	var first: Node3D = table.slot("player", 1)
	var second: Node3D = table.slot("player", 2)
	first.configure(_card("bruiser", "Bruiser"))
	second.configure(_card("forkshot", "Forkshot"))
	var first_start := first.position
	var second_start := second.position
	_completed = false
	_animate_before(table, {"type": "swap", "side": "player", "lane": 1, "target_side": "player", "target_lane": 2})
	await create_timer(.17).timeout
	_check(first.position.x > first_start.x and second.position.x < second_start.x, "Both swapped cards visibly travel toward the opposite slot")
	_check(second.position.y > first.position.y, "Swapped cards cross on separate-height arcs")
	await _wait_motion()
	_check(first.position.is_equal_approx(first_start) and second.position.is_equal_approx(second_start), "Swap restores reusable slot transforms without drift")
	first.configure(_card("forkshot", "Forkshot"))
	second.configure(_card("bruiser", "Bruiser"))
	_check(first.card_data.id == "forkshot" and second.card_data.id == "bruiser", "Post-swap snapshot presents exchanged identities in the original slots")

	_completed = false
	_animate_before(table, {"type": "attack", "side": "player", "lane": 1, "target_side": "enemy", "target_lane": 2, "direct": true})
	await create_timer(.08).timeout
	_check(first.position.x > first_start.x and first.position.z < first_start.z, "Diagonal attack lunges toward the actual opposing lane")
	var sparks := table.world.get_children().filter(func(node: Node): return node is MeshInstance3D and node != table.score_marker)
	_check(sparks.size() == 1, "Diagonal attack creates one directional tracer")
	if sparks.size() == 1:
		_check(sparks[0].position.x > first_start.x and sparks[0].position.x < table.lane_position("enemy", 2).x, "Tracer travels along the diagonal attack path")
	await _wait_motion()
	await process_frame
	_check(first.position.is_equal_approx(first_start), "Diagonal attack restores the attacker's slot")
	_check(table.world.get_children().filter(func(node: Node): return node is MeshInstance3D and node != table.score_marker).is_empty(), "Attack tracer is removed after impact")

	await _effects.after(table, {"type": "fatigue", "side": "player", "target_side": "enemy", "target_lane": -1, "direct": true, "amount": 2})
	var labels := table.world.get_children().filter(func(node: Node): return node is Label3D)
	_check(labels.size() == 1 and labels[0].text == "+2", "Enemy fatigue presents a positive score change for the player")
	_completed = false
	_animate_before(table, {"type": "swap", "side": "player", "lane": 1, "target_side": "player", "target_lane": 2})
	await create_timer(.05).timeout
	table.queue_free()
	await _wait_motion()
	_check(not is_instance_valid(table), "Leaving during movement removes the table and its transient visuals")
	print("Card motion: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures else 0)

func _animate_before(table: Control, event: Dictionary) -> void:
	await _effects.before(table, event)
	_completed = true

func _wait_motion() -> void:
	for frame in 240:
		if _completed:
			break
		await process_frame
	_check(_completed, "Animation await completes or is released when the table exits")

func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		push_error(message)

func _card(id: String, title: String) -> Dictionary:
	return {"id": id, "name": title, "kind": "unit", "cost": 2, "power": 1, "health": 8, "hp": 8, "max_hp": 8, "description": "Animation fixture."}

class Fixture extends Control:
	const Actor := preload("res://minigames/cards/card_actor.gd")
	var world: Node3D
	var score_marker: MeshInstance3D
	var _slots := {"player": [], "enemy": []}
	var hand_cards: Array = []

	func _ready() -> void:
		world = Node3D.new()
		add_child(world)
		for side: String in ["player", "enemy"]:
			for lane in 4:
				var actor := Actor.new()
				world.add_child(actor)
				actor.position = lane_position(side, lane)
				actor.set_empty("Lane %d" % (lane + 1), side)
				_slots[side].append(actor)
		score_marker = MeshInstance3D.new()
		world.add_child(score_marker)

	func slot(side: String, lane: int) -> Node3D:
		return _slots[side][lane] if lane >= 0 and lane < 4 else null

	func lane_position(side: String, lane: int) -> Vector3:
		return Vector3((lane - 1.5) * 1.25, .035, .55 if side == "player" else -.95)

	func draw_position() -> Vector3:
		return Vector3(-3.225, .3, 1.42)
