extends "res://tests/test_suite.gd"
## Plays the Workshop story from the first click to the win, through the story's own
## click handler, dismissing every speech bubble as it appears. Checks each beat's
## result, the hints and blocks along the way, and save/resume between phases.

var _checks := 0
var _failures := 0
var _game: Control
var _story: Node
var _won := false
const SaveGame := preload("res://autoload/save_game.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.time_scale = 8.0
	root.size = Vector2i(1280, 720)
	_game = _open({})
	await _settle()
	_expect(_story.flags.phase == "setup", "The Workshop opens in its setup phase")
	_expect(_w().fuse.pose == "sleep", "Fuse starts asleep on the icebox")

	# Setup: the radio gives up its tube to the Futurescope.
	await _click("tv")
	_expect(not _w().tv.on, "The Futurescope needs a tube first")
	await _click("radio")
	_expect(_w().radio.playing, "The radio plays")
	await _click("radio")
	_expect(_w().radio.back_open, "The radio's back opens")
	await _click("radio")
	_expect(_inv().has("tube"), "The tube is taken")
	await _click("tv", "tube")
	_expect(_w().tv.on and not _w().tv.tuned, "The tube switches the Futurescope on, untuned")
	await _click("tv")
	_expect(_story.flags.phase == "loop", "Tuning shows the future, then the loop opens")
	_expect(_story.twin != null and _story.twin.displaced, "A second, shimmering Fuse walked out of the portal")
	_expect(_story.twin.lid and _story.twin.yarn, "It wears the lid and the yarn")
	_expect(_story.alarm.mode == "violation", "The temporal violation alarm sounds")
	_expect(_w().clock.frozen and _story.flags.arrival >= 0, "The clock stopped at the arrival minute")
	var future: Dictionary = _w().tv.future.things
	_expect(future.machine.dial == _story.flags.arrival, "The footage's destination counter shows the arrival minute")
	_expect(int(future.clock.seconds / 60.0) % 720 == _story.flags.arrival, "The footage's clock agrees")
	_expect(int(_w().clock.seconds / 60.0) % 720 == _story.flags.arrival, "So does the stopped clock in the room")
	_expect(not _w().has("officer"), "The Officer has gone again")

	# Save and resume mid-phase.
	await _click("icebox")
	await _click("icebox")
	_expect(_inv().has("sardines"), "Sardines from the icebox")
	_game = await _reopen()
	_expect(_story.flags.phase == "loop" and _inv().has("sardines"), "Resuming keeps the phase and the items")
	_expect(_story.twin != null and _story.alarm.mode == "violation", "Resuming restores the twin and the alarm")
	_expect(_w().clock.frozen and int(_w().clock.seconds / 60.0) % 720 == _story.flags.arrival, "Resuming keeps the stopped clock")

	await _click("drawer")
	await _click("drawer")
	_expect(_inv().has("opener") and _inv().has("flashlight"), "Opener and flashlight from the drawer")
	await _click("lever", "flashlight")
	_expect(_w().fuse.pose == "sleep", "A sleeping cat ignores the flashlight")
	await _click("basket")
	_expect(not _inv().has("yarn"), "The basket has no red yarn")
	await _click("twin")
	_expect(_inv().has("yarn") and not _story.twin.yarn, "The red yarn comes off the cat from the future")
	await _click("fuse", "yarn")
	_expect(_inv().has("yarn") and not _story.flags.yarn, "A sleeping Fuse won't play with yarn")

	await _click("floor", "sardines", Vector2(700, 740))
	_expect(_w().tin.visible, "The tin is on the floor")
	await _click("tin", "opener")
	_expect(_story.flags.lid and _w().fuse.lid, "Fuse ate the sardines and wears the lid")
	await _click("fuse", "yarn")
	_expect(_story.flags.yarn and _w().fuse.yarn, "Fuse is tangled in the yarn")
	await _click("lever", "flashlight")
	_expect(_w().fuse.visible and not _w().machine.powered, "Without power the lever does nothing")
	await _click("wire")
	await _click("machine", "wire")
	_expect(_w().machine.powered, "The copper wire bridges the blown fuse")
	_story.flags.dial = (_story.flags.arrival + 1) % 720
	_w().machine.dial = _story.flags.dial
	await _click("lever", "flashlight")
	_expect(_w().fuse.visible and _story.flags.phase == "loop", "The wrong destination: the portal spits Fuse back out")
	_expect(_w().machine.dial_wrong > 0.0, "The counter flashes: the destination is what differs")
	await _click("clock")
	_expect(_w().clock.scale == Vector2.ONE and _w().clock.z_index == 0, "The clock zooms in and back on a click")
	await _set_dial(_w().tv.future.things.machine.dial)
	_expect(_story.flags.dial == _story.flags.arrival, "The counter's wheels reach the stopped minute")
	await _click("lever", "flashlight")
	_expect(not _w().fuse.visible, "Fuse leapt on the lever and went through the portal")
	_expect(_story.flags.phase == "break", "The loop closed, and the cascade begins")
	_expect(_story.alarm.mode == "instability", "The instability alarm sounds")
	_expect(not _w().clock.frozen, "The clock runs again")
	_expect(_story.twin.position.distance_to(preload("res://minigames/workshop/vision.gd").LEVER_WAIT) < 4.0, "The remaining cat waits by the lever")

	# Break: the cat guards the lever; a box only works in the sun.
	await _click("machine")
	_expect(_w().machine.powered, "No pulling the wire while the cat eyes the lever")
	await _click("box")
	await _click("floor", "box", Vector2(900, 760))
	_expect(_story.flags.box == "floor" and not _story._twin_in_box, "A box in the shade doesn't tempt the cat")
	_game = await _reopen()
	_expect(_story.flags.phase == "break" and _story.twin.pose == "sit", "Resuming the break phase puts the cat by the lever")
	await _click("blinds")
	_expect(not _story._twin_in_box, "Sunlight alone doesn't either")
	await _click("placed_box")
	_expect(_inv().has("box"), "The box can be picked up again")
	await _click("floor", "box", Vector2(450, 770))
	_expect(_story._twin_in_box, "A box in the sunbeam: the cat climbs in")
	_game.finished.connect(func(r: Dictionary): _won = r.get("won", false))
	await _click("machine")
	_expect(_won, "Pulling the wire wins the Workshop")
	_expect(_game.save_state().is_empty(), "A won Workshop saves no progress")

	# The save editor's jump points resume cleanly and play on.
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
	_game = _open(_through_json(Stages.state_for("break")))
	await _settle()
	_expect(_story.flags.phase == "break" and _story.twin.position.distance_to(preload("res://minigames/workshop/vision.gd").LEVER_WAIT) < 4.0,
		"'Loop closed' puts the cat at the lever")

	print("Workshop story: %d checks, %d failures" % [_checks, _failures])
	_game.queue_free()
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
