extends "res://tests/test_suite.gd"
## Plays the Workshop story through the story's own click handler, dismissing every
## speech bubble as it appears: the radio close-up, the vision and the arrival, making the
## loop (with the flashlight's pounces and a rejection), breaking it, and the win. Also
## the order rules (Fuse stays on the icebox until the twin arrives; sardines opened early
## wait for him), the Engineer's moods, save/resume in each phase, and the editor's jumps.

const SaveGame := preload("res://autoload/save_game.gd")
const RadioView := preload("res://minigames/workshop/radio_view.gd")
const Vision := preload("res://minigames/workshop/vision.gd")

var _checks := 0
var _failures := 0
var _game: Control
var _story: Node
var _won := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.time_scale = 8.0
	root.size = Vector2i(1280, 720)
	_game = _open({})
	await _settle()
	_expect(_story.flags.phase == "setup" and int(_story.flags.visits) == 1, "The Workshop opens in setup, and the Engineer has arrived once")
	_expect(_w().engineer.position.distance_to(preload("res://minigames/workshop/engineer.gd").SPOT) < 2.0, "He walked in to his spot")
	_expect(_w().fuse.pose == "sleep" and _story.fuse_on_icebox(), "Fuse is asleep on the icebox")

	# Setup: the radio, up close.
	await _click("tv")
	_expect(not _w().tv.on, "The Futurescope needs a tube first")
	await _click("radio")
	_expect(_story.radio_open(), "The radio opens up close")
	await _radio(RadioView.POWER)
	_expect(_story.flags.radio_on and _w().radio.playing, "The power knob turns it on")
	await _radio(RadioView.TUNE)
	_expect(int(_story.flags.station) == 1, "The tuning knob finds the next station")
	await _radio(RadioView.TURN.get_center())
	_expect(_story.radio_view.view == "back", "Turned round")
	for k in 4:
		await _radio(RadioView.SCREWS[k])
	_expect(int(_story.flags.screws) == 4 and _w().radio.back_open, "Four screws out, the back comes off")
	await _radio(RadioView.TUBE + Vector2(0, -40))
	_expect(_inv().has("tube") and not _w().radio.playing, "The tube is taken; the radio falls silent")
	await _radio(Vector2(100, 100))
	_expect(not _story.radio_open(), "Clicking outside closes the radio")
	_expect(int(_story.flags.annoyance) >= 2, "The Engineer minded his radio")

	# Sardines before the loop: Fuse doesn't stir.
	await _click("icebox")
	await _click("icebox")
	_expect(_inv().has("sardines"), "Sardines from the icebox")
	await _click("drawer")
	await _click("drawer")
	await _click("floor", "sardines", Vector2(700, 740))
	await _click("tin", "opener")
	_expect(_story.flags.tin_open and not _story.flags.lid and _w().fuse.pose == "sleep", "Opened early, the sardines don't wake him")
	await _click("lever", "flashlight")
	_expect(_story.fuse_on_icebox(), "Nor does the flashlight, while he sleeps")

	await _click("tv", "tube")
	_expect(_w().tv.on, "The tube switches the Futurescope on")
	await _click("tv")
	_expect(_story.flags.phase == "loop", "Tuning shows the future, then the loop opens")
	_expect(_story.twin != null and _story.twin.displaced and _story.twin.lid and _story.twin.yarn, "A second, shimmering Fuse in lid and yarn walked out")
	_expect(_story.alarm.mode == "violation" and _w().clock.frozen, "Alarm on, clock stopped")
	_expect(_story.flags.lid and not _story.fuse_on_icebox(), "Once awake, Fuse went straight for the waiting sardines")
	var future: Dictionary = _w().tv.future.things
	_expect(future.machine.dial == _story.flags.arrival, "The footage's counter shows the arrival minute")

	# Save and resume mid-phase.
	_game = await _reopen()
	_expect(_story.flags.phase == "loop" and _story.flags.lid and _inv().has("flashlight"), "Resuming keeps the phase, the lid and the items")
	_expect(int(_story.flags.visits) == 2, "...and the Engineer turned up again")

	# His milk.
	await _click("icebox")
	for k in 3:
		await _click("milk")
	_expect(_story.flags.milk == "drunk" and not _w().milk.visible, "Three grabs at his milk and he drinks it")
	_expect(int(_story.flags.annoyance) >= 6, "He's getting put out")

	# The yarn from the future, and a pounce.
	await _click("twin")
	_expect(_inv().has("yarn") and not _story.twin.yarn, "The red yarn comes off the cat from the future")
	await _click("fuse", "yarn")
	_expect(_story.flags.yarn, "Fuse is tangled in it")
	await _click("tv", "flashlight")
	_expect(not _story.fuse_on_icebox() and _w().fuse.visible, "He pounced at the Futurescope and came back down")
	var before := int(_story.flags.station)
	await _click("radio", "flashlight")
	_expect(int(_story.flags.station) != before, "Pouncing on the bench knocks the radio's tuning")
	await _click("lever", "flashlight")
	_expect(_w().fuse.visible and not _w().machine.powered, "Without power the lever does nothing")
	await _click("machine")
	_expect("nudge_socket" in _story.flags.said, "The blown socket gets a nudge")
	await _click("wire")
	await _click("machine", "wire")
	_expect(_w().machine.powered, "The copper wire bridges the blown fuse")
	_story.flags.dial = (_story.flags.arrival + 1) % 720
	_w().machine.dial = _story.flags.dial
	await _click("lever", "flashlight")
	_expect(_w().fuse.visible and _story.flags.phase == "loop" and _w().machine.dial_wrong > 0.0, "The wrong destination: deleted, rewound, and the counter flashes")
	_expect(int(_story.flags.deletions) == 1 and _story.flags.yarn and _story.flags.lid and _w().machine.powered, "Deletion is harmless: nothing was lost")
	_expect(not _story.deletion.visible and _w().machine.portal == 0.0, "...and the room is back as it was")
	await _set_dial(_w().tv.future.things.machine.dial)
	await _click("lever", "flashlight")
	_expect(not _w().fuse.visible and _story.flags.phase == "break", "Fuse went through: the loop closed, the cascade begins")
	_expect(_story.twin.position.distance_to(Vision.LEVER_WAIT) < 4.0, "The remaining cat waits by the lever")

	# Break.
	await _click("machine")
	_expect(_w().machine.powered and "nudge_wire_watched" in _story.flags.said, "No pulling the wire while he watches")
	await _click("tv", "flashlight")
	_expect(int(_story.flags.fixated) == 1, "He ignores the flashlight now")
	await _click("box")
	await _click("floor", "box", Vector2(900, 760))
	_expect(not _story._twin_in_box and "nudge_box_shade" in _story.flags.said, "A box in the shade: a look, and a nudge")
	_game = await _reopen()
	await _click("blinds")
	await _click("placed_box")
	await _click("floor", "box", Vector2(450, 770))
	_expect(_story._twin_in_box, "A box in the sunbeam: he climbs in")
	_expect("in_the_box" in _story.flags.said, "...and the Engineer points out the moment")
	_game.finished.connect(func(r: Dictionary): _won = r.get("won", false))
	await _click("machine")
	_expect(_won and _game.save_state().is_empty(), "Pulling the wire wins; nothing left to save")

	# The editor's jump points resume cleanly and play on.
	var Stages := preload("res://minigames/workshop/dev_stages.gd")
	for st: Dictionary in Stages.STAGES:
		_expect(Stages.stage_of(Stages.state_for(st.id)) == st.id, "The editor recognises its own '%s' state" % st.id)
	_game.queue_free()
	await process_frame
	_game = _open(_through_json(Stages.state_for("ready")))
	await _settle()
	_expect(_story.flags.phase == "loop" and _story.matches_footage(), "'Ready to send Fuse' matches the footage")
	await _click("lever", "flashlight")
	_expect(_story.flags.phase == "break", "From 'Ready to send Fuse' the flashlight closes the loop")
	_game.queue_free()
	await process_frame
	_game = _open(_through_json(Stages.state_for("loop")))
	await _settle()
	_expect(_story.fuse_on_icebox() and _w().fuse.pose == "sit", "'Twin arrived' finds Fuse awake on the icebox")
	_game.queue_free()
	await process_frame

	# Leaving mid-vision resumes with the vision still to watch; mid-finale, with the cat
	# in his box and the wire back in.
	_game = _open(_through_json({"phase": "setup", "tube": "tv", "tuned": true, "arrival": 185}))
	await _settle()
	await _click("tv")
	_expect(_story.flags.phase == "loop" and _story.twin != null, "Left during the vision: the TV shows it again and the twin arrives")
	_game.queue_free()
	await process_frame
	var mid := Stages.state_for("break")
	mid.merge({"wire": "pulled", "items": ["wire"], "box": "floor", "box_pos": Vector2(450, 770), "blinds": true}, true)
	_game = _open(_through_json(mid))
	await _settle()
	_expect(_story.flags.wire == "machine" and _w().machine.powered and not _inv().has("wire"), "Left during the finale: the wire is back in")
	await _click("wire")
	_expect(_story.flags.wire == "machine", "The empty pegboard hook doesn't take the wire back out")
	_won = false
	_game.finished.connect(func(r: Dictionary): _won = r.get("won", false))
	await _click("machine")
	_expect(_won, "...and pulling it wins")
	_game.queue_free()
	await process_frame

	print("Workshop story: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _open(state: Dictionary) -> Control:
	var g: Control = load("res://minigames/workshop/workshop.tscn").instantiate()
	g.resume_state = state
	root.add_child(g)
	_story = g._story
	return g


func _through_json(state: Dictionary) -> Dictionary:
	return SaveGame.decode(JSON.parse_string(JSON.stringify(SaveGame.encode(state))))


func _reopen() -> Control:
	# Through JSON, as the save file does.
	var state := _through_json(_game.save_state())
	_game.queue_free()
	await process_frame
	var g := _open(state)
	await _settle()
	return g


func _w() -> Dictionary:
	return _story.world.things


func _inv() -> Node:
	return _story.inventory


## Clicks a hotspot (optionally using a held item) and waits for the scene to finish,
## dismissing speech bubbles as they appear.
func _click(id: String, held := "", at := Vector2(700, 740)) -> void:
	_story.click(id, held, at)
	await _settle()


func _radio(at: Vector2) -> void:
	_story.radio_click(at)
	await _settle()


## Turns the counter's wheels, by clicking them, until it reads `minutes`.
func _set_dial(minutes: int) -> void:
	var wheels: Array = _w().machine.dial_part.WHEELS
	for k in 3:
		var guard := 0
		while _digit(_story.flags.dial, k) != _digit(minutes, k) and guard < 12:
			await _click("dial", "", wheels[k].get_center())
			guard += 1


func _digit(m: int, wheel: int) -> int:
	return [m / 60, (m % 60) / 10, m % 10][wheel]


func _settle() -> void:
	await process_frame
	var guard := 0
	while (_story.busy or _story.bubble.is_open()) and guard < 20000:
		_story.bubble.advance()
		_story.bubble.advance()
		await process_frame
		guard += 1
	_expect(guard < 20000, "A scene finished")


func _expect(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(description)
