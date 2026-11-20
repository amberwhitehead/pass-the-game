extends RefCounted
## Compiles a song definition (see README.md) into per-channel event arrays the synth plays.
##
##   var song := Song.compile(definition, Synth.RATE)
##   if not song.errors.is_empty(): push_error(song.errors)
##
## The result is a plain Dictionary:
##   {"name", "rate", "length" (samples), "loop" (bool), "loop_at" (samples),
##    "beat" (samples per quarter note), "channels": [channel...], "errors": [String]}
## where each channel has its instrument settings and parallel packed arrays of events:
##   starts, gates (samples the note is held), notes (MIDI note, or drum number), vols (0..1),
##   duties (pulse width), arps (Array of PackedInt32Array semitone offsets).

const WAVES := ["pulse", "triangle", "drums"]
const NOTE_STEPS := {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}
const DUTIES := [0.125, 0.25, 0.5, 0.75]
## Instrument settings and their defaults; a channel definition may override any of them.
const DEFAULTS := {
	"wave": "pulse", "volume": 0.2, "pan": 0.0, "duty": 0.5,
	"attack": 0.005, "decay": 0.12, "sustain": 0.65, "release": 0.08,
	"vibrato": 0.0, "vibrato_rate": 5.5, "vibrato_delay": 0.2,
	"lowpass": 1.0, "echo": 0.0, "octave": 4,
}


static func compile(definition: Dictionary, rate: int) -> Dictionary:
	var out := {
		"name": str(definition.get("name", "")), "rate": rate, "length": 0, "loop": bool(definition.get("loop", true)),
		"loop_at": 0, "beat": 0.0, "channels": [], "errors": [],
	}
	var tempo := float(definition.get("tempo", 120))
	if tempo <= 0.0:
		out.errors.append("tempo must be positive")
		tempo = 120.0
	var beat := rate * 60.0 / tempo
	out.beat = beat
	var macros: Dictionary = definition.get("macros", {})
	var lengths := []
	var loop_beats := -1.0
	for spec: Dictionary in definition.get("channels", []):
		var settings := DEFAULTS.duplicate()
		for k in spec:
			if k != "mml":
				settings[k] = spec[k]
		if not str(settings.wave) in WAVES:
			out.errors.append("unknown wave '%s'" % settings.wave)
			settings.wave = "pulse"
		var text := expand(str(spec.get("mml", "")), macros, out.errors)
		var parsed := _parse(text, settings, out.errors)
		lengths.append(parsed.beats)
		if parsed.loop_at >= 0.0:
			loop_beats = parsed.loop_at if loop_beats < 0.0 else minf(loop_beats, parsed.loop_at)
		var ch := {
			"wave": WAVES.find(str(settings.wave)),
			"volume": float(settings.volume),
			"pan": clampf(float(settings.pan), -1.0, 1.0),
			"attack": maxi(1, int(float(settings.attack) * rate)),
			"decay": maxi(1, int(float(settings.decay) * rate)),
			"sustain": clampf(float(settings.sustain), 0.0, 1.0),
			"release": maxi(1, int(float(settings.release) * rate)),
			"vibrato": float(settings.vibrato),
			"vibrato_rate": float(settings.vibrato_rate),
			"vibrato_delay": int(float(settings.vibrato_delay) * rate),
			"lowpass": clampf(float(settings.lowpass), 0.01, 1.0),
			"echo": clampf(float(settings.echo), 0.0, 1.0),
			"starts": PackedInt32Array(), "gates": PackedInt32Array(), "notes": PackedInt32Array(),
			"vols": PackedFloat32Array(), "duties": PackedFloat32Array(), "arps": [],
		}
		for e: Array in parsed.events:
			ch.starts.append(int(round(e[0] * beat)))
			ch.gates.append(maxi(1, int(round(e[1] * beat))))
			ch.notes.append(e[2])
			ch.vols.append(e[3])
			ch.duties.append(e[4])
			ch.arps.append(e[5])
		out.channels.append(ch)
	var longest := 0.0
	for l in lengths:
		longest = maxf(longest, l)
	if out.loop:
		for i in lengths.size():
			if absf(lengths[i] - longest) > 0.001:
				out.errors.append("channel %d is %.2f beats long but the longest is %.2f; looping songs need equal lengths" % [i + 1, lengths[i], longest])
	out.length = int(round(longest * beat))
	out.loop_at = int(round(maxf(loop_beats, 0.0) * beat))
	return out


