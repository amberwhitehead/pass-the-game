extends Node
## The Workshop's story: what each click does, in each phase.
##
##   setup   The Futurescope needs a tube (the radio has one). Tuned, it shows Fuse,
##           tangled in yarn with a sardine lid on one ear, leaping on the lever and
##           vanishing into the portal. Then the portal opens by itself and that very cat
##           walks out. The clock stops at that minute. Two cats; the Officer scoffs.
##   loop    Make the footage come true: the lid (sardines + can opener wake Fuse), the
##           red yarn (the basket has none: unwind it off the cat from the future), power
##           (the fuse is blown: bridge it with the pegboard's copper wire) and the
##           destination counter set to the minute the clock stopped. A flashlight on the
##           lever sends Fuse. Anything that doesn't match and the portal spits him out.
##   break   The loop closes, but the remaining cat wants another go. A box in the shade
##           won't tempt it; a box in the sunbeam will. Then pull the wire.
##   done    Won.
##
## Most clicks simply do things; the Engineer speaks only at story beats. Things that
## can't be done wiggle. `flags` holds everything saved; `apply_flags()` rebuilds the room.

signal won

const Machine := preload("res://minigames/workshop/machine.gd")
const Cat := preload("res://minigames/workshop/cat.gd")
const Person := preload("res://minigames/workshop/person.gd")
const Small := preload("res://minigames/workshop/small_props.gd")
const Vision := preload("res://minigames/workshop/vision.gd")
const Lines := preload("res://minigames/workshop/lines.gd")

const FUSE_NAP := Vector2(450, 330)      ## On top of the icebox.
const YARN_SPOT := Vector2(870, 764)
const OFFICER_SPOT := Vector2(860, 800)
## About how long after tuning the Futurescope the twin steps out (sets the stopped minute).
const ARRIVAL_DELAY := 20.0

var world: Node2D
var bubble: Node2D
var inventory: Node2D
var closeup: Node2D
var alarm: Node2D
var busy := false          ## True while a scene plays; clicks wait.

var flags := {
	"phase": "setup",
	"radio_on": false, "radio_open": false, "tube": "radio",   # radio, held, tv
	"tuned": false,
	"icebox_open": false, "tin": "icebox", "tin_pos": Vector2(700, 730), "tin_open": false,
	"drawer_open": false, "drawer_items": true,
	"wire": "board",       # board, held, machine, pulled
	"dial": 3 * 60, "arrival": -1, "lid": false, "yarn": false, "twin_yarn": true,
	"box": "wall", "box_pos": Vector2(700, 760),   # wall, held, floor
	"blinds": false,
	"items": [],
}

var twin: Node2D            ## The cat that walked out of the portal.
var _box_node: Node2D
var _w: Dictionary
var _mutters := 0
var _twin_in_box := false


func _ready() -> void:
	_w = world.things


# --- saving ---------------------------------------------------------------------------

func save_state() -> Dictionary:
	var out := flags.duplicate(true)
	out.items = inventory.items.duplicate()
	return out


func load_state(state: Dictionary) -> void:
	for k in state:
		if flags.has(k):
			flags[k] = state[k]
	flags.dial = int(flags.dial)
	flags.arrival = int(flags.arrival)
	if flags.tin_pos is not Vector2:
		flags.tin_pos = Vector2(700, 730)
	if flags.box_pos is not Vector2:
		flags.box_pos = Vector2(700, 760)
	# A scene interrupted midway resumes from the start of its phase.
	if flags.phase == "done":
		flags.phase = "break"


