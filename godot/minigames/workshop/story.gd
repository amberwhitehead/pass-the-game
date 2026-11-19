extends Node
## The Workshop's story: what each click does, in each phase.
##
##   setup   Repair the Futurescope (the radio's tube) and tune it. It shows Fuse, tangled
##           in yarn with a sardine lid on one ear, leaping on the lever and vanishing into
##           the portal. Then the portal opens by itself and that very cat walks out:
##           two cats, sirens, and the Officer.
##   loop    Make the footage come true: sardines (the lid), the knitting basket (the yarn),
##           the coffee-can fuse (power), the dial setting, and a flashlight on the lever.
##   break   The loop closes, but the remaining cat wants another go. Lure it into a box,
##           then pull the fuse.
##   done    Won.
##
## `flags` holds everything saved; `apply_flags()` rebuilds the room from it.

signal won

const Machine := preload("res://minigames/workshop/machine.gd")
const Cat := preload("res://minigames/workshop/cat.gd")
const Person := preload("res://minigames/workshop/person.gd")
const Small := preload("res://minigames/workshop/small_props.gd")
const Vision := preload("res://minigames/workshop/vision.gd")
const Items := preload("res://minigames/workshop/items.gd")
const Lines := preload("res://minigames/workshop/lines.gd")

const FUSE_NAP := Vector2(450, 330)      ## On top of the icebox.
const OFFICER_SPOT := Vector2(1010, 800)

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
	"icebox_open": false, "tin": "icebox", "tin_pos": Vector2(640, 730), "tin_open": false,
	"drawer_open": false, "drawer_items": true,
	"fuse_part": "can",    # can, held, machine, pulled
	"dial": 0, "lid": false, "yarn": false,
	"box": "wall", "box_pos": Vector2(700, 760),   # wall, held, floor
	"blinds": false,
	"items": [],
}

var twin: Node2D            ## The cat that walked out of the portal.
var _box_node: Node2D
var _w: Dictionary


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
	if flags.tin_pos is not Vector2:
		flags.tin_pos = Vector2(640, 730)
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
	_w.tin.eaten = f.tin_open
	_w.bench.drawer_open = f.drawer_open
	_w.bench.has_opener = f.drawer_items
	_w.bench.has_flashlight = f.drawer_items
	_w.can.has_fuse = f.fuse_part == "can"
	_w.machine.powered = f.fuse_part == "machine"
	_w.machine.dial = f.dial
	_w.basket.has_yarn = not f.yarn
	_w.blinds.open = f.blinds
	_w.box.visible = f.box == "wall"
	var fuse: Node2D = _w.fuse
	fuse.lid = f.lid
	fuse.yarn = f.yarn
	if f.phase in ["setup"]:
		fuse.position = FUSE_NAP
		fuse.pose = "sleep"
	elif f.phase == "loop":
		if f.tin_open:
			fuse.position = Vector2(870, 764) if f.yarn else Vector2(f.tin_pos.x - 70, f.tin_pos.y - 4)
			fuse.pose = "sit"
		else:
			fuse.position = FUSE_NAP
			fuse.pose = "sleep"
	else:
		fuse.visible = false
	if f.phase != "setup":
		_spawn_twin(Vision.TWIN_NAP, "sleep")
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
		if f.box == "floor":
			_place_box(f.box_pos)
			twin.position = f.box_pos + Vector2(0, -12)
			twin.pose = "sit"
			_raise_box()
		else:
			twin.position = Vision.LEVER_WAIT
			twin.pose = "sit"
			twin.facing = -1.0
			twin.tail_mood = 3.0


func _spawn_twin(at: Vector2, pose: String) -> void:
	if twin == null:
		twin = Cat.new()
		twin.id = "twin"
		twin.hover_name = "Fuse (from the future)"
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


func use_up(item: String) -> void:
	inventory.remove(item)
	flags.items = inventory.items.duplicate()


# --- clicks -----------------------------------------------------------------------------

## The opening lines, the first time the Workshop opens.
func intro() -> void:
	busy = true
	_engineer_gesture("shrug")
	await says("engineer", Lines.INTRO)
	_engineer_gesture("idle")
	busy = false


func click(id: String, held: String, at: Vector2) -> void:
	if busy:
		return
	busy = true
	if held != "":
		await _use(held, id, at)
	else:
		await _poke(id)
	_engineer_gesture("idle")
	busy = false


