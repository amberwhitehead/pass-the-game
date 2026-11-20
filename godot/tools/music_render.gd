extends Node
## Dev tool: renders procedural songs to WAV files for listening, and reports their level
## and how fast they render.
##   godot --headless --path godot res://tools/music_render.tscn -- --out=/some/dir [--seconds=40] [--songs=res://minigames/arcade/songs.gd]

const MusicPlayer := preload("res://audio/music/music_player.gd")
const Song := preload("res://audio/music/song.gd")
const Synth := preload("res://audio/music/synth.gd")


func _ready() -> void:
	var out := OS.get_user_data_dir()
	var seconds := 40.0
	var source := "res://minigames/arcade/songs.gd"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--seconds="):
			seconds = float(a.substr(10))
		elif a.begins_with("--songs="):
			source = a.substr(8)
	var songs: Dictionary = load(source).all()
	for id in songs:
		var c := Song.compile(songs[id], Synth.RATE)
		for e in c.errors:
			printerr("%s: %s" % [id, e])
		var length_s: float = c.length / float(Synth.RATE)
		var secs := seconds if c.loop else length_s + 1.5
		var t0 := Time.get_ticks_usec()
		var frames := Synth.new(c).render(int(secs * Synth.RATE))
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var peak := 0.0
		var sum := 0.0
		for f in frames:
			peak = maxf(peak, maxf(absf(f.x), absf(f.y)))
			sum += f.x * f.x + f.y * f.y
		var rms := sqrt(sum / maxf(1.0, frames.size() * 2.0))
		var path := "%s/%s.wav" % [out, id]
		MusicPlayer.save_wav(frames, path)
		print("%-6s %6.1fs song, rendered %5.1fs in %6.0f ms (%4.1fx realtime) peak %.3f rms %.3f -> %s" %
			[id, length_s, secs, ms, secs * 1000.0 / ms, peak, rms, path])
	get_tree().quit()