## Puts every prop, cat and item where the flags say.
func apply_flags() -> void:
	var f := flags
	inventory.items.clear()
	for it in f.items:
		inventory.add(str(it))
	_w.radio.playing = f.radio_on and f.tube == "radio"
	_w.radio.back_open = f.radio_open
	_w.radio.has_tube = f.tube == "radio"
	_w.tv.has_tube = f.tube == "tv"
	_w.tv.on = f.tube == "tv"
	_w.tv.tuned = f.tuned
	_w.icebox.open = f.icebox_open
	_w.icebox.has_tin = f.tin == "icebox"
	_w.tin.visible = f.tin == "floor"
	_w.tin.position = f.tin_pos
	_w.tin.opened = f.tin_open
	_w.tin.eaten = f.tin_open and f.lid
	_w.bench.drawer_open = f.drawer_open
	_w.bench.has_opener = f.drawer_items
	_w.bench.has_flashlight = f.drawer_items
	_w.wire.taken = f.wire != "board"
	_w.machine.powered = f.wire == "machine"
	_w.machine.fuse_blown = f.wire == "board" or f.wire == "held"
	_w.machine.dial = f.dial
	_w.blinds.open = f.blinds
	_w.box.visible = f.box == "wall"
	var fuse: Node2D = _w.fuse
	fuse.lid = f.lid
	fuse.yarn = f.yarn
	if f.phase in ["setup", "loop"]:
		if f.yarn:
			fuse.position = YARN_SPOT
			fuse.pose = "sit"
		elif f.lid:
			fuse.position = Vector2(f.tin_pos.x - 70, f.tin_pos.y - 4)
			fuse.pose = "sit"
		else:
			fuse.position = FUSE_NAP
			fuse.pose = "sleep"
	else:
		fuse.visible = false
	if f.box == "floor":
		_place_box(f.box_pos)
	if f.phase != "setup":
		_spawn_twin(Vision.TWIN_NAP, "sleep")
		twin.yarn = f.twin_yarn
		_w.clock.seconds = f.arrival * 60.0 + 20.0
		_w.clock.frozen = true
	if f.phase == "loop":
		alarm.mode = "violation"
		_w.tv.alarm = true
	if f.phase == "break":
		twin.displaced = false
		_w.machine.portal = 0.35
		_w.machine.portal_unstable = true
		alarm.mode = "instability"
		_w.clock.frozen = false
		if f.box == "floor" and _w.blinds.lit(f.box_pos):
			_place_box(f.box_pos)
			twin.position = f.box_pos + Vector2(0, -12)
			twin.pose = "sit"
			_raise_box()
			_twin_in_box = true
		else:
			twin.position = Vision.LEVER_WAIT
			twin.pose = "sit"
			twin.facing = -1.0
			twin.tail_mood = 3.0


func _spawn_twin(at: Vector2, pose: String) -> void:
	if twin == null:
		twin = Cat.new()
		twin.id = "twin"
		twin.hover_name = "Fuse?"
		twin.lid = true
		twin.yarn = true
		twin.displaced = true
		world.add_child(twin)
		world.move_child(twin, _w.fuse.get_index() + 1)
	twin.position = at
	twin.pose = pose


# --- helpers ----------------------------------------------------------------------------

func say(who: String, text: String, auto := 0.0) -> void:
	var node: Node2D = _w.engineer if who == "engineer" else _w.get("officer")
	var name := "The Engineer" if who == "engineer" else "The Officer"
	var tint := Color("fffaf0") if who == "engineer" else Color("f3f0d8")
	if node:
		node.talking = true
	var head := node.position + Vector2(30 * node.facing, -300) if node else Vector2(800, 400)
	await bubble.show_line(name, text, head, tint, auto, node.facing if node else 1.0)
	if node:
		node.talking = false


func says(who: String, lines: Array) -> void:
	for l in lines:
		await say(who, l)


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _engineer_gesture(g: String, at := Vector2.ZERO) -> void:
	_w.engineer.gesture = g
	_w.engineer.point_at = at


func take(item: String) -> void:
	inventory.add(item)
	flags.items = inventory.items.duplicate()
	Sound.play("pickup", self)


func use_up(item: String) -> void:
	inventory.remove(item)
	flags.items = inventory.items.duplicate()


## "That doesn't do anything": the thing wiggles, with a dull click.
func nope(id: String) -> void:
	var node: Node2D = _hotspot(id)
	Sound.play("unavailable", self, -8.0)
	if node == null:
		return
	var home := node.position
	var tw := create_tween()
	for dx in [6.0, -5.0, 3.0, 0.0]:
		tw.tween_property(node, "position", home + Vector2(dx, 0), 0.05)
	await tw.finished


func _hotspot(id: String) -> Node2D:
	for t in world.hotspots():
		if t.id == id:
			return t
	return null


# --- clicks -----------------------------------------------------------------------------

