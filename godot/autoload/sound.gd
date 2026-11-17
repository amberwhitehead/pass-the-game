extends Node
## Bounded sound voices with scene ownership. Audio randomness never changes game RNG.
signal cue_played(cue: String, file: String, spatial: bool)
const Bank := preload("res://audio/sound_bank.gd")
const Mixer := preload("res://audio/sound_mixer.gd")
const Settings := preload("res://audio/sound_settings.gd")
const VOICES := 12
var mixer := Mixer.new()
var settings_open := false
var _streams: Dictionary = {}
var _last_file: Dictionary = {}
var _last_play: Dictionary = {}
var _flat: Array[AudioStreamPlayer] = []
var _spatial: Array[AudioStreamPlayer3D] = []
var _rng := RandomNumberGenerator.new()
var _serial := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	mixer.setup()
	for i in VOICES:
		var flat := AudioStreamPlayer.new()
		flat.bus = "Effects"
		add_child(flat)
		_flat.append(flat)
		var spatial := AudioStreamPlayer3D.new()
		spatial.bus = "Effects"
		spatial.unit_size = 3.0
		spatial.max_distance = 20.0
		spatial.max_db = -3.0
		add_child(spatial)
		_spatial.append(spatial)
	for definition: Dictionary in Bank.CUES.values():
		for file: String in definition.files:
			stream(file)
	var settings := Settings.new()
	settings.name = "SoundSettings"
	add_child(settings)

func stream(file: String) -> AudioStream:
	if not _streams.has(file):
		var path := Bank.DIRECTORY + file + ".ogg"
		_streams[file] = load(path) if ResourceLoader.exists(path) else null
	return _streams[file]

func play(cue: String, owner_node: Node, gain_db := 0.0, pitch := 1.0) -> Node:
	return _play(cue, owner_node, Vector3.INF, gain_db, pitch)

func play_at(cue: String, at: Vector3, owner_node: Node, gain_db := 0.0, pitch := 1.0) -> Node:
	return _play(cue, owner_node, at, gain_db, pitch)

func _play(cue: String, owner_node: Node, at: Vector3, gain_db: float, pitch: float) -> Node:
	if not Bank.CUES.has(cue) or not is_instance_valid(owner_node) or not owner_node.is_inside_tree():
		return null
	var data: Dictionary = Bank.CUES[cue]
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(cue, -100000)) < int(data.gap):
		return null
	var choices: Array = data.files.duplicate()
	if choices.size() > 1:
		choices.erase(_last_file.get(cue, ""))
	var file: String = choices[_rng.randi_range(0, choices.size() - 1)]
	var audio := stream(file)
	if audio == null:
		return null # A missing asset must not interrupt gameplay.
	_last_play[cue] = now
	_last_file[cue] = file
	var positional := at.is_finite()
	var voice: Node = _voice(_spatial if positional else _flat)
	voice.stop()
	voice.stream = audio
	voice.volume_db = float(data.db) + gain_db
	voice.pitch_scale = pitch * _rng.randf_range(1.0 - float(data.pitch), 1.0 + float(data.pitch))
	voice.set_meta("sound_owner", weakref(owner_node))
	_serial += 1
	voice.set_meta("serial", _serial)
	if positional:
		voice.global_position = at
	voice.play()
	cue_played.emit(cue, file, positional)
	return voice

func _voice(pool: Array) -> Node:
	var oldest: Node = pool[0]
	for voice: Node in pool:
		if not voice.playing:
			return voice
		if int(voice.get_meta("serial", 0)) < int(oldest.get_meta("serial", 0)):
			oldest = voice
	return oldest

func stop_owner(owner_node: Node) -> void:
	for pool: Array in [_flat, _spatial]:
		for voice: Node in pool:
			var reference: WeakRef = voice.get_meta("sound_owner") if voice.has_meta("sound_owner") else null
			var source: Node = reference.get_ref() if reference != null else null
			if source == owner_node or (is_instance_valid(source) and owner_node.is_ancestor_of(source)):
				voice.stop()

func _process(_delta: float) -> void:
	for pool: Array in [_flat, _spatial]:
		for voice: Node in pool:
			if not voice.playing:
				continue
			var reference: WeakRef = voice.get_meta("sound_owner") if voice.has_meta("sound_owner") else null
			var source: Node = reference.get_ref() if reference != null else null
			if not is_instance_valid(source) or not source.is_inside_tree():
				voice.stop()