## Expands {macro} references and [ ... ]n repeats (with | to skip the rest of the body on
## the last pass) into a flat MML string.
static func expand(text: String, macros: Dictionary, errors: Array) -> String:
	var s := text
	for depth in 8:
		var changed := false
		for name in macros:
			var token := "{%s}" % name
			if s.contains(token):
				s = s.replace(token, " %s " % macros[name])
				changed = true
		if not changed:
			break
	var leftover := RegEx.create_from_string("\\{[^}]*\\}").search(s)
	if leftover:
		errors.append("unknown macro %s" % leftover.get_string())
		s = s.replace(leftover.get_string(), "")
	var inner := RegEx.create_from_string("\\[([^\\[\\]]*)\\](\\d*)")
	for guard in 200:
		var m := inner.search(s)
		if m == null:
			break
		var body := m.get_string(1)
		var times := int(m.get_string(2)) if m.get_string(2) != "" else 2
		var parts := body.split("|", true, 1)
		var full := body.replace("|", " ")
		var rep := ""
		for i in times:
			rep += " " + (parts[0] if i == times - 1 and parts.size() > 1 else full) + " "
		s = s.substr(0, m.get_start()) + rep + s.substr(m.get_end())
	if s.contains("[") or s.contains("]"):
		errors.append("unbalanced [ ] repeat")
		s = s.replace("[", " ").replace("]", " ")
	return s


## Reads a flat MML string into [start_beat, length_beats, note, vol, duty, arp] events.
static func _parse(text: String, settings: Dictionary, errors: Array) -> Dictionary:
	var events := []
	var t := 0.0
	var octave := int(settings.octave)
	var default_len := 0.5
	var vol := 1.0
	var gate := 7.0 / 8.0
	var duty := float(settings.duty)
	var transpose := 0
	var arp := PackedInt32Array()
	var loop_at := -1.0
	var drums := str(settings.wave) == "drums"
	var i := 0
	var n := text.length()
	while i < n:
		var raw := text[i]
		i += 1
		if raw == "L":
			loop_at = t
			continue
		var ch := raw.to_lower()
		if ch in [" ", "\t", "\n", "\r", "|"]:
			continue
		if NOTE_STEPS.has(ch) or ch == "r":
			var semis := 0 if ch == "r" else int(NOTE_STEPS[ch])
			while i < n and text[i] in ["+", "#", "-"]:
				semis += -1 if text[i] == "-" else 1
				i += 1
			var len_read := _length(text, i, default_len)
			i = len_read[1]
			var beats: float = len_read[0]
			# ^len extends; & joins the next note of the same pitch.
			while i < n and text[i] in ["^", "&"]:
				var tie := text[i]
				i += 1
				if tie == "&":
					while i < n and text[i] == " ":
						i += 1
					if i < n and NOTE_STEPS.has(text[i].to_lower()):
						i += 1
						while i < n and text[i] in ["+", "#", "-"]:
							i += 1
				var more := _length(text, i, default_len)
				i = more[1]
				beats += more[0]
			if ch != "r":
				var note := (12 * (octave + 1) + semis + transpose) if not drums else semis
				var held := beats if drums else beats * gate
				events.append([t, held, note, vol, duty, arp])
			t += beats
		elif ch == "o":
			var r := _int(text, i)
			if r[1] == i:
				errors.append("o needs a number")
			octave = r[0]
			i = r[1]
		elif ch == ">":
			octave += 1
		elif ch == "<":
			octave -= 1
		elif ch == "l":
			var r := _length(text, i, default_len)
			default_len = r[0]
			i = r[1]
		elif ch == "v":
			var r := _int(text, i)
			vol = clampf(r[0] / 15.0, 0.0, 1.0)
			i = r[1]
		elif ch == "q":
			var r := _int(text, i)
			gate = clampf(r[0] / 8.0, 0.05, 1.0)
			i = r[1]
		elif ch == "@":
			var r := _int(text, i)
			duty = DUTIES[clampi(r[0], 0, DUTIES.size() - 1)]
			i = r[1]
		elif ch == "k":
			var r := _int(text, i)
			transpose = r[0]
			i = r[1]
		elif ch == "%":
			# %0,4,7 arpeggiates each note through those offsets; %0 (or %) turns it off.
			var offsets := PackedInt32Array()
			while true:
				var r := _int(text, i)
				if r[1] == i:
					break
				offsets.append(r[0])
				i = r[1]
				if i < n and text[i] == ",":
					i += 1
				else:
					break
			arp = PackedInt32Array() if offsets.size() <= 1 else offsets
		else:
			errors.append("unexpected '%s' at %d" % [text[i - 1], i - 1])
	return {"events": events, "beats": t, "loop_at": loop_at}


## A length like 8, 4., 16 or 2.. at text[i] -> [beats, next index].
static func _length(text: String, i: int, default_len: float) -> Array:
	var r := _int(text, i)
	var beats := default_len if r[1] == i else 4.0 / maxf(1.0, float(r[0]))
	i = r[1]
	var add := beats * 0.5
	while i < text.length() and text[i] == ".":
		beats += add
		add *= 0.5
		i += 1
	return [beats, i]


## A (possibly negative) integer at text[i] -> [value, next index]; next == i if none.
static func _int(text: String, i: int) -> Array:
	var j := i
	if j < text.length() and text[j] == "-" and j + 1 < text.length() and text[j + 1].is_valid_int():
		j += 1
	while j < text.length() and text[j].is_valid_int():
		j += 1
	if j == i or (j == i + 1 and text[i] == "-"):
		return [0, i]
	return [int(text.substr(i, j - i)), j]
