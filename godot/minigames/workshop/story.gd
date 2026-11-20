extends Node
## The Workshop's story: a state machine of phases, and what each click does in each.
##
##   setup   The Engineer wanders in after you, mourning his dark Futurescope. Fuse is
##           asleep on the icebox and stays there whatever you do. The radio (up close:
##           three stations, and four screws on its back) gives up its tube; the
##           Futurescope, tuned, shows Fuse in yarn and a sardine lid leaping on the lever
##           and vanishing into the portal. Then the portal opens by itself and that very
##           cat walks out. The two cats see each other; the clock stops; sirens; the
##           Officer, with a form.
##   loop    Make the footage come true. Fuse, awake now, only comes down from the icebox
##           for something: opened sardines (the lid), or the flashlight. The red yarn is
##           on the cat from the future: unwind it and give it to Fuse. The fuse is blown:
##           the pegboard's copper wire. The destination counter matches the stopped
##           clock (and the footage). The flashlight on the lever sends Fuse; anything
##           that doesn't match and the portal spits him out.
##   break   The loop closes, but the remaining cat wants another go. Only a box in the
##           sunbeam tempts him away; then pull the wire.
##   done    Won.     epilogue   Revisiting after the win (epilogue.gd).
##
## Clicks mostly just do things; the Engineer (engineer.gd) minds his things, gets put
## out, and nudges only when you're close. The flashlight makes Fuse pounce at almost
## anything (pounce.gd). Nothing in a phase depends on something that hasn't happened:
## each handler checks the phase and the flags it needs.

signal won

const Machine := preload("res://minigames/workshop/machine.gd")
const Cat := preload("res://minigames/workshop/cat.gd")
const Person := preload("res://minigames/workshop/person.gd")
const Small := preload("res://minigames/workshop/small_props.gd")
const Vision := preload("res://minigames/workshop/vision.gd")
const Lines := preload("res://minigames/workshop/lines.gd")
const Engineer := preload("res://minigames/workshop/engineer.gd")
const Pounce := preload("res://minigames/workshop/pounce.gd")
const Epilogue := preload("res://minigames/workshop/epilogue.gd")
const RadioSongs := preload("res://minigames/workshop/radio_songs.gd")
const MusicPlayer := preload("res://audio/music/music_player.gd")

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
var radio_view: Node2D
var deletion: Node2D       ## overlays.gd Deletion: the rewind when a wrong attempt is deleted.
var busy := false          ## True while a scene plays; clicks wait.

var flags := {
	"phase": "setup",
	"visits": 0, "annoyance": 0, "said": [], "milk": "fridge", "milk_grabs": 0,
	"radio_on": false, "station": 0, "screws": 0, "tube": "radio",   # radio, held, tv
	"tuned": false,
	"icebox_open": false, "tin": "icebox", "tin_pos": Vector2(700, 730), "tin_open": false,
	"drawer_open": false, "drawer_items": true,
	"wire": "board",       # board, held, machine, pulled
	"dial": 3 * 60, "arrival": -1, "lid": false, "yarn": false, "twin_yarn": true,
	"fuse_down": false,    # Fuse has come down from the icebox (loop phase).
	"box": "wall", "box_pos": Vector2(700, 760),   # wall, held, floor
	"blinds": false, "fixated": 0, "deletions": 0,
	"items": [],
}

var twin: Node2D            ## The cat that walked out of the portal.
var engineer: RefCounted     ## engineer.gd
var pounce: RefCounted       ## pounce.gd
var epilogue: RefCounted     ## epilogue.gd
var radio_music: Node
var _box_node: Node2D
var _w: Dictionary
var _mutters := 0
var _twin_in_box := false


func _ready() -> void:
	_w = world.things
	engineer = Engineer.new(self)
	pounce = Pounce.new(self)
	epilogue = Epilogue.new(self)
	radio_music = MusicPlayer.new()
	radio_music.songs = RadioSongs.all()
	add_child(radio_music)


