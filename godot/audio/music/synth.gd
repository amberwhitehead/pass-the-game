extends RefCounted
## Plays one compiled song (song.gd) into stereo samples: pulse, triangle and drum voices,
## ADSR envelopes, vibrato, arpeggios, a one-pole low-pass per channel and a stereo echo.
## Used live by music_player.gd and offline by render() for tests and WAV files.
##
## Control values (envelope, pitch) update every BLOCK samples; oscillators run per sample.

const RATE := 22050
const BLOCK := 32
const ARP_STEP := RATE / 30          ## Arpeggio note change: two 60 Hz frames, the chip classic.
const ECHO_DELAY := int(RATE * 0.21)
const ECHO_FEEDBACK := 0.38
const ECHO_MIX := 0.32
const MASTER := 0.9

var song: Dictionary
var pos := 0                ## Sample position within the song.
var finished := false       ## A non-looping song has played out, tails included.
var gain := 1.0             ## Fades multiply the whole output.
var _gain_target := 1.0
var _gain_step := 0.0
var _voices: Array[Voice] = []
var _echo := PackedFloat32Array()
var _echo_i := 0
var _tail := 0


func _init(compiled: Dictionary) -> void:
	song = compiled
	for ch: Dictionary in song.channels:
		_voices.append(Voice.new(ch))
	_echo.resize(ECHO_DELAY)
	_echo.fill(0.0)


## Ramps the output gain to `target` over `seconds`.
func fade_to(target: float, seconds: float) -> void:
	_gain_target = target
	_gain_step = absf(target - gain) / maxf(1.0, seconds * RATE / BLOCK)
	if seconds <= 0.0:
		gain = target


func fading_out() -> bool:
	return _gain_target <= 0.0


## Adds `frames` samples of this song into l/r (from index 0).
func mix_into(l: PackedFloat32Array, r: PackedFloat32Array, frames: int) -> void:
	if finished:
		return
	var send := PackedFloat32Array()
	send.resize(frames)
	send.fill(0.0)
	var dl := PackedFloat32Array()
	dl.resize(frames)
	dl.fill(0.0)
	var dr := PackedFloat32Array()
	dr.resize(frames)
	dr.fill(0.0)
	var done := 0
	var length: int = song.length
	while done < frames:
		var n := frames - done
		if length > 0 and pos < length:
			n = mini(n, length - pos)
		for v in _voices:
			v.render(pos, n, done, dl, dr, send)
		pos += n
		done += n
		if length > 0 and pos >= length:
			if song.loop:
				pos = song.loop_at
				for v in _voices:
					v.seek(pos)
			else:
				_tail += n
	# Echo, then gain ramps per block.
	var buf := _echo
	var ei := _echo_i
	var size := buf.size()
	for i in frames:
		var d := buf[ei]
		buf[ei] = send[i] + d * ECHO_FEEDBACK
		ei += 1
		if ei >= size:
			ei = 0
		dl[i] += d * ECHO_MIX
		dr[i] += d * ECHO_MIX * 0.75
	_echo_i = ei
	var g := gain
	var i := 0
	while i < frames:
		if g != _gain_target:
			g = move_toward(g, _gain_target, _gain_step)
		var end := mini(i + BLOCK, frames)
		var m := g * MASTER
		while i < end:
			l[i] += dl[i] * m
			r[i] += dr[i] * m
			i += 1
	gain = g
	if not song.loop and pos >= length and _tail > RATE:
		finished = true


## Renders `frames` samples on their own, clamped to [-1, 1], as stereo frames.
func render(frames: int) -> PackedVector2Array:
	var l := PackedFloat32Array()
	l.resize(frames)
	l.fill(0.0)
	var r := l.duplicate()
	mix_into(l, r, frames)
	return to_frames(l, r)


