extends RefCounted
## Shared with the audition tool: edit cue files/mix in assets/audio/cues.json.
const DIRECTORY := "res://assets/audio/cc0/"
static var CUES: Dictionary = _load_cues()

static func _load_cues() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/cues.json"))
	if data is not Dictionary or data.get("version") != 1 or data.get("cues") is not Dictionary:
		push_error("Invalid audio cue configuration")
		return {}
	return data.cues