func _notification(what: int) -> void:
	if radio_music == null:
		return
	if what == NOTIFICATION_DISABLED:
		radio_music.paused = true
	elif what == NOTIFICATION_ENABLED:
		radio_music.paused = false


# --- saving ---------------------------------------------------------------------------

func save_state() -> Dictionary:
	var out := flags.duplicate(true)
	out.items = inventory.items.duplicate()
	return out


func load_state(state: Dictionary) -> void:
	for k in state:
		if flags.has(k):
			flags[k] = state[k]
	for k in ["dial", "arrival", "visits", "annoyance", "milk_grabs", "station", "screws", "fixated", "deletions"]:
		flags[k] = int(flags[k])
	flags.said = Array(flags.said)
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
	_w.radio.back_open = int(f.screws) >= 4
	_w.radio.has_tube = f.tube == "radio"
	_w.tv.has_tube = f.tube == "tv"
	_w.tv.on = f.tube == "tv"
	_w.tv.tuned = f.tuned
	_set_icebox(f.icebox_open)
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
	match f.phase:
		"setup":
			_fuse_at(FUSE_NAP, "sleep")
		"loop":
			if f.yarn:
				_fuse_at(YARN_SPOT, "sit")
			elif f.lid:
				_fuse_at(Vector2(f.tin_pos.x - 70, f.tin_pos.y - 4), "sit")
			elif f.fuse_down:
				_fuse_at(Vector2(640, 724), "sit")
			else:
				_fuse_at(FUSE_NAP, "sit")
		_:
			fuse.visible = false
	if f.box == "floor":
		_place_box(f.box_pos)
	if f.arrival >= 0:
		_w.tv.future.things.machine.dial = f.arrival
		_w.tv.future.things.clock.seconds = f.arrival * 60.0 + 20.0
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
			twin.position = f.box_pos + Vector2(0, -12)
			twin.pose = "sit"
			_raise_box()
			_twin_in_box = true
		else:
			twin.position = Vision.LEVER_WAIT
			twin.pose = "sit"
			twin.facing = -1.0
			twin.tail_mood = 3.0
	_play_radio()


func _fuse_at(at: Vector2, pose: String) -> void:
	_w.fuse.position = at
	_w.fuse.pose = pose
	_w.fuse.visible = true


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


# --- opening the Workshop ---------------------------------------------------------------

## A first visit, a resumed one, or a visit after the win: the Engineer arrives a moment
## after you, either way.
func begin(resume: Dictionary) -> void:
	busy = true
	if Game.completed_minigames.has("workshop"):
		epilogue.begin()
		await engineer.arrive_with(epilogue.arrival_lines())
	else:
		if not resume.is_empty():
			load_state(resume)
		apply_flags()
		await engineer.arrive()
	busy = false


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


func _gesture(g: String, at := Vector2.ZERO) -> void:
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


func light_spot(at: Vector2) -> Node2D:
	var spot := LightSpot.new()
	spot.position = at
	world.add_child(spot)
	return spot


func box_node() -> Node2D:
	return _box_node


func fuse_awake() -> bool:
	return flags.phase == "loop" and _w.fuse.visible


func fuse_on_icebox() -> bool:
	return _w.fuse.position.y < 600


# --- clicks -----------------------------------------------------------------------------

func click(id: String, held: String, at: Vector2) -> void:
	if busy:
		return
	busy = true
	if held != "":
		await _use(held, id, at)
	else:
		await _poke(id, at)
	_gesture("idle")
	busy = false


