extends "res://tests/test_suite.gd"
## Asset availability, bounded playback, ownership and modal input regressions.
var checks := 0
var failures := 0
var heard: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var sound := root.get_node("Sound")
	sound.cue_played.connect(func(cue: String, _file: String, _spatial: bool): heard.append(cue))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/cc0_manifest.json"))
	check(manifest.license == "CC0-1.0", "audio source library is CC0")
	for asset: Dictionary in manifest.assets:
		var clip: AudioStream = sound.stream(asset.id)
		check(clip != null and clip.get_length() > 0, "decode " + asset.id)
	for cue: String in sound.Bank.CUES:
		var definition: Dictionary = sound.Bank.CUES[cue]
		check(not definition.files.is_empty(), "cue has a sound: " + cue)
		for file: String in definition.files:
			check(sound.stream(file) != null, "cue resolves: " + cue + " / " + file)
	var owner := Node.new()
	root.add_child(owner)
	var first: Node = sound.play("card_hand", owner)
	check(first != null, "valid cue starts a voice")
	check(sound.play("card_hand", owner) == null, "duplicate event is throttled")
	sound.stop_owner(owner)
	check(not first.playing, "scene exit stops owned voices")
	var position := Vector3(2, 1, 3)
	var positional: Node3D = sound.play_at("place", position, owner)
	check(positional != null and positional.global_position == position, "world cue uses its physical position")
	owner.free()
	await process_frame
	await process_frame
	check(not positional.playing, "freed owner cannot leave a lingering sound")
	var previous := ""
	for i in 20:
		sound._last_play.erase("card_draw")
		var voice: Node = sound.play("card_draw", sound)
		var file: String = voice.stream.resource_path
		check(file != previous, "successive variations avoid identical samples")
		previous = file
	check(sound._flat.size() == 12 and sound._spatial.size() == 12, "burst playback keeps voice pools bounded")
	sound.stop_owner(sound)
	seed(91)
	var expected := randi()
	seed(91)
	sound.play("confirm", sound)
	check(randi() == expected, "sound variation does not perturb gameplay RNG")
	var card_sound: GDScript = load("res://audio/card_sound.gd")
	var table := Control.new()
	root.add_child(table)
	for id: String in ["patch", "renewal", "bolt", "thunderbolt"]:
		var cue := "heal" if id in ["patch", "renewal"] else "bolt"
		sound._last_play.erase(cue)
		heard.clear()
		card_sound.before(table, {"type": "spell", "card": id, "side": "player", "target_side": "player" if cue == "heal" else "enemy"})
		check(heard == [cue], "spell kind chooses correct cue for " + id)
	sound.stop_owner(table)
	table.free()
	sound.mixer.forced_mute = true
	sound.mixer.set_muted(false)
	check(AudioServer.is_bus_mute(0), "test URL mute cannot be overridden by saved preferences")
	sound.mixer.set_level("Effects", 2.0)
	check(sound.mixer.levels.Effects == 1.0, "mixer clamps upper gain")
	sound.mixer.set_level("Effects", -1.0)
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Effects")) <= -79, "zero effects gain is silent")
	var room: Node = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(room)
	await physics_frame
	var settings: Node = sound.get_node("SoundSettings")
	settings._toggle(true)
	check(room.get_node("Player")._frozen(), "mixer blocks player movement")
	var cancel := InputEventAction.new()
	cancel.action = "back"
	cancel.pressed = true
	settings._input(cancel)
	check(not sound.settings_open, "Escape dismisses mixer")
	heard.clear()
	for i in 10:
		room.optics.refresh()
	check(heard.is_empty(), "unchanged optical render is silent")
	room.queue_free()
	await process_frame
	print("Audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