func _poke(id: String) -> void:
	var f := flags
	if f.phase == "setup" and id in ["icebox", "drawer", "can", "basket", "box"]:
		await say("engineer", "Later, later. First let's get the Futurescope working.")
		return
	match id:
		"engineer":
			await say("engineer", Lines.hint(self))
		"fuse":
			if f.phase == "loop" and not f.tin_open:
				await say("engineer", "Fuse sleeps through anything. Except a can opener.")
			elif f.phase == "loop":
				await say("engineer", "He's watching your every move. Cats know when they're in a paradox.")
			else:
				await say("engineer", "That's Fuse. Named after my favourite component. Don't wake him.")
		"twin":
			if f.phase == "break":
				await say("engineer", "Look at him staring at that lever. He wants another go.")
			else:
				await say("engineer", "Same cat. Same stripes. Same lid. He's from up ahead somewhere, and he's very pleased with himself.")
		"radio":
			await _radio()
		"tv":
			await _tv()
		"icebox":
			await _icebox()
		"drawer":
			await _drawer()
		"can":
			if f.fuse_part == "can":
				take("fuse")
				_w.can.has_fuse = false
				f.fuse_part = "held"
				await say("engineer", "A fuse! No, not that Fuse. The other fuse.")
			else:
				await say("engineer", "Just washers and a bottle cap now.")
		"basket":
			await _basket()
		"tin":
			await say("engineer", "Sardines. Fuse's one weakness. Well, one of four.")
		"machine":
			await _machine()
		"dial":
			_w.machine.dial += 1
			f.dial = _w.machine.dial
			Sound.play("dial_turn", self)
		"lever":
			_engineer_gesture("shrug")
			if f.phase == "setup":
				await say("engineer", "Nothing happens without power. Thank goodness.")
			elif f.phase == "loop":
				await say("engineer", "Not us! On the Futurescope it was Fuse who pulled it. It has to happen exactly that way.")
			else:
				await say("engineer", "Don't touch it. Don't even look at it. HE is looking at it.")
		"portal":
			await say("engineer", Lines.portal(self))
		"box":
			take("box")
			_w.box.visible = false
			f.box = "held"
			await say("engineer", "Fuse's favourite box. He's very particular about it.")
		"blinds":
			f.blinds = not f.blinds
			_w.blinds.open = f.blinds
			Sound.play("dial_snap", self)
		"clock":
			if _w.clock.frozen:
				await say("engineer", "Stuck. The second hand's twitching but it can't get past this minute.")
			else:
				await say("engineer", "Ticking along again. Bless it.")


func _use(item: String, id: String, at: Vector2) -> void:
	var f := flags
	match [item, id]:
		["tube", "tv"]:
			use_up("tube")
			f.tube = "tv"
			_w.tv.has_tube = true
			_w.tv.on = true
			Sound.play("place", self)
			await say("engineer", "It's warming up! Give the tuning knob a turn.")
		["sardines", "floor"]:
			use_up("sardines")
			f.tin = "floor"
			f.tin_pos = Vector2(clampf(at.x, 600, 940), clampf(at.y, 700, 780))
			_w.tin.position = f.tin_pos
			_w.tin.visible = true
			Sound.play("place", self)
		["opener", "tin"], ["opener", "sardines"]:
			if id == "sardines" or f.tin != "floor":
				await say("engineer", "Put the tin down first. Nobody eats over my workbench.")
			else:
				await _open_sardines()
		["fuse", "machine"]:
			use_up("fuse")
			f.fuse_part = "machine"
			_w.machine.powered = true
			Sound.play("place", self)
			await say("engineer", "Listen to her hum!")
		["flashlight", "lever"]:
			await _lure_to_lever()
		["flashlight", _]:
			await say("engineer", "Fuse chases that light anywhere. Point it somewhere useful.")
		["box", "floor"]:
			await _place_box_scene(at)
		["box", _]:
			await say("engineer", "Put it on the floor. Cats like a box where they can be admired.")
		_:
			await say("engineer", Lines.no_use(item, id))


# --- setup ------------------------------------------------------------------------------