func _poke(id: String, at: Vector2) -> void:
	var f := flags
	if f.phase == "epilogue":
		match id:
			"tv": await epilogue.next_channel()
			"engineer": await _mutter()
			"radio": await open_radio()
			"clock": await _zoom_clock()
			_: await nope(id)
		return
	match id:
		"engineer":
			await _mutter()
		"fuse":
			await _pet(_w.fuse)
		"twin":
			if f.phase == "loop" and f.twin_yarn:
				await _unwind_twin()
			else:
				await _pet(twin)
		"radio":
			await open_radio()
		"tv":
			await _tv()
		"icebox":
			await _icebox()
		"milk":
			await engineer.milk()
			_w.milk.visible = f.milk == "fridge" and f.icebox_open
		"jelly":
			_w.jelly.wobble_jelly()
			Sound.play("card_hit", self, -8.0, 0.6)
			await engineer.mine("jelly")
		"drawer":
			await _drawer()
		"wire":
			take("wire")
			_w.wire.taken = true
			f.wire = "held"
			await engineer.mine("wire")
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
			await nope("lever")
			if f.phase == "loop":
				await engineer.nudge("lever_hand")
		"box":
			take("box")
			_w.box.visible = false
			f.box = "held"
			await engineer.mine("box")
		"placed_box":
			if _twin_in_box:
				await _pet(twin)
			else:
				take("box")
				_box_node.visible = false
				f.box = "held"
		"blinds":
			await _toggle_blinds()
		"clock":
			await _zoom_clock()
			await engineer.mine("clock")
		_:
			await nope(id)


func _use(item: String, id: String, at: Vector2) -> void:
	var f := flags
	if f.phase == "epilogue":
		if id == "portal":
			await epilogue.send(item)
		else:
			await nope(id)
		return
	match [item, id]:
		["tube", "tv"]:
			use_up("tube")
			f.tube = "tv"
			_w.tv.has_tube = true
			_w.tv.on = true
			Sound.play("place", self)
			_gesture("cheer")
			await say("engineer", Lines.TUBE)
		["sardines", "floor"]:
			await _put_down_sardines(at)
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
		["flashlight", _]:
			await _flashlight(id, at)
		["box", "floor"]:
			await _place_box_scene(at)
		_:
			await nope(id)


func _mutter() -> void:
	_mutters += 1
	await say("engineer", Lines.mutter(flags.phase, _mutters))


func _pet(cat: Node2D) -> void:
	if cat == null:
		return
	if cat.pose == "sleep":
		cat.set("_ear_flick", 0.3)
		return
	cat.tail_mood = 2.0
	Sound.play("card_hit", self, -10.0, 1.6)
	await wait(0.4)
	cat.tail_mood = 1.0


func _toggle_blinds() -> void:
	var f := flags
	f.blinds = not f.blinds
	_w.blinds.open = f.blinds
	Sound.play("dial_snap", self)
	if _box_tempts_twin():
		await wait(0.6)
		await _twin_to_box()
	elif f.phase == "break" and f.blinds:
		await engineer.nudge("sunbeam")


# --- the radio --------------------------------------------------------------------------

## The radio up close: its knobs and, round the back, its screws and tubes. Clicks go to
## radio_click() until it's closed.
func open_radio() -> void:
	radio_view.on = flags.radio_on
	radio_view.station = int(flags.station)
	radio_view.screws_out = int(flags.screws)
	radio_view.tube_present = flags.tube == "radio"
	radio_view.open()
	Sound.play("card_draw", self, -6.0)


func radio_open() -> bool:
	return radio_view.visible


func radio_click(p: Vector2) -> void:
	if busy:
		return
	busy = true
	var f := flags
	match radio_view.part_at(p):
		"outside":
			await radio_view.close()
		"power":
			f.radio_on = not f.radio_on
			radio_view.on = f.radio_on
			Sound.play("dial_snap", self)
			_play_radio()
			if f.radio_on and f.tube == "radio":
				await _station_remark()
		"tune":
			await radio_next_station(true)
		"turn":
			radio_view.view = "back" if radio_view.view == "front" else "front"
			Sound.play("card_draw", self, -4.0)
		"screw":
			f.screws = int(f.screws) + 1
			radio_view.screws_out = f.screws
			Sound.play("dial_turn", self, 0.0, 1.4)
			if int(f.screws) >= 4:
				_w.radio.back_open = true
				Sound.play("place", self)
				await engineer.mine("radio_back")
		"tube":
			take("tube")
			f.tube = "held"
			_w.radio.has_tube = false
			radio_view.tube_present = false
			_play_radio()
			await engineer.mine("tube")
	busy = false


