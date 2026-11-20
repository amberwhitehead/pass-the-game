extends "res://tests/test_suite.gd"
## The Workshop radio's stations (minigames/workshop/radio_songs.gd): every station and the
## static compile cleanly, loop, last a sensible time, and render audible and unclipped,
## and the second pass of a loop sounds like the first.

const Song := preload("res://audio/music/song.gd")
const Synth := preload("res://audio/music/synth.gd")
const RadioSongs := preload("res://minigames/workshop/radio_songs.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var songs := RadioSongs.all()
	_expect(RadioSongs.STATIONS.size() == 3, "Three stations on the dial")
	for st: Dictionary in RadioSongs.STATIONS:
		_expect(songs.has(st.id) and st.name != "" and st.frequency != "", "Station '%s' is named and tuned" % st.id)
	_expect(RadioSongs.song(3) == RadioSongs.song(0), "The dial wraps around")
	_expect(songs.has("static") and SaveGameSafe.same(RadioSongs.static_noise(), songs.static), "The static is offered too")
	for id: String in songs:
		var c: Dictionary = Song.compile(songs[id], Synth.RATE)
		_expect(c.errors.is_empty(), "'%s' compiles cleanly %s" % [id, c.errors])
		_expect(c.loop, "'%s' loops" % id)
		var length: int = c.length
		var seconds := length / float(Synth.RATE)
		var lo := 1.0 if id == "static" else 28.0
		_expect(seconds >= lo and seconds <= 50.0, "'%s' lasts a radio-ish length (%.1f s)" % [id, seconds])
		var frames := Synth.new(c).render(int(seconds * 2.0 * Synth.RATE) + Synth.RATE)
		var peak := 0.0
		var sum := 0.0
		for f in frames:
			peak = maxf(peak, maxf(absf(f.x), absf(f.y)))
			sum += f.x * f.x + f.y * f.y
		var rms := sqrt(sum / (frames.size() * 2.0))
		_expect(peak <= 1.0, "'%s' never clips (peak %.3f)" % [id, peak])
		_expect(rms > (0.01 if id == "static" else 0.04), "'%s' is audible (rms %.3f)" % [id, rms])
		# One second into the first pass and into the second should be equally loud.
		var a := _rms(frames, Synth.RATE, Synth.RATE)
		var b := _rms(frames, length + Synth.RATE, Synth.RATE)
		_expect(absf(a - b) < 0.02, "'%s' plays the same after looping (%.3f vs %.3f)" % [id, a, b])
	print("Radio songs: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _rms(frames: PackedVector2Array, from: int, count: int) -> float:
	var sum := 0.0
	for i in range(from, mini(from + count, frames.size())):
		sum += frames[i].x * frames[i].x
	return sqrt(sum / maxf(1.0, count))


func _expect(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(description)


class SaveGameSafe:
	static func same(a: Variant, b: Variant) -> bool:
		return var_to_str(a) == var_to_str(b)
