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
	await _click("icebox")
	_expect(not _w().icebox.open, "Setup keeps the icebox for later")
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
	_expect(_w().clock.frozen, "The clock is stuck")
	_expect(not _w().has("officer"), "The Officer has gone again")

	# Save and resume mid-phase.
	await _click("icebox")
	await _click("icebox")
	_expect(_inv().has("sardines"), "Sardines from the icebox")
	_game = await _reopen()
	_expect(_story.flags.phase == "loop" and _inv().has("sardines"), "Resuming keeps the phase and the items")
	_expect(_story.twin != null and _story.alarm.mode == "violation", "Resuming restores the twin and the alarm")

	# The flashlight refuses until everything matches the footage.
	await _click("drawer")
	await _click("drawer")
	_expect(_inv().has("opener") and _inv().has("flashlight"), "Opener and flashlight from the drawer")
	await _click("lever", "flashlight")
	_expect(_w().fuse.visible and _inv().has("flashlight"), "The lure waits until the scene matches")
	await _click("basket")
	_expect(not _story.flags.yarn, "Yarn can't wake a sleeping cat")

	await _click("floor", "sardines", Vector2(700, 740))
	_expect(_w().tin.visible, "The tin is on the floor")
	await _click("tin", "opener")
	_expect(_story.flags.lid and _w().fuse.lid, "Fuse ate the sardines and wears the lid")
	await _click("basket")
	_expect(_story.flags.yarn and _w().fuse.yarn, "Fuse is tangled in yarn")
	await _click("can")
	_expect(_inv().has("fuse"), "The fuse from the coffee can")
	await _click("machine", "fuse")
	_expect(_w().machine.powered, "The machine is powered")
	await _click("lever", "flashlight")
	_expect(_w().fuse.visible, "A wrong dial setting still stops the lure")
	while _w().machine.dial != 1:
		await _click("dial")
	await _click("lever", "flashlight")
	_expect(not _w().fuse.visible, "Fuse leapt on the lever and went through the portal")
	_expect(_story.flags.phase == "break", "The loop closed, and the cascade begins")
	_expect(_story.alarm.mode == "instability", "The instability alarm sounds")
	_expect(not _w().clock.frozen, "The clock runs again")
	_expect(_story.twin.position.distance_to(preload("res://minigames/workshop/vision.gd").LEVER_WAIT) < 4.0, "The remaining cat waits by the lever")

	# Break: pulling the fuse with the cat at the lever is refused; a box lures it away.
	await _click("machine")
	_expect(_w().machine.powered, "No pulling the fuse while the cat eyes the lever")
	await _click("box")
	_expect(_inv().has("box"), "The box is taken")
	_game = await _reopen()
	_expect(_story.flags.phase == "break" and _story.twin.pose == "sit", "Resuming the break phase puts the cat by the lever")
	await _click("floor", "box", Vector2(760, 760))
	_expect(_story.flags.box == "floor" and _story.twin.position.distance_to(Vector2(760, 748)) < 4.0, "The cat sits in the box")
	_game.finished.connect(func(r: Dictionary): _won = r.get("won", false))
	await _click("machine")
	_expect(_won, "Pulling the fuse wins the Workshop")
	_expect(_game.save_state().is_empty(), "A won Workshop saves no progress")

	print("Workshop story: %d checks, %d failures" % [_checks, _failures])
	_game.queue_free()
	quit(1 if _failures > 0 else 0)


func _open(state: Dictionary) -> Control:
	var g: Control = load("res://minigames/workshop/workshop.tscn").instantiate()
	g.resume_state = state
	root.add_child(g)
	_story = g._story
	return g


func _reopen() -> Control:
	var state: Dictionary = _game.save_state()
	# Through JSON, as the save file does.
	state = SaveGame.decode(JSON.parse_string(JSON.stringify(SaveGame.encode(state))))
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