## The tuning knob (or a pouncing cat): a sweep of static, then the next station.
func radio_next_station(remark: bool) -> void:
	var f := flags
	f.station = (int(f.station) + 1) % RadioSongs.STATIONS.size()
	radio_view.station = f.station
	if f.radio_on and f.tube == "radio":
		radio_view.tuning = 0.5
		radio_music.play("static", 0.05)
		Sound.play("dial_turn", self)
		await wait(0.5)
		_play_radio()
		if remark:
			await _station_remark()


func _station_remark() -> void:
	var s := int(flags.station)
	if Lines.STATIONS.has(s):
		await engineer.nudge_line("station_%d" % s, Lines.STATIONS[s])


func _play_radio() -> void:
	var playing: bool = flags.radio_on and flags.tube == "radio"
	_w.radio.playing = playing
	if radio_music == null:
		return
	if playing:
		radio_music.play(RadioSongs.STATIONS[int(flags.station)].id, 0.25)
	else:
		radio_music.stop(0.3)


# --- setup ------------------------------------------------------------------------------

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
	await watch(_vision_for_phase(), "")


func _vision_for_phase() -> String:
	match flags.phase:
		"break":
			return "cascade"
		"done":
			return "calm"
	return "loop"


## Shows the Futurescope full screen while a scene plays in the future room.
func watch(scene: String, caption: String) -> void:
	closeup.open(_w.tv.feed_texture(), _w.tv.material(), caption)
	await Vision.play(_w.tv.future, scene, footage_minute())
	await closeup.close()


## The destination the footage shows: the minute the twin steps out.
func footage_minute() -> int:
	return flags.arrival if flags.arrival >= 0 else _arrival_minute()


## The minute the twin will step out: shortly after the first vision ends.
func _arrival_minute() -> int:
	return int((_w.clock.seconds + ARRIVAL_DELAY) / 60.0) % 720


func _first_vision() -> void:
	# Decided once, up front: the footage, the stopped clock and the rule all use it.
	flags.arrival = _arrival_minute()
	_gesture("point", _w.tv.position + Vector2(920, 340))
	await wait(0.6)
	await watch("loop", "")
	_gesture("think")
	await says("engineer", Lines.AFTER_VISION)
	await wait(0.6)
	await _arrival()


## The portal opens by itself; the cat from the future steps out. The two see each other.
func _arrival() -> void:
	var m: Node2D = _w.machine
	var fuse: Node2D = _w.fuse
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
	await twin.walk_to(1150.0, 724.0, 150.0)
	# Fuse wakes on the icebox. They see each other.
	fuse.pose = "sit"
	fuse.facing = 1.0
	await wait(0.6)
	twin.facing = -1.0
	twin.pose = "sit"
	await wait(0.4)
	fuse.startle()
	await twin.startle()
	await say("engineer", Lines.BOTH_SEE, 1.6)
	# The one from the future couldn't care less, and finds somewhere to curl up.
	twin.pose = "stand"
	await twin.walk_to(Vision.TWIN_NAP.x, Vision.TWIN_NAP.y, 150.0)
	twin.pose = "sleep"
	_gesture("shrug")
	await wait(0.6)
	flags.phase = "loop"
	alarm.mode = "violation"
	_w.tv.alarm = true
	await _sirens()
	await wait(0.4)
	await _officer_visit(Lines.OFFICER_ARRIVES)
	_gesture("think")
	await says("engineer", Lines.AFTER_OFFICER)
	# Sardines opened earlier have been waiting; now he's awake, he goes for them.
	if flags.tin == "floor" and flags.tin_open and not flags.lid:
		await _fuse_eats()


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


# --- his things -------------------------------------------------------------------------

func _set_icebox(open: bool) -> void:
	flags.icebox_open = open
	_w.icebox.open = open
	_w.icebox.has_tin = flags.tin == "icebox"
	_w.milk.visible = open and flags.milk == "fridge"
	_w.jelly.visible = open


