extends Node
## Plays procedural songs live on the "Music" bus, crossfading between them.
##
##   var music := MusicPlayer.new()
##   music.songs = preload("res://minigames/arcade/songs.gd").SONGS   # id -> definition
##   add_child(music)
##   music.play("stage")        # crossfades from whatever was playing
##   music.stop()
##
## Samples are generated in _process into an AudioStreamGenerator, so the music pauses with
## its owner (set `paused`) and stops when the node leaves the tree.

const Song := preload("res://audio/music/song.gd")
const Synth := preload("res://audio/music/synth.gd")
const BUFFER_SECONDS := 0.2

signal song_finished(id: String)

var songs: Dictionary = {}       ## id -> song definition (see README.md)
var current := ""                ## The id playing (or fading in), "" when silent.
var paused := false:
	set(v):
		paused = v
		if _player:
			_player.stream_paused = v
var frames_pushed := 0           ## For checks: samples generated so far.

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _synths: Array = []          ## [id, Synth] pairs; older ones fading out.
var _played_out := ""            ## A one-shot song that finished: asking for it again does nothing.
static var _compiled := {}       ## Compiled songs, shared by every player.


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = Synth.RATE
	gen.buffer_length = BUFFER_SECONDS
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	# The non-threaded Web build defaults to "sample" playback, which can't play a
	# generator; ask for stream mixing for this player only.
	_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_player)
	_player.play()
	_player.stream_paused = paused
	_playback = _player.get_stream_playback()


## The compiled form of song `id` (compiled once, then cached).
func compiled(id: String) -> Dictionary:
	var key := "%s:%d" % [id, songs.get(id, {}).hash()]
	if not _compiled.has(key):
		var c := Song.compile(songs[id], Synth.RATE)
		for e in c.errors:
			push_error("Song %s: %s" % [id, e])
		_compiled[key] = c
	return _compiled[key]


## Starts song `id`, crossfading over `fade` seconds. Asking for the song already playing
## (or a one-shot jingle that just finished) does nothing, so callers can ask every frame.
func play(id: String, fade := 0.6) -> void:
	if id == current or id == _played_out or not songs.has(id):
		return
	_played_out = ""
	_fade_out_all(fade)
	var s := Synth.new(compiled(id))
	if not _synths.is_empty():
		s.gain = 0.0
		s.fade_to(1.0, fade * 0.5)
	_synths.append([id, s])
	current = id


func stop(fade := 0.6) -> void:
	_fade_out_all(fade)
	current = ""
	_played_out = ""


func _fade_out_all(fade: float) -> void:
	for pair in _synths:
		pair[1].fade_to(0.0, fade)


func _process(_delta: float) -> void:
	if _playback == null or paused:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	_playback.push_buffer(mix(frames))


## The next `frames` samples of everything playing, mixed.
func mix(frames: int) -> PackedVector2Array:
	var l := PackedFloat32Array()
	l.resize(frames)
	l.fill(0.0)
	var r := l.duplicate()
	for pair in _synths.duplicate():
		var s = pair[1]
		s.mix_into(l, r, frames)
		if s.finished or (s.fading_out() and s.gain <= 0.0):
			_synths.erase(pair)
			if s.finished and pair[0] == current:
				current = ""
				_played_out = pair[0]
				song_finished.emit(pair[0])
	frames_pushed += frames
	return Synth.to_frames(l, r)


## Underruns since playback started (should stay 0).
func skips() -> int:
	return _playback.get_skips() if _playback else 0


## Renders `seconds` of song `definition` offline, from the start.
static func render(definition: Dictionary, seconds: float) -> PackedVector2Array:
	var c := Song.compile(definition, Synth.RATE)
	return Synth.new(c).render(int(seconds * Synth.RATE))


## Writes stereo frames to a 16-bit WAV file.
static func save_wav(frames: PackedVector2Array, path: String) -> Error:
	var data := PackedByteArray()
	data.resize(frames.size() * 4)
	for i in frames.size():
		data.encode_s16(i * 4, int(clampf(frames[i].x, -1.0, 1.0) * 32767.0))
		data.encode_s16(i * 4 + 2, int(clampf(frames[i].y, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = Synth.RATE
	wav.data = data
	return wav.save_to_wav(path)
