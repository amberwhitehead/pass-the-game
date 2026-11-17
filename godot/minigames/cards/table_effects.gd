extends RefCounted
## Animations use tabletop coordinates and never modify match rules.
const Motion := preload("res://minigames/cards/table_motion.gd")
const Catalog := preload("res://minigames/cards/card_catalog.gd")

static func before(table: Control, event: Dictionary) -> void:
	if event.type == "spell":
		var target: Node3D = table.slot(event.target_side, int(event.target_lane))
		if target != null:
			var healing: bool = Catalog.get_card(str(event.get("card", ""))).get("kind", "") == "heal"
			var color := Color("82e4b9") if healing else Color("ff976d")
			await _spell(table, target.position, color)
		return
	var source: Node3D = table.slot(event.get("side", "player"), int(event.get("lane", -1)))
	if source == null:
		return
	if event.type in ["intercept", "swap"]:
		await _reposition(table, source, event)
	elif event.type == "attack":
		await _attack(table, source, event)
	elif event.type == "death":
		var original := source.scale
		await _motion(table, .20, func(t: float):
			if is_instance_valid(source):
				source.scale = original.lerp(Vector3.ONE * .02, t * t)
		, func():
			if is_instance_valid(source):
				source.scale = original)

static func after(table: Control, event: Dictionary) -> void:
	var source: Node3D = table.slot(event.get("side", "player"), int(event.get("lane", -1)))
	var kind: String = event.type
	if kind in ["play", "enemy_play"] and source != null:
		var destination := source.position
		await _move(table, source, Vector3(0, .8, 2.0 if event.side == "player" else -2.5), destination, .32)
	elif kind == "draw" and not event.get("burned", false) and not table.hand_cards.is_empty():
		var card: Node3D = table.hand_cards.back()
		var start: Vector3 = card.get_parent().to_local(table.world.to_global(table.draw_position()))
		await _move(table, card, start, card.position, .26)
	elif kind in ["intercept", "swap"]:
		var destination: Node3D = table.slot(event.target_side, int(event.target_lane))
		if destination != null:
			destination.pulse(Color("a4d9cc") if kind == "intercept" else Color("e6c980"))
	elif kind in ["attack", "spell", "heal", "fatigue"]:
		var target: Node3D = table.slot(event.get("target_side", "enemy"), int(event.get("target_lane", -1)))
		var healing: bool = kind == "heal" or (kind == "spell" and Catalog.get_card(str(event.get("card", ""))).get("kind", "") == "heal")
		var positive := healing
		if target == null or event.get("direct", false):
			target = table.score_marker
			positive = event.get("side", "enemy") == "player"
		var color := Color("82e4b9") if positive else Color("ff976d")
		if target.has_method("pulse"):
			target.pulse(color)
		_float(table, table.world.to_local(target.global_position), int(event.get("amount", 0)), positive, color)
	elif kind == "victory":
		table.world.react(event.side == "player")

static func _spell(table: Control, target: Vector3, color: Color) -> void:
	var orb := _spark(table, color, .085)
	var start := Vector3(0, .6, 2.4)
	await _motion(table, .25, func(t: float):
		if is_instance_valid(orb):
			orb.position = start.lerp(target + Vector3(0, .15, 0), t)
	, func():
		if is_instance_valid(orb):
			orb.queue_free())

static func _spark(table: Control, color: Color, radius: float) -> MeshInstance3D:
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	orb.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	orb.material_override = material
	table.world.add_child(orb)
	return orb

static func _reposition(table: Control, source: Node3D, event: Dictionary) -> void:
	var target: Node3D = table.slot(event.target_side, int(event.target_lane))
	if target == null:
		return
	var start := source.position
	var finish := target.position
	var swapping: bool = event.type == "swap"
	await _motion(table, .42 if swapping else .34, func(t: float):
		var progress := t * t * (3.0 - 2.0 * t)
		if is_instance_valid(source):
			source.position = start.lerp(finish, progress) + Vector3(0, sin(t * PI) * .12, sin(t * PI) * .12 if swapping else 0.0)
		if swapping and is_instance_valid(target):
			target.position = finish.lerp(start, progress) + Vector3(0, sin(t * PI) * .38, -sin(t * PI) * .12)
	, func():
		# Actors belong to slots, while rule snapshots own card identity. Restore the
		# slot transforms before the controller applies the post-movement snapshot.
		if is_instance_valid(source):
			source.position = start
		if swapping and is_instance_valid(target):
			target.position = finish)

static func _attack(table: Control, source: Node3D, event: Dictionary) -> void:
	var original := source.position
	var target: Vector3 = table.lane_position(event.target_side, int(event.target_lane))
	var direction := (target - original).normalized()
	var diagonal: bool = int(event.lane) != int(event.target_lane)
	var spark: MeshInstance3D = _spark(table, Color("e7cf8c") if event.side == "player" else Color("e59a73"), .055) if diagonal else null
	var struck := [false]
	await _motion(table, .32, func(t: float):
		if is_instance_valid(source):
			source.position = original + direction * sin(t * PI) * .42 + Vector3.UP * sin(t * PI) * .14
		if is_instance_valid(spark):
			spark.position = original.lerp(target, minf(t * 2, 1)) + Vector3.UP * .17
			spark.visible = t < .55
		if t >= .5 and not struck[0] and is_instance_valid(table):
			struck[0] = true
			Sound.play("card_direct" if event.get("direct", false) else "card_hit", table)
	, func():
		if is_instance_valid(source):
			source.position = original
		if is_instance_valid(spark):
			spark.queue_free())

static func _move(table: Control, actor: Node3D, start: Vector3, finish: Vector3, duration: float) -> void:
	await _motion(table, duration, func(t: float):
		if is_instance_valid(actor):
			actor.position = start.lerp(finish, 1.0 - pow(1.0 - t, 3))
	, func():
		if is_instance_valid(actor):
			actor.position = finish)

static func _motion(table: Control, duration: float, update: Callable, cleanup: Callable) -> void:
	var motion := Motion.new()
	table.add_child(motion)
	motion.play(duration, update, cleanup)
	await motion.finished

static func _float(table: Control, origin: Vector3, amount: int, positive: bool, color: Color) -> void:
	if amount == 0:
		return
	var label := Label3D.new()
	label.text = ("+" if positive else "−") + str(amount)
	label.font_size = 80
	label.pixel_size = 0.004
	label.modulate = color
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	table.world.add_child(label)
	label.position = origin + Vector3(0, 0.35, 0)
	var tween := table.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 0.6, 0.75)
	tween.tween_property(label, "modulate:a", 0.0, 0.75)
	tween.chain().tween_callback(label.queue_free)