func _icebox() -> void:
	var f := flags
	if not f.icebox_open:
		_set_icebox(true)
		Sound.play("place", self)
		await engineer.mine("icebox")
	elif f.tin == "icebox":
		f.tin = "held"
		_w.icebox.has_tin = false
		take("sardines")
	else:
		_set_icebox(false)
		Sound.play("place", self)


func _drawer() -> void:
	var f := flags
	if not f.drawer_open:
		f.drawer_open = true
		_w.bench.drawer_open = true
		Sound.play("card_draw", self)
		await engineer.mine("drawer")
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


# --- making the loop --------------------------------------------------------------------

func _put_down_sardines(at: Vector2) -> void:
	var f := flags
	use_up("sardines")
	f.tin = "floor"
	f.tin_pos = Vector2(clampf(at.x, 600, 940), clampf(at.y, 700, 780))
	_w.tin.position = f.tin_pos
	_w.tin.visible = true
	Sound.play("place", self)
	if fuse_awake():
		_w.fuse.set("_ear_flick", 0.3)
		await engineer.nudge("tin_closed")


func _open_sardines() -> void:
	var f := flags
	if f.tin_open:
		await nope("tin")
		return
	use_up("opener")
	f.tin_open = true
	_w.tin.opened = true
	Sound.play("dial_snap", self)
	if f.phase == "setup":
		# Asleep on the icebox, he doesn't stir. Not even for sardines.
		_w.fuse.set("_ear_flick", 0.3)
		await wait(0.6)
		await engineer.nudge("sardines_early")
	elif fuse_awake() and not f.lid:
		await _fuse_eats()


## Down from wherever he is, to the open tin: he eats, and comes up wearing the lid.
func _fuse_eats() -> void:
	var f := flags
	var fuse: Node2D = _w.fuse
	await wait(0.3)
	if fuse_on_icebox():
		fuse.pose = "crouch"
		await wait(0.4)
		await fuse.jump_to(Vector2(560, 720), 60.0, 0.6)
	f.fuse_down = true
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


## Red yarn for Fuse, if he's down here to play: a ball rolls, a cat pounces.
func _tangle(at: Vector2) -> void:
	var f := flags
	var fuse: Node2D = _w.fuse
	if f.yarn or not fuse_awake():
		await nope("fuse")
		return
	if fuse_on_icebox():
		await nope("fuse")
		await engineer.nudge("yarn_up_high")
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
			await engineer.nudge("wire_watched")
			await _twin_guards_lever()
		return
	await nope("machine")
	if f.wire == "board" or f.wire == "held":
		await engineer.nudge("socket")


## The flashlight at anything but the lever: Fuse (if he's awake) pounces at it.
func _flashlight(id: String, at: Vector2) -> void:
	var f := flags
	if f.phase == "break":
		# The remaining cat only has eyes for the lever.
		await nope(id)
		f.fixated = int(f.fixated) + 1
		await engineer.nudge("fixated_%d" % mini(int(f.fixated), 3))
		return
	if not fuse_awake():
		await nope(id)
		if f.phase == "setup":
			await engineer.nudge("lever_asleep")
		return
	if not pounce.can_target(id):
		await nope(id)
		return
	await pounce.chase(id, at)
	f.fuse_down = not fuse_on_icebox()


## Flashlight on the lever: Fuse pounces. Whether the portal accepts him depends on how
## closely this moment matches the Futurescope's footage.
func _lure_to_lever() -> void:
	var f := flags
	var fuse: Node2D = _w.fuse
	if f.phase == "break":
		await _flashlight("lever", Vector2.ZERO)
		return
	if not fuse_awake():
		await nope("lever")
		if f.phase == "setup":
			await engineer.nudge("lever_asleep")
		return
	var dot := light_spot(Machine.LEVER_TOP + Vector2(0, 10))
	if fuse_on_icebox():
		fuse.pose = "crouch"
		await wait(0.4)
		await fuse.jump_to(Vector2(560, 720), 60.0, 0.6)
	f.fuse_down = true
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
		await _deleted(fuse)
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
	_gesture("cheer")
	await say("engineer", Lines.LOOP_CLOSED)
	_gesture("idle")
	await wait(0.8)
	await _cascade()