func _radio() -> void:
	var f := flags
	if f.tube != "radio":
		await say("engineer", "Silent. I'll buy another tube. Eventually.")
	elif not f.radio_on:
		f.radio_on = true
		_w.radio.playing = true
		await say("engineer", "Ah, the Hit Parade! This radio's never missed a beat. Its back panel's loose, mind.")
	elif not f.radio_open:
		f.radio_open = true
		_w.radio.back_open = true
		Sound.play("dial_snap", self)
		await say("engineer", "Look at those tubes. Lovely warm glow. One looks just about the Futurescope's size...")
	else:
		take("tube")
		f.tube = "held"
		_w.radio.has_tube = false
		_w.radio.playing = false
		f.radio_on = false
		Sound.play("pickup", self)
		await say("engineer", "Goodbye, Hit Parade. Science requires sacrifice.")


func _tv() -> void:
	var f := flags
	if f.tube != "tv":
		_engineer_gesture("point", _w.tv.position + Vector2(920, 340))
		await says("engineer", Lines.TV_BROKEN)
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
	closeup.open(_w.tv.feed_texture(), _w.tv.material(), caption)
	await Vision.play(_w.tv.future, scene)
	await closeup.close()


func _first_vision() -> void:
	await say("engineer", "There! The Futurescope. It shows what's going to happen. Let's see what's coming...", 2.2)
	await _watch("loop", "THE FUTURE")
	_engineer_gesture("think")
	await says("engineer", Lines.AFTER_VISION)
	await wait(0.6)
	await _arrival()


func _arrival() -> void:
	var m: Node2D = _w.machine
	Sound.play("lens_light", self)
	var tw := create_tween()
	tw.tween_property(m, "portal", 1.0, 1.0)
	await tw.finished
	_spawn_twin(Machine.PORTAL_FLOOR + Vector2(-10, 4), "stand")
	twin.scale = Vector2(0.25, 0.25)
	twin.modulate.a = 0.0
	twin.facing = -1.0
	tw = create_tween().set_parallel()
	tw.tween_property(twin, "scale", Vector2(-1, 1), 0.6)
	tw.tween_property(twin, "modulate:a", 1.0, 0.6)
	await tw.finished
	twin.facing = -1.0
	tw = create_tween()
	tw.tween_property(m, "portal", 0.0, 0.6)
	await twin.walk_to(Vision.TWIN_NAP.x, Vision.TWIN_NAP.y, 150.0)
	twin.pose = "sleep"
	await wait(0.5)
	_engineer_gesture("shrug")
	await say("engineer", "...")
	await wait(0.4)
	flags.phase = "loop"
	alarm.mode = "violation"
	_w.tv.alarm = true
	_w.clock.frozen = true
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
	o.id = ""
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


# --- loop -------------------------------------------------------------------------------

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
		Sound.play("pickup", self)
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
		Sound.play("pickup", self)
	else:
		f.drawer_open = false
		_w.bench.drawer_open = false
		Sound.play("card_draw", self)


func _open_sardines() -> void:
	var f := flags
	use_up("opener")
	f.tin_open = true
	_w.tin.opened = true
	Sound.play("dial_snap", self)
	if f.phase == "setup":
		await say("engineer", "Mm. Smells like Tuesday.")
		return
	var fuse: Node2D = _w.fuse
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
	await say("engineer", "There it is! The lid, right on his ear. Just like on the Futurescope.")


