extends "res://tests/test_suite.gd"
## The procedural music module: MML parsing, timing, rendering levels, looping and
## one-shot songs, the live player's crossfades and the Music bus, and CHRONO RAIDER
## choosing the right song for each of its modes.

const Song := preload("res://audio/music/song.gd")
const Synth := preload("res://audio/music/synth.gd")
const MusicPlayer := preload("res://audio/music/music_player.gd")
const Songs := preload("res://minigames/arcade/songs.gd")
const Stage := preload("res://minigames/arcade/stage.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_parsing()
	_timing()
	_levels()
	await _player()
	await _arcade()
	print("Music: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _one(mml: String, extra := {}) -> Dictionary:
	var ch := {"wave": "pulse", "mml": mml}
	ch.merge(extra, true)
	return Song.compile({"tempo": 120, "loop": false, "channels": [ch]}, Synth.RATE)


func _parsing() -> void:
	var c := _one("o4 l4 c d e f")
	var ch: Dictionary = c.channels[0]
	_expect(c.errors.is_empty(), "A plain melody parses")
	_expect(Array(ch.notes) == [60, 62, 64, 65], "o4 c d e f are MIDI 60 62 64 65")
	var beat := Synth.RATE * 60 / 120
	_expect(Array(ch.starts) == [0, beat, beat * 2, beat * 3], "Quarter notes start one beat apart")
	_expect(Array(_one("o4 c+4 d-4 > c4 < c4").channels[0].notes) == [61, 61, 72, 60], "Sharps, flats and octave shifts")
	_expect(_one("c4. r8").length == beat * 2, "A dot adds half; a rest takes time")
	_expect(_one("c4^8 d4&d4").channels[0].starts.size() == 2 and _one("c4^8").length == roundi(beat * 1.5), "^ extends and & ties")
	var errors := []
	_expect(Song.expand("[c d|e]3", {}, errors).split(" ", false) == PackedStringArray(["c", "d", "e", "c", "d", "e", "c", "d"]),
		"[ ]3 repeats, and | skips the rest on the last pass")
	_expect(Song.expand("{x} {x}", {"x": "c"}, errors).split(" ", false).size() == 2 and errors.is_empty(), "Macros expand")
	Song.expand("{nope}", {}, errors)
	_expect(not errors.is_empty(), "An unknown macro is reported")
	_expect(not _one("o4 c4 z4").errors.is_empty(), "An unknown command is reported")
	var arp: Dictionary = _one("%0,4,7 c4 %0 c4").channels[0]
	_expect(Array(arp.arps[0]) == [0, 4, 7] and arp.arps[1].is_empty(), "% sets and clears an arpeggio")
	_expect(Array(_one("c4 d4 e4", {"wave": "drums"}).channels[0].notes) == [0, 2, 4], "Drum notes are kit numbers")
	var looped := Song.compile({"tempo": 120, "channels": [{"mml": "c4 L d4"}, {"mml": "r4 L e4"}]}, Synth.RATE)
	_expect(looped.loop and looped.loop_at == beat, "L marks the loop point")
	var uneven := Song.compile({"tempo": 120, "channels": [{"mml": "c4"}, {"mml": "c2"}]}, Synth.RATE)
	_expect(not uneven.errors.is_empty(), "A looping song with uneven channels is reported")
	for id in Songs.all():
		var song := Song.compile(Songs.all()[id], Synth.RATE)
		_expect(song.errors.is_empty(), "CHRONO RAIDER's '%s' compiles cleanly %s" % [id, song.errors])


func _timing() -> void:
	# At 150 BPM a 4/4 bar is 1.6 s.
	var c := Song.compile({"tempo": 150, "loop": true, "channels": [{"mml": "c1 c1"}]}, Synth.RATE)
	_expect(c.length == int(Synth.RATE * 3.2), "Two bars at 150 BPM last 3.2 s of samples")
	var stage := Song.compile(Songs.all().stage, Synth.RATE)
	var seconds: float = stage.length / float(Synth.RATE)
	_expect(seconds > 55.0 and seconds < 120.0, "The stage tune is a one-to-two minute loop (%.1f s)" % seconds)


func _levels() -> void:
	var t0 := Time.get_ticks_usec()
	var rendered := 0.0
	for id in Songs.all():
		var song := Song.compile(Songs.all()[id], Synth.RATE)
		var synth := Synth.new(song)
		var secs: float = 6.0 if song.loop else song.length / float(Synth.RATE) + 1.5
		var frames := synth.render(int(secs * Synth.RATE))
		rendered += secs
		var peak := 0.0
		var sum := 0.0
		var pinned := 0
		for f in frames:
			var p := maxf(absf(f.x), absf(f.y))
			peak = maxf(peak, p)
			sum += f.x * f.x + f.y * f.y
			if p >= 0.999:
				pinned += 1
		var rms := sqrt(sum / (frames.size() * 2.0))
		_expect(rms > 0.03 and rms < 0.4, "'%s' has a sensible level (rms %.3f)" % [id, rms])
		_expect(pinned == 0, "'%s' never clips (peak %.3f)" % [id, peak])
		if not song.loop:
			_expect(synth.finished, "The '%s' jingle finishes" % id)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	_expect(rendered * 1000.0 / ms > 4.0, "Rendering is comfortably faster than real time (%.0fx)" % (rendered * 1000.0 / ms))
	# A looping song keeps going past its end.
	var short := Song.compile({"tempo": 240, "channels": [{"mml": "c4 e4 g4 > c4"}]}, Synth.RATE)
	var synth := Synth.new(short)
	synth.render(short.length + 100)
	var after := synth.render(Synth.RATE / 4)
	var energy := 0.0
	for f in after:
		energy += absf(f.x)
	_expect(energy > 10.0 and not synth.finished, "A looping song plays on after its loop point")


func _player() -> void:
	_expect(AudioServer.get_bus_index("Music") >= 0, "There is a Music bus")
	_expect(Sound.mixer.levels.has("Music"), "The Sound panel's mixer has a Music level")
	var songs := {
		"a": {"tempo": 120, "channels": [{"mml": "o4 c1"}]},
		"b": {"tempo": 120, "channels": [{"mml": "o5 c1"}]},
		"jingle": {"tempo": 240, "loop": false, "channels": [{"mml": "c4"}]},
	}
	var music := MusicPlayer.new()
	music.songs = songs
	root.add_child(music)
	await process_frame
	_expect(music._player.bus == "Music", "Music plays on the Music bus")
	music.play("a")
	music.mix(1000)
	_expect(music.current == "a" and music._synths.size() == 1, "play() starts a song")
	music.play("a")
	_expect(music._synths.size() == 1, "Asking for the current song again does nothing")
	music.play("b", 0.2)
	_expect(music.current == "b" and music._synths.size() == 2, "A new song crossfades in over the old one")
	music.mix(int(Synth.RATE * 0.4))
	_expect(music._synths.size() == 1 and music._synths[0][0] == "b", "The old song is gone once it has faded")
	music.play("jingle", 0.05)
	music.mix(Synth.RATE * 3)
	_expect(music.current == "" and music._synths.is_empty(), "A jingle ends by itself")
	music.play("jingle")
	_expect(music.current == "", "A finished jingle doesn't restart while it is still requested")
	music.stop()
	music.play("jingle")
	_expect(music.current == "jingle", "...but plays again once something else was asked for")
	# Live: the generator is kept fed.
	music.play("a", 0.0)
	var before: int = music.frames_pushed
	for i in 30:
		await process_frame
	_expect(music.frames_pushed > before, "The live player keeps feeding the audio stream (%d frames)" % (music.frames_pushed - before))
	_expect(music.skips() == 0, "No audio underruns while playing (%d)" % music.skips())
	print("Music live: %d frames generated over 30 frames, %d underruns" % [music.frames_pushed - before, music.skips()])
	music.paused = true
	var held: int = music.frames_pushed
	for i in 5:
		await process_frame
	_expect(music.frames_pushed == held and music._player.stream_paused, "Pausing stops generation")
	music.queue_free()
	await process_frame


func _arcade() -> void:
	var game: Control = load("res://minigames/arcade/arcade.tscn").instantiate()
	root.add_child(game)
	for i in 3:
		await process_frame
	var s: Node2D = game.shooter
	_expect(game.music.current == "title", "The title screen plays the title tune")
	s.start()
	await process_frame
	_expect(game.music.current == "stage", "Starting a game plays the stage tune")
	s.stage_frame = Stage.BOSS_AT
	await process_frame
	_expect(game.music.current == "boss", "The boss warning brings in the boss tune")
	s.mode = "over"
	await process_frame
	_expect(game.music.current == "over", "Game over plays its jingle")
	s.to_title()
	await process_frame
	_expect(game.music.current == "title", "Back at the title, the title tune returns")
	s.mode = "clear"
	await process_frame
	_expect(game.music.current == "clear", "Clearing the stage plays its jingle")
	game.propagate_notification(Node.NOTIFICATION_DISABLED)
	_expect(game.music.paused, "The pause menu pauses the music")
	game.propagate_notification(Node.NOTIFICATION_ENABLED)
	_expect(not game.music.paused, "Resuming resumes it")
	game.queue_free()
	await process_frame


func _expect(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(description)
