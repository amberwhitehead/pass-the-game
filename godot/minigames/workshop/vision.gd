extends RefCounted
## What the Futurescope shows: short scripted scenes played in the future copy of the room.
##
##   "loop"    Fuse (tangled in yarn, a lid on one ear) leaps on the lever and walks into
##             the portal: the scene the player has to make come true.
##   "cascade" After the loop closes, the remaining cat does it again, and again: more
##             cats tumble out of the portal.
##   "calm"    A quiet room: a cat sitting in a box. The loop is broken.

const Machine := preload("res://minigames/workshop/machine.gd")
const Cat := preload("res://minigames/workshop/cat.gd")
const Small := preload("res://minigames/workshop/small_props.gd")

## The dial setting the loop scene shows; the player must match it.
const LOOP_DIAL := 1
const TWIN_NAP := Vector2(760, 724)
const LEVER_WAIT := Vector2(1352, 700)


## Plays `scene` in `future` (a World); resolves when it ends.
static func play(future: Node2D, scene: String) -> void:
	var t: Dictionary = future.things
	_reset(future)
	match scene:
		"loop":
			await _loop(future, t)
		"cascade":
			await _cascade(future, t)
		"calm":
			await _calm(future, t)


static func _reset(future: Node2D) -> void:
	var t: Dictionary = future.things
	for c in future.get_children():
		if c.has_meta("extra"):
			c.queue_free()
	t.machine.portal = 0.0
	t.machine.portal_unstable = false
	t.machine.lever_down = false
	t.machine.powered = true
	t.machine.dial = LOOP_DIAL
	t.clock.frozen = true
	t.tv.has_tube = true
	t.radio.back_open = true
	t.radio.has_tube = false
	t.can.has_fuse = false
	t.basket.has_yarn = false
	t.fuse.visible = true
	t.fuse.modulate.a = 1.0
	t.fuse.scale = Vector2.ONE
	t.fuse.facing = -1.0


static func _extra_cat(future: Node2D, at: Vector2, pose: String) -> Node2D:
	var c := Cat.new()
	c.set_meta("extra", true)
	c.id = ""
	c.position = at
	c.pose = pose
	future.add_child(c)
	return c


static func _wait(node: Node, s: float) -> void:
	await node.get_tree().create_timer(s).timeout


## The cat leaps on the lever, the portal opens, and in it goes.
static func _leap_through(future: Node2D, m: Node2D, cat: Node2D) -> void:
	await _wait(future, 1.0)
	await cat.jump_to(Machine.LEVER_TOP, 90.0, 0.5, "crouch")
	m.lever_down = true
	await _wait(future, 0.2)
	await cat.jump_to(LEVER_WAIT + Vector2(10, 0), 40.0, 0.4)
	var tw := future.create_tween()
	tw.tween_property(m, "portal", 1.0, 0.8)
	await tw.finished
	cat.facing = 1.0
	await cat.walk_to(Machine.PORTAL_FLOOR.x - 10, Machine.PORTAL_FLOOR.y + 4, 140.0)
	tw = future.create_tween()
	tw.set_parallel()
	tw.tween_property(cat, "scale", Vector2(0.25, 0.25), 0.6)
	tw.tween_property(cat, "modulate:a", 0.0, 0.6)
	await tw.finished
	cat.visible = false


static func _loop(future: Node2D, t: Dictionary) -> void:
	var twin := _extra_cat(future, TWIN_NAP, "sleep")
	twin.displaced = true
	var cat: Node2D = t.fuse
	cat.yarn = true
	cat.lid = true
	cat.position = LEVER_WAIT
	cat.pose = "sit"
	cat.tail_mood = 2.5
	await _leap_through(future, t.machine, cat)
	var tw := future.create_tween()
	tw.tween_property(t.machine, "portal", 0.0, 0.6)
	await tw.finished
	await _wait(future, 0.8)


static func _cascade(future: Node2D, t: Dictionary) -> void:
	var cat: Node2D = t.fuse
	cat.yarn = true
	cat.lid = true
	cat.displaced = true
	cat.position = LEVER_WAIT
	cat.pose = "sit"
	cat.tail_mood = 3.0
	t.machine.portal_unstable = true
	await _leap_through(future, t.machine, cat)
	# ...and out they come.
	for k in 4:
		var c := _extra_cat(future, Machine.PORTAL_FLOOR + Vector2(-20, 4), "stand")
		c.yarn = true
		c.lid = k % 2 == 0
		c.displaced = true
		c.facing = -1.0
		c.walk_to(1100.0 - k * 150.0, 700.0 + (k % 2) * 40.0, 220.0)
		await _wait(future, 0.45)
	await _wait(future, 1.6)


static func _calm(future: Node2D, t: Dictionary) -> void:
	t.machine.powered = false
	t.clock.frozen = false
	var box := Small.Box.new()
	box.set_meta("extra", true)
	box.id = ""
	box.folded = true
	box.position = Vector2(760, 740)
	var cat: Node2D = t.fuse
	cat.yarn = true
	cat.lid = true
	cat.position = Vector2(760, 728)
	cat.pose = "sit"
	future.add_child(box)
	await _wait(future, 3.0)