func _basket() -> void:
	var f := flags
	if f.yarn:
		await say("engineer", "My knitting. It's a tea cosy. Don't judge.")
		return
	if f.phase != "loop" or not f.tin_open:
		await say("engineer", "Fuse wouldn't wake up for yarn. He'd want something that smells better.")
		return
	var fuse: Node2D = _w.fuse
	_w.basket.has_yarn = false
	var ball := YarnBall.new()
	ball.position = Vector2(935, 600)
	world.add_child(ball)
	var tw := create_tween()
	tw.tween_property(ball, "position", Vector2(880, 760), 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Sound.play("card_hit", self)
	fuse.pose = "crouch"
	fuse.facing = signf(880 - fuse.position.x)
	await wait(0.6)
	await fuse.jump_to(Vector2(870, 764), 80.0, 0.55)
	ball.queue_free()
	fuse.yarn = true
	f.yarn = true
	fuse.pose = "sit"
	await wait(0.4)
	await say("engineer", "Thoroughly tangled. A masterpiece of disorder.")


## Flashlight on the lever: if everything matches the footage, Fuse makes the loop.
func _lure_to_lever() -> void:
	var f := flags
	var missing := Lines.missing(self)
	if f.phase != "loop":
		await say("engineer", "Point that light at the lever? Absolutely not. Not now.")
		return
	if not missing.is_empty():
		_engineer_gesture("shrug")
		await say("engineer", missing[0])
		return
	use_up("flashlight")
	var fuse: Node2D = _w.fuse
	var dot := LightSpot.new()
	dot.position = Machine.LEVER_TOP + Vector2(0, 10)
	world.add_child(dot)
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
	var tw := create_tween()
	tw.tween_property(_w.machine, "portal", 1.0, 0.8)
	Sound.play("lens_light", self)
	await tw.finished
	fuse.facing = 1.0
	await fuse.walk_to(Machine.PORTAL_FLOOR.x - 10, Machine.PORTAL_FLOOR.y + 4, 140.0)
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
	await say("engineer", "He went! The loop is closed! Time is ticking again!")
	_engineer_gesture("idle")
	await wait(0.8)
	await _cascade()


# --- break ------------------------------------------------------------------------------

func _cascade() -> void:
	flags.phase = "break"
	_w.tv.tuned = false
	await _sirens(2)
	_w.tv.tuned = true
	await say("engineer", "Hang on. The Futurescope's showing something new...", 1.8)
	await _watch("cascade", "THE FUTURE")
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
	await say("engineer", "He's thinking about it. I know that look. We need to get his mind off that lever before I pull the plug.")


func _machine() -> void:
	var f := flags
	match f.phase:
		"setup":
			await says("engineer", Lines.MACHINE_SETUP if f.fuse_part != "machine" else ["She's humming. Doesn't do much on her own, mind."])
		"loop":
			if f.fuse_part != "machine":
				await say("engineer", "On the Futurescope she was glowing. She'll need a fuse for that.")
			else:
				await say("engineer", "Powered and purring. Now the dial, and the cat.")
		"break":
			if f.box != "floor":
				await say("engineer", "If I pull the fuse with him right there, he'll pounce on that lever the moment it sparks. Distract him first.")
			else:
				await _finale()


func _place_box_scene(at: Vector2) -> void:
	var f := flags
	if f.phase != "break":
		await say("engineer", "Hold on to that. Fuse's favourite box. We may need a distraction later.")
		return
	use_up("box")
	f.box = "floor"
	f.box_pos = Vector2(clampf(at.x, 560, 1100), clampf(at.y, 720, 790))
	_place_box(f.box_pos)
	Sound.play("place", self)
	await wait(0.6)
	twin.tail_mood = 1.0
	twin.pose = "stand"
	await twin.walk_to(f.box_pos.x + 90, f.box_pos.y - 12)
	await twin.jump_to(f.box_pos + Vector2(0, -12), 70.0, 0.5, "sit")
	_raise_box()
	await say("engineer", "If he fits, he sits. Quick, the fuse!")


func _place_box(p: Vector2) -> void:
	if _box_node == null:
		_box_node = Small.Box.new()
		_box_node.id = ""
		_box_node.folded = true
		world.add_child(_box_node)
	_box_node.position = p


## Moves the box in front of the cat sitting in it.
func _raise_box() -> void:
	if _box_node and twin:
		world.move_child(_box_node, twin.get_index() + 1)


func _finale() -> void:
	var f := flags
	f.fuse_part = "pulled"
	take("fuse")
	_w.machine.powered = false
	Sound.play("place", self)
	var tw := create_tween()
	tw.tween_property(_w.machine, "portal", 0.0, 0.8)
	await tw.finished
	_w.machine.portal_unstable = false
	alarm.mode = ""
	await wait(0.5)
	await _watch("calm", "THE FUTURE")
	f.phase = "done"
	_engineer_gesture("cheer")
	await says("engineer", Lines.FINALE)
	await _officer_visit(Lines.OFFICER_LEAVES)
	_engineer_gesture("idle")
	await say("engineer", "Come back any time. Just... knock first. And bring sardines.")
	won.emit()


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
		draw_circle(p, 22, Color(1, 1, 0.8, 0.25))
		draw_circle(p, 12, Color(1, 1, 0.85, 0.6))
