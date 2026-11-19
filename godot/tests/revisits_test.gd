extends "res://tests/test_suite.gd"
## Room revisits (docs/INTERCONNECTION.md): after the Workshop is won, Fuse naps in the
## hall with a card in his fur, Egypt's room goes dark, the Workshop's Futurescope shows
## both, and the flashlight sent through the ring becomes a lamp in the hall's optics
## whose yellow beam restores Egypt's sun. None of it touches Door 2.

const TimeLink := preload("res://autoload/time_link.gd")
const Model := preload("res://scenes/escape/optics_model.gd")
const Progression := preload("res://minigames/cards/deck_progression.gd")

var _checks := 0
var _failures := 0
var _game: Node
var _room: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.time_scale = 8.0
	root.size = Vector2i(1280, 720)
	_game = root.get_node("Game")
	_game.flags.clear()
	_game.completed_minigames.clear()
	_game.collected_cards.clear()

	# Before the Workshop: nothing has changed.
	_expect(TimeLink.active_problems().is_empty(), "No problems before the Workshop is won")
	await _load_room()
	var revisits: Node3D = _room.revisits
	_expect(revisits.cat == null, "No cat in the hall yet")
	_expect(revisits.tray.slot_item == "", "The ring tray starts empty")
	var egypt_light := _egypt_light(revisits)
	_expect(egypt_light != null, "Egypt's room has a light to dim")
	var full: float = egypt_light.light_energy if egypt_light else 0.0

	# Win the Workshop.
	_game.record_win("workshop", {"won": true})
	_expect(TimeLink.is_active("egypt_dark") and TimeLink.is_active("fuse_loose"), "The Workshop's win sets off both problems")
	await _load_room()
	revisits = _room.revisits
	egypt_light = _egypt_light(revisits)
	_expect(egypt_light and egypt_light.light_energy < full * 0.5, "Egypt's room has gone dark")
	_expect(revisits.cat != null, "Fuse naps in the hall")

	# Fuse.
	revisits.cat.interact(null)
	_expect("fuse" in _game.collected_cards and not TimeLink.is_active("fuse_loose"), "Petting Fuse finds the Fuse card")
	_expect(Progression.owned(_game.collected_cards).is_empty(), "The bonus card isn't counted among the hall's five")
	_expect("fuse" in Progression.build(_game.collected_cards), "...but it joins Older Brother's deck")

	# The Workshop's epilogue: channels, and sending the flashlight.
	var workshop: Control = load("res://minigames/workshop/workshop.tscn").instantiate()
	root.add_child(workshop)
	var story: Node = workshop._story
	await _settle(story)
	_expect(story.flags.phase == "epilogue", "A won Workshop opens in its epilogue")
	_expect(story.inventory.has("flashlight"), "The flashlight is to hand")
	var channels := preload("res://minigames/workshop/channels.gd").available()
	_expect(channels.size() == 1 and channels[0].id == "egypt_dark", "The Futurescope picks up Egypt's channel (Fuse is found)")
	story.click("tv", "", Vector2.ZERO)
	await _settle(story)
	_expect(not story.closeup.visible, "Watching a channel ends cleanly")
	story.click("portal", "flashlight", Vector2.ZERO)
	await _settle(story)
	_expect(TimeLink.tray_item() == "flashlight" and not story.inventory.has("flashlight"), "The flashlight went through the portal")
	_expect(workshop.save_state().is_empty(), "The epilogue saves nothing of its own")
	workshop.queue_free()
	await process_frame

	# Back in the hall: the tray, the lamp, the lens, the sun.
	await _load_room()
	revisits = _room.revisits
	var hand: Node = _room.inventory
	_expect(revisits.tray.slot_item == "flashlight", "The flashlight waits in the ring tray")
	revisits.tray.interact(null)
	_expect(hand.held_item == "flashlight" and TimeLink.tray_item() == "", "Taking it empties the tray")
	var optics: Node3D = _room.optics
	optics.exchange_item("J")
	_expect(hand.held_item == "flashlight", "The flashlight won't go in a lens mount")
	optics.exchange_item("F")
	_expect(optics.model.items.F == "flashlight" and hand.held_item == "", "The flashlight fits the lamp socket")
	optics.model.lamp_angle = (Model.SUN_DISC - Model.LAMP).angle()
	optics.refresh()
	_expect(optics.lamp_result.hit == "receiver" and not optics.lamp_result.won, "White light reaches the disc, but it wants sunlight")
	_expect(not _game.get_flag("egypt_sun_restored", false), "Not restored yet")
	optics.exchange_item("J")
	optics.exchange_item("N")
	_expect(optics.model.items.N == "lens_yellow", "The yellow lens moves to mount N")
	_expect(optics.lamp_result.won and _game.get_flag("egypt_sun_restored", false), "Yellow light on the disc restores Egypt's sun")
	_expect(not _game.get_flag("escape_prism_solved", false), "The lamp never opens Door 2")
	await process_frame
	egypt_light = _egypt_light(revisits)
	_expect(egypt_light and is_equal_approx(egypt_light.light_energy, full), "Egypt's room is lit again")
	_expect(revisits.scarab != null, "The Egyptian's thanks waits at the disc")
	revisits.scarab.interact(null)
	_expect("scarab" in _game.collected_cards, "The Sun Scarab joins the deck")

	# The lamp's aim and the flashlight survive a reload.
	await _load_room()
	_expect(_room.optics.model.items.F == "flashlight" and _room.optics.lamp_result.won, "The lamp stays where it was put")
	_expect(_room.revisits.scarab == null, "The scarab isn't offered twice")

	_room.queue_free()
	await process_frame
	_game.flags.clear()
	_game.completed_minigames.clear()
	_game.collected_cards.clear()
	print("Revisits: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _load_room() -> void:
	if is_instance_valid(_room):
		_room.queue_free()
		await process_frame
	_game.set_flag("room_visited")
	_room = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	for i in 4:
		await physics_frame
		await process_frame


func _egypt_light(revisits: Node3D) -> OmniLight3D:
	for light in revisits._egypt_lights:
		if is_instance_valid(light):
			return light
	return null


func _settle(story: Node) -> void:
	await process_frame
	var guard := 0
	while (story.busy or story.bubble.is_open()) and guard < 20000:
		story.bubble.advance()
		story.bubble.advance()
		await process_frame
		guard += 1


func _expect(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(description)