## The opening line, the first time the Workshop opens.
func intro() -> void:
	busy = true
	await wait(0.6)
	await says("engineer", Lines.INTRO)
	busy = false


func click(id: String, held: String, at: Vector2) -> void:
	if busy:
		return
	busy = true
	if held != "":
		await _use(held, id, at)
	else:
		await _poke(id, at)
	_engineer_gesture("idle")
	busy = false


func _poke(id: String, at: Vector2) -> void:
	var f := flags
	match id:
		"engineer":
			_mutters += 1
			await say("engineer", Lines.mutter(f.phase, _mutters))
		"fuse":
			await _pet(_w.fuse)
		"twin":
			if f.phase == "loop" and f.twin_yarn:
				await _unwind_twin()
			else:
				await _pet(twin)
		"radio":
			await _radio()
		"tv":
			await _tv()
		"icebox":
			_icebox()
		"drawer":
			_drawer()
		"wire":
			take("wire")
			_w.wire.taken = true
			f.wire = "held"
		"machine":
			await _machine()
		"dial":
			var wheel: int = _w.machine.dial_part.wheel_at(at)
			if wheel < 0:
				await nope("dial")
			else:
				_w.machine.turn_wheel(wheel)
				f.dial = _w.machine.dial
				Sound.play("dial_turn", self)
		"lever":
			await _lever_by_hand()
		"box":
			take("box")
			_w.box.visible = false
			f.box = "held"
		"placed_box":
			if _twin_in_box:
				await _pet(twin)
			else:
				take("box")
				_box_node.visible = false
				f.box = "held"
		"clock":
			await _zoom_clock()
		"blinds":
			f.blinds = not f.blinds
			_w.blinds.open = f.blinds
			Sound.play("dial_snap", self)
			if _box_tempts_twin():
				await wait(0.6)
				await _twin_to_box()
		_:
			await nope(id)


func _use(item: String, id: String, at: Vector2) -> void:
	var f := flags
	match [item, id]:
		["tube", "tv"]:
			use_up("tube")
			f.tube = "tv"
			_w.tv.has_tube = true
			_w.tv.on = true
			Sound.play("place", self)
			_engineer_gesture("cheer")
			await say("engineer", Lines.TUBE)
		["sardines", "floor"]:
			use_up("sardines")
			f.tin = "floor"
			f.tin_pos = Vector2(clampf(at.x, 600, 940), clampf(at.y, 700, 780))
			_w.tin.position = f.tin_pos
			_w.tin.visible = true
			Sound.play("place", self)
		["opener", "tin"]:
			await _open_sardines()
		["wire", "machine"]:
			use_up("wire")
			f.wire = "machine"
			_w.machine.fuse_blown = false
			_w.machine.powered = true
			Sound.play("lens_light", self)
			await wait(0.4)
			await say("engineer", Lines.WIRED)
		["yarn", "fuse"], ["yarn", "floor"]:
			await _tangle(at)
		["flashlight", "lever"]:
			await _lure_to_lever()
		["flashlight", "fuse"], ["flashlight", "twin"]:
			# The cat chases the spot for a moment.
			var cat: Node2D = _w.fuse if id == "fuse" else twin
			if cat.pose != "sleep":
				cat.tail_mood = 3.0
				await cat.jump_to(cat.position + Vector2(40 * cat.facing, 0), 50.0, 0.4, "sit")
			else:
				await nope(id)
		["box", "floor"]:
			await _place_box_scene(at)
		_:
			await nope(id)


func _pet(cat: Node2D) -> void:
	if cat == null:
		return
	if cat.pose == "sleep":
		_ear_flick(cat)
		return
	cat.tail_mood = 2.0
	Sound.play("card_hit", self, -10.0, 1.6)
	await wait(0.4)
	cat.tail_mood = 1.0


func _ear_flick(cat: Node2D) -> void:
	cat.set("_ear_flick", 0.3)


# --- setup ------------------------------------------------------------------------------

func _radio() -> void:
	var f := flags
	if f.tube != "radio":
		await nope("radio")
	elif not f.radio_on:
		f.radio_on = true
		_w.radio.playing = true
		_ear_flick(_w.fuse)
	elif not f.radio_open:
		f.radio_open = true
		_w.radio.back_open = true
		Sound.play("dial_snap", self)
	else:
		take("tube")
		f.tube = "held"
		_w.radio.has_tube = false
		_w.radio.playing = false
		f.radio_on = false