## True when the cat, the machine and the destination match the footage.
func matches_footage() -> bool:
	var f := flags
	return f.lid and f.yarn and f.wire == "machine" and f.dial == footage_minute()


## Not as in the footage: the timeline is deleted, which here means a glitch, a stamp and
## a rewind to just before the lever, with nothing lost. Then what differs flickers.
func _deleted(fuse: Node2D) -> void:
	var f := flags
	_w.machine.portal_unstable = true
	Sound.play("unavailable", self, 0.0, 0.6)
	await wait(0.4)
	var n := int(f.deletions)
	f.deletions = n + 1
	await deletion.play(n, func():
		# Back to a moment before: Fuse by the lever, the portal shut, the lever up.
		_w.machine.portal = 0.0
		_w.machine.portal_unstable = false
		_w.machine.lever_down = false
		fuse.scale = Vector2.ONE
		fuse.modulate.a = 1.0
		fuse.visible = true
		fuse.position = Vision.LEVER_WAIT + Vector2(-90, 10)
		fuse.facing = -1.0
		fuse.pose = "sit")
	Sound.play("dial_turn", self, 0.0, 0.5)
	# Whatever differs from the footage flickers for a moment.
	if f.dial != footage_minute():
		_w.machine.dial_wrong = 4.0
	if not f.yarn or not f.lid:
		fuse.ghost = 4.0
	_gesture("shrug")
	await say("engineer", Lines.DELETED[mini(n, Lines.DELETED.size() - 1)])


# --- breaking the loop ------------------------------------------------------------------

func _cascade() -> void:
	flags.phase = "break"
	_w.tv.tuned = false
	await _sirens(2)
	_w.tv.tuned = true
	await watch("cascade", "")
	alarm.mode = "instability"
	_w.machine.portal_unstable = true
	var tw := create_tween()
	tw.tween_property(_w.machine, "portal", 0.35, 0.8)
	_gesture("shrug")
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


## Reaching for the wire while the cat watches: it leaps onto the lever first.
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
	f.box_pos = Vector2(clampf(at.x, 300, 1100), clampf(at.y, 720, 790))
	_place_box(f.box_pos)
	Sound.play("place", self)
	if _box_tempts_twin():
		await wait(0.6)
		await _twin_to_box()
	elif f.phase == "break":
		# In the shade: he looks, and thinks better of it.
		twin.set("_ear_flick", 0.3)
		await wait(0.5)
		await engineer.nudge("box_shade")


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
	await wait(0.6)
	_gesture("point", Machine.LEVER_PIVOT + Vector2(-80, -70))
	await engineer.nudge_line("in_the_box", Lines.IN_THE_BOX)


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
	raise_box_over(twin)


func raise_box_over(cat: Node2D) -> void:
	if _box_node and cat:
		world.move_child(_box_node, cat.get_index() + 1)


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
	await watch("calm", "")
	f.phase = "done"
	_gesture("cheer")
	await says("engineer", Lines.FINALE)
	await _officer_visit(Lines.OFFICER_LEAVES)
	_gesture("idle")
	await say("engineer", Lines.GOODBYE)
	won.emit()


# --- the clock --------------------------------------------------------------------------

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
		Small.Yarn.yarn_ball(self, Vector2.ZERO, 22, 130)


## The flashlight's spot dancing on something.
class LightSpot extends Node2D:
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var p := Vector2(sin(_t * 7.0) * 8.0, cos(_t * 5.0) * 6.0)
		draw_circle(p, 22, Color(1, 1, 0.85, 0.25))
		draw_circle(p, 12, Color(1, 1, 0.85, 0.6))