static func to_frames(l: PackedFloat32Array, r: PackedFloat32Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(l.size())
	for i in l.size():
		out[i] = Vector2(clampf(l[i], -1.0, 1.0), clampf(r[i], -1.0, 1.0))
	return out


## One channel: the event list and the oscillator, envelope and filter state.
class Voice:
	var wave: int
	var volume: float
	var pan_l: float
	var pan_r: float
	var attack: int
	var decay: int
	var sustain: float
	var release: int
	var vib_depth: float
	var vib_rate: float
	var vib_delay: int
	var lowpass: float
	var echo: float
	var starts: PackedInt32Array
	var gates: PackedInt32Array
	var notes: PackedInt32Array
	var vols: PackedFloat32Array
	var duties: PackedFloat32Array
	var arps: Array
	var idx := 0               ## Next event to start.
	var on := false            ## A note (or its release) is sounding.
	var age := 0               ## Samples since the current note started.
	var gate := 0
	var note := 60
	var vol := 1.0
	var duty := 0.5
	var arp := PackedInt32Array()
	var phase := 0.0
	var lp := 0.0              ## Low-pass filter memory.
	var lfsr := 0x7fff
	var noise_acc := 0.0

	func _init(ch: Dictionary) -> void:
		wave = ch.wave
		volume = ch.volume
		pan_l = sqrt(0.5 * (1.0 - ch.pan))
		pan_r = sqrt(0.5 * (1.0 + ch.pan))
		attack = ch.attack
		decay = ch.decay
		sustain = ch.sustain
		release = ch.release
		vib_depth = ch.vibrato
		vib_rate = ch.vibrato_rate
		vib_delay = ch.vibrato_delay
		lowpass = ch.lowpass
		echo = ch.echo
		starts = ch.starts
		gates = ch.gates
		notes = ch.notes
		vols = ch.vols
		duties = ch.duties
		arps = ch.arps

	## After a loop: the next event is the first at or after `at`. Sounding notes ring on.
	func seek(at: int) -> void:
		idx = starts.bsearch(at)

	func _start(i: int) -> void:
		on = true
		age = 0
		gate = gates[i]
		note = notes[i]
		vol = vols[i]
		duty = duties[i]
		arp = arps[i]
		if wave == 2:
			phase = 0.0

	## Envelope level `a` samples into a note held for `gate` samples.
	func _env(a: int) -> float:
		if a < gate:
			if a < attack:
				return float(a) / attack
			if a < attack + decay:
				return lerpf(1.0, sustain, float(a - attack) / decay)
			return sustain
		var held := _env(gate - 1) if gate > 0 else 0.0
		var t := float(a - gate) / release
		return 0.0 if t >= 1.0 else held * (1.0 - t)

	func render(song_pos: int, n: int, offset: int, l: PackedFloat32Array, r: PackedFloat32Array, send: PackedFloat32Array) -> void:
		var k := 0
		var count := starts.size()
		while k < n:
			var b := mini(BLOCK, n - k)
			var t := song_pos + k
			while idx < count and starts[idx] < t + b:
				_start(idx)
				idx += 1
			if not on:
				k += b
				continue
			var amp: float
			var freq: float
			if wave == 2:
				var drum := _drum(note, age)
				amp = drum.x * vol * volume
				freq = drum.y
				if age > RATE:
					on = false
			else:
				amp = _env(age) * vol * volume
				if age >= gate and amp <= 0.0:
					on = false
				var semis := float(note)
				if arp.size() > 0:
					semis += arp[(age / ARP_STEP) % arp.size()]
				if vib_depth > 0.0 and age > vib_delay:
					semis += vib_depth * sin(TAU * vib_rate * (age - vib_delay) / RATE)
				freq = 440.0 * pow(2.0, (semis - 69.0) / 12.0)
			var inc := freq / RATE
			var o := offset + k
			var ph := phase
			var y := lp
			var a := lowpass
			var pl := amp * pan_l
			var pr := amp * pan_r
			var e := echo
			if wave == 0:
				var w := duty
				for i in b:
					ph += inc
					if ph >= 1.0:
						ph -= 1.0
					y += a * ((1.0 if ph < w else -1.0) - y)
					l[o + i] += y * pl
					r[o + i] += y * pr
					send[o + i] += y * amp * e
			elif wave == 1:
				for i in b:
					ph += inc
					if ph >= 1.0:
						ph -= 1.0
					# A 16-step triangle, like the old sound chips.
					var s := floorf((absf(ph - 0.5) * 4.0 - 1.0) * 8.0) / 8.0
					y += a * (s - y)
					l[o + i] += y * pl
					r[o + i] += y * pr
			else:
				var noisy := note in [2, 4, 5, 11]
				var tone := note in [0, 2, 7, 9]
				var lf := lfsr
				var acc := noise_acc
				var noise_inc := (0.9 if note == 2 else 1.0) if noisy else 0.0
				var tone_mix := 0.55 if note == 2 else 1.0
				for i in b:
					var s := 0.0
					if tone:
						ph += inc
						if ph >= 1.0:
							ph -= 1.0
						s = sin(ph * TAU) * tone_mix
					if noisy:
						acc += noise_inc
						if acc >= 1.0:
							acc -= 1.0
							var bit := (lf ^ (lf >> 1)) & 1
							lf = (lf >> 1) | (bit << 14)
						s += (1.0 if lf & 1 else -1.0) * (0.6 if tone else 1.0)
					l[o + i] += s * pl
					r[o + i] += s * pr
				lfsr = lf
				noise_acc = acc
			phase = ph
			lp = y
			age += b
			k += b

	## Drum `id` at `a` samples: (level, tone frequency). Ids are the note letters' steps:
	## c kick, d snare, e closed hat, f open hat, g low tom, a high tom, b crash.
	static func _drum(id: int, a: int) -> Vector2:
		var t := float(a) / RATE
		match id:
			0:
				return Vector2(exp(-t * 22.0), 48.0 + 120.0 * exp(-t * 38.0))
			2:
				return Vector2(exp(-t * 26.0) * 0.8, 180.0 + 60.0 * exp(-t * 50.0))
			4:
				return Vector2(exp(-t * 90.0) * 0.35, 0.0)
			5:
				return Vector2(exp(-t * 12.0) * 0.3, 0.0)
			7:
				return Vector2(exp(-t * 14.0), 90.0 + 60.0 * exp(-t * 20.0))
			9:
				return Vector2(exp(-t * 14.0), 150.0 + 80.0 * exp(-t * 20.0))
			11:
				return Vector2(exp(-t * 4.0) * 0.35, 0.0)
		return Vector2.ZERO