func _tv() -> void:
	var f := flags
	if f.tube != "tv":
		await nope("tv")
		return
	if not f.tuned:
		f.tuned = true
		_w.tv.tuned = true
		Sound.play("dial_turn", self)
		await wait(0.4)
		await _first_vision()
		return
	await _watch(_vision_for_phase(), "")


func _vision_for_phase() -> String:
	match flags.phase:
		"break":
			return "cascade"
		"done":
			return "calm"
	return "loop"


## Shows the Futurescope full screen while a scene plays in the future room.
func _watch(scene: String, caption: String) -> void:
	_w.tv.future.things.machine.dial = flags.arrival if flags.arrival >= 0 else _arrival_minute()
	closeup.open(_w.tv.feed_texture(), _w.tv.material(), caption)
	await Vision.play(_w.tv.future, scene)
	await closeup.close()


## The minute the twin will step out: shortly after the first vision ends.
func _arrival_minute() -> int:
	return int((_w.clock.seconds + ARRIVAL_DELAY) / 60.0) % 720


func _first_vision() -> void:
	_engineer_gesture("point", _w.tv.position + Vector2(920, 340))
	await wait(0.6)
	await _watch("loop", "")
	_engineer_gesture("think")
	await says("engineer", Lines.AFTER_VISION)
	await wait(0.6)
	await _arrival()


func _arrival() -> void:
	var m: Node2D = _w.machine
	flags.arrival = _arrival_minute()
	Sound.play("lens_light", self)
	var tw := create_tween()
	tw.tween_property(m, "portal", 1.0, 1.0)
	await tw.finished
	_spawn_twin(Machine.PORTAL_FLOOR + Vector2(-10, 4), "stand")
	twin.scale = Vector2(0.25, 0.25)
	twin.modulate.a = 0.0
	tw = create_tween().set_parallel()
	tw.tween_property(twin, "scale", Vector2(-1, 1), 0.6)
	tw.tween_property(twin, "modulate:a", 1.0, 0.6)
	await tw.finished
	twin.facing = -1.0
	# The moment it arrives, time stops.
	_w.clock.seconds = flags.arrival * 60.0 + 20.0
	_w.clock.frozen = true
	tw = create_tween()
	tw.tween_property(m, "portal", 0.0, 0.6)
	await twin.walk_to(Vision.TWIN_NAP.x, Vision.TWIN_NAP.y, 150.0)
	twin.pose = "sleep"
	await wait(0.5)
	_engineer_gesture("shrug")
	await wait(0.8)
	flags.phase = "loop"
	alarm.mode = "violation"
	_w.tv.alarm = true
	await _sirens()
	await wait(0.4)
	await _officer_visit(Lines.OFFICER_ARRIVES)
	_engineer_gesture("think")
	await says("engineer", Lines.AFTER_OFFICER)


## A few blasts of the alarm when it starts; the lights keep flashing after.
func _sirens(count := 3) -> void:
	for k in count:
		Sound.play("unavailable", self, 0.0, 0.8 if k % 2 == 0 else 1.0)
		await wait(0.42)


func _officer_visit(lines: Array) -> void:
	var o := Person.new()
	o.kind = "officer"
	o.position = OFFICER_SPOT
	o.facing = -1.0
	o.modulate.a = 0.0
	world.add_child(o)
	o.id = ""
	_w["officer"] = o
	Sound.play("door", self)
	var tw := create_tween()
	tw.tween_property(o, "modulate:a", 1.0, 0.5)
	await tw.finished
	await says("officer", lines)
	tw = create_tween()
	tw.tween_property(o, "modulate:a", 0.0, 0.5)
	await tw.finished
	_w.erase("officer")
	o.queue_free()


# --- making the loop --------------------------------------------------------------------

func _icebox() -> void:
	var f := flags
	if not f.icebox_open:
		f.icebox_open = true
		_w.icebox.open = true
		Sound.play("place", self)
	elif f.tin == "icebox":
		f.tin = "held"
		_w.icebox.has_tin = false
		take("sardines")
	else:
		f.icebox_open = false
		_w.icebox.open = false
		Sound.play("place", self)


func _drawer() -> void:
	var f := flags
	if not f.drawer_open:
		f.drawer_open = true
		_w.bench.drawer_open = true
		Sound.play("card_draw", self)
	elif f.drawer_items:
		f.drawer_items = false
		_w.bench.has_opener = false
		_w.bench.has_flashlight = false
		take("opener")
		take("flashlight")
	else:
		f.drawer_open = false
		_w.bench.drawer_open = false
		Sound.play("card_draw", self)


func _open_sardines() -> void:
	var f := flags
	if f.tin_open:
		await nope("tin")
		return
	use_up("opener")
	f.tin_open = true
	_w.tin.opened = true
	Sound.play("dial_snap", self)
	var fuse: Node2D = _w.fuse
	if not fuse.visible or fuse.pose != "sleep":
		return
	await wait(0.4)
	fuse.pose = "sit"
	await wait(0.5)
	await fuse.jump_to(Vector2(560, 720), 60.0, 0.6)
	await fuse.walk_to(f.tin_pos.x - 70, f.tin_pos.y - 4)
	fuse.facing = 1.0
	fuse.pose = "eat"
	await wait(1.6)
	_w.tin.eaten = true
	fuse.lid = true
	f.lid = true
	Sound.play("card_hit", self)
	fuse.pose = "sit"
	await wait(0.3)
	await say("engineer", Lines.LID)


## The only red yarn in the room is on the cat from the future. Unwind it.
func _unwind_twin() -> void:
	flags.twin_yarn = false
	twin.pose = "sit"
	twin.tail_mood = 3.0
	Sound.play("card_draw", self)
	await wait(0.5)
	twin.yarn = false
	take("yarn")
	await wait(0.4)
	twin.tail_mood = 1.0
	twin.pose = "sleep"
	await say("engineer", Lines.UNWOUND)


## Red yarn for an awake Fuse: a ball rolls, a cat pounces, a cat is tangled.
func _tangle(at: Vector2) -> void:
	var f := flags
	var fuse: Node2D = _w.fuse
	if f.yarn or not fuse.visible or fuse.pose == "sleep":
		await nope("fuse")
		return
	use_up("yarn")
	var ball := YarnBall.new()
	ball.position = Vector2(clampf(at.x, 600, 1000), 700)
	world.add_child(ball)
	var tw := create_tween()
	tw.tween_property(ball, "position", YARN_SPOT + Vector2(10, -4), 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Sound.play("card_hit", self)
	await tw.finished
	fuse.pose = "crouch"
	fuse.facing = signf(YARN_SPOT.x - fuse.position.x) if absf(YARN_SPOT.x - fuse.position.x) > 1.0 else 1.0
	await wait(0.4)
	await fuse.jump_to(YARN_SPOT, 80.0, 0.55)
	ball.queue_free()
	fuse.yarn = true
	f.yarn = true
	fuse.pose = "sit"


func _machine() -> void:
	var f := flags
	if f.phase == "break" and f.wire == "machine":
		if _twin_in_box:
			await _finale()
		else:
			await _twin_guards_lever()
		return
	await nope("machine")


func _lever_by_hand() -> void:
	# It won't budge for you: in the footage, it was the cat that pulled it.
	await nope("lever")


## Flashlight on the lever: Fuse pounces. Whether the portal accepts him depends on how
## closely this moment matches the Futurescope's footage.
func _lure_to_lever() -> void:
	var f := flags
	var fuse: Node2D = _w.fuse
	if f.phase != "loop" or not fuse.visible or fuse.pose == "sleep":
		await nope("lever")
		return
	var dot := LightSpot.new()
	dot.position = Machine.LEVER_TOP + Vector2(0, 10)
	world.add_child(dot)
	fuse.pose = "stand"
	await fuse.walk_to(Vision.LEVER_WAIT.x, Vision.LEVER_WAIT.y)
	fuse.facing = -1.0
	fuse.pose = "sit"
	fuse.tail_mood = 2.5
	await wait(0.7)
	dot.queue_free()
	await fuse.jump_to(Machine.LEVER_TOP, 90.0, 0.5, "crouch")
	_w.machine.lever_down = true
	Sound.play("dial_snap", self)
	await wait(0.2)
	await fuse.jump_to(Vision.LEVER_WAIT + Vector2(10, 0), 40.0, 0.4)
	if f.wire != "machine":
		# Nothing happens. The cat looks at you.
		await wait(0.8)
		_w.machine.lever_down = false
		fuse.tail_mood = 1.0
		return
	var tw := create_tween()
	tw.tween_property(_w.machine, "portal", 1.0, 0.8)
	Sound.play("lens_light", self)
	await tw.finished
	fuse.facing = 1.0
	await fuse.walk_to(Machine.PORTAL_FLOOR.x - 10, Machine.PORTAL_FLOOR.y + 4, 140.0)
	if not matches_footage():
		await _rejected(fuse)
		return
	tw = create_tween().set_parallel()
	tw.tween_property(fuse, "scale", Vector2(0.25, 0.25), 0.6)
	tw.tween_property(fuse, "modulate:a", 0.0, 0.6)
	await tw.finished
	fuse.visible = false
	tw = create_tween()
	tw.tween_property(_w.machine, "portal", 0.0, 0.6)
	await tw.finished
	_w.machine.lever_down = false
	# The loop is closed.
	alarm.mode = ""
	_w.tv.alarm = false
	_w.clock.frozen = false
	twin.displaced = false
	Sound.play("victory", self)
	_engineer_gesture("cheer")
	await say("engineer", Lines.LOOP_CLOSED)
	_engineer_gesture("idle")
	await wait(0.8)
	await _cascade()


## True when the cat, the machine and the destination match the footage.
func matches_footage() -> bool:
	var f := flags
	return f.lid and f.yarn and f.wire == "machine" and f.dial == f.arrival


## The portal flares red and throws the cat back out.
func _rejected(fuse: Node2D) -> void:
	var f := flags
	_w.machine.portal_unstable = true
	# Whatever differs from the footage flickers for a moment.
	if f.dial != f.arrival:
		_w.machine.dial_wrong = 4.0
	if not f.yarn or not f.lid:
		fuse.ghost = 4.0
	Sound.play("unavailable", self, 0.0, 0.7)
	await wait(0.5)
	fuse.facing = -1.0
	await fuse.jump_to(Vision.LEVER_WAIT + Vector2(-90, 10), 70.0, 0.45, "crouch")
	fuse.tail_mood = 4.0
	var tw := create_tween()
	tw.tween_property(_w.machine, "portal", 0.0, 0.5)
	await tw.finished
	_w.machine.portal_unstable = false
	_w.machine.lever_down = false
	await wait(0.4)
	fuse.pose = "sit"
	fuse.tail_mood = 1.0
	_engineer_gesture("shrug")
	await say("engineer", Lines.REJECTED)


# --- breaking the loop ------------------------------------------------------------------

func _cascade() -> void:
	flags.phase = "break"
	_w.tv.tuned = false
	await _sirens(2)
	_w.tv.tuned = true
	await _watch("cascade", "")
	alarm.mode = "instability"
	_w.machine.portal_unstable = true
	var tw := create_tween()
	tw.tween_property(_w.machine, "portal", 0.35, 0.8)
	_engineer_gesture("shrug")
	await says("engineer", Lines.CASCADE)
	twin.pose = "stand"
	await twin.walk_to(Vision.LEVER_WAIT.x, Vision.LEVER_WAIT.y)
	twin.facing = -1.0
	twin.pose = "sit"
	twin.tail_mood = 3.0
	if _box_tempts_twin():
		# A box was already waiting in the sun. Irresistible.
		await wait(1.2)
		await _twin_to_box()


## Reaching for the fuse while the cat watches: it leaps onto the lever first.
func _twin_guards_lever() -> void:
	await twin.jump_to(Machine.LEVER_TOP, 90.0, 0.45, "crouch")
	_w.machine.lever_down = true
	_w.machine.portal = 0.6
	Sound.play("unavailable", self, 0.0, 0.7)
	await wait(0.6)
	await twin.jump_to(Vision.LEVER_WAIT, 40.0, 0.4, "sit")
	_w.machine.lever_down = false
	var tw := create_tween()
	tw.tween_property(_w.machine, "portal", 0.35, 0.6)
	await tw.finished


func _place_box_scene(at: Vector2) -> void:
	var f := flags
	use_up("box")
	f.box = "floor"
	f.box_pos = Vector2(clampf(at.x, 560, 1100), clampf(at.y, 720, 790))
	_place_box(f.box_pos)
	Sound.play("place", self)
	if not _box_tempts_twin():
		# In the shade, or nobody's in the mood: it just sits there.
		if f.phase == "break":
			_ear_flick(twin)
		return
	await wait(0.6)
	await _twin_to_box()


## The restless cat ignores a box in the shade; a box in the sunbeam is too much.
func _box_tempts_twin() -> bool:
	var f := flags
	return f.phase == "break" and f.box == "floor" and not _twin_in_box and _w.blinds.lit(f.box_pos)


func _twin_to_box() -> void:
	var f := flags
	twin.tail_mood = 1.0
	twin.pose = "stand"
	await twin.walk_to(f.box_pos.x + 90, f.box_pos.y - 12)
	await twin.jump_to(f.box_pos + Vector2(0, -12), 70.0, 0.5, "sit")
	_raise_box()
	_twin_in_box = true


func _place_box(p: Vector2) -> void:
	if _box_node == null:
		_box_node = Small.Box.new()
		_box_node.id = "placed_box"
		_box_node.hover_name = "Box"
		_box_node.hit_rect = Rect2(-70, -90, 140, 95)
		_box_node.folded = true
		world.add_child(_box_node)
	_box_node.position = p
	_box_node.visible = true


## Moves the box in front of the cat sitting in it.
func _raise_box() -> void:
	if _box_node and twin:
		world.move_child(_box_node, twin.get_index() + 1)


func _finale() -> void:
	var f := flags
	f.wire = "pulled"
	take("wire")
	_w.machine.powered = false
	var tw := create_tween()
	tw.tween_property(_w.machine, "portal", 0.0, 0.8)
	await tw.finished
	_w.machine.portal_unstable = false
	alarm.mode = ""
	await wait(0.5)
	await _watch("calm", "")
	f.phase = "done"
	_engineer_gesture("cheer")
	await says("engineer", Lines.FINALE)
	await _officer_visit(Lines.OFFICER_LEAVES)
	_engineer_gesture("idle")
	await say("engineer", Lines.GOODBYE)
	won.emit()


## A close look at the clock: it grows to fill the room until the next click.
func _zoom_clock() -> void:
	var clock: Node2D = _w.clock
	var scrim := Scrim.new()
	world.add_child(scrim)
	clock.z_index = 45
	var s := 4.2
	var tw := create_tween().set_parallel()
	tw.tween_property(clock, "scale", Vector2(s, s), 0.35)
	tw.tween_property(clock, "position", Vector2(800, 450) - Vector2(1150, 150) * s, 0.35)
	tw.tween_property(scrim, "modulate:a", 1.0, 0.35).from(0.0)
	await tw.finished
	await bubble.wait_click()
	tw = create_tween().set_parallel()
	tw.tween_property(clock, "scale", Vector2.ONE, 0.3)
	tw.tween_property(clock, "position", Vector2.ZERO, 0.3)
	tw.tween_property(scrim, "modulate:a", 0.0, 0.3)
	await tw.finished
	clock.z_index = 0
	scrim.queue_free()


class Scrim extends Node2D:
	func _ready() -> void:
		z_index = 44

	func _draw() -> void:
		draw_rect(Rect2(-100, -100, 1800, 1100), Color(0.08, 0.05, 0.04, 0.8))


## The ball of yarn while it rolls across the floor.
class YarnBall extends "res://minigames/workshop/thing.gd":
	func _paint() -> void:
		Small.Basket.yarn_ball(self, Vector2.ZERO, 22, 130)


## The flashlight's spot dancing on the lever.
class LightSpot extends Node2D:
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var p := Vector2(sin(_t * 7.0) * 8.0, cos(_t * 5.0) * 6.0)
		draw_circle(p, 22, Color(1, 1, 0.85, 0.25))
		draw_circle(p, 12, Color(1, 1, 0.85, 0.6))
