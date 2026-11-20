extends RefCounted
## Jump points into the Workshop's story, for the developer save editor. Each is a
## resume state (what Workshop.save_state() would write) at a clean moment in the story.
## Keep these in step with story.gd's flags if the story changes.

const ARRIVAL := 3 * 60 + 5   ## 3:05, the minute the twin arrives in these states.

const STAGES := [
	{"id": "start", "label": "From the start"},
	{"id": "loop", "label": "Twin arrived (alarm on)"},
	{"id": "ready", "label": "Ready to send Fuse"},
	{"id": "break", "label": "Loop closed, cat at the lever"},
]


## The resume state for a stage, or {} for a fresh start.
static func state_for(stage: String) -> Dictionary:
	var s := {
		"phase": "loop", "radio_on": false, "screws": 4, "tube": "tv", "tuned": true, "visits": 1,
		"icebox_open": false, "tin": "icebox", "tin_pos": Vector2(700, 730), "tin_open": false,
		"drawer_open": false, "drawer_items": true, "wire": "board",
		"dial": 3 * 60, "arrival": ARRIVAL, "lid": false, "yarn": false, "twin_yarn": true,
		"box": "wall", "box_pos": Vector2(700, 760), "blinds": false, "items": [],
	}
	match stage:
		"loop":
			return s
		"ready", "break":
			s.merge({"icebox_open": true, "tin": "floor", "tin_open": true, "drawer_open": true,
				"drawer_items": false, "wire": "machine", "dial": ARRIVAL, "lid": true, "yarn": true,
				"twin_yarn": false, "fuse_down": true, "items": ["flashlight"]}, true)
			if stage == "break":
				s.phase = "break"
				s.items = []
			return s
	return {}


## Which stage a saved resume state is, or "" when it's somewhere in between.
static func stage_of(progress: Variant) -> String:
	if progress is not Dictionary or progress.is_empty():
		return "start"
	for st in STAGES:
		var want := state_for(st.id)
		if not want.is_empty() and str(progress.get("phase")) == want.phase \
				and progress.get("lid") == want.lid and progress.get("wire") == want.wire \
				and str(progress.get("box")) == "wall":
			return st.id
	return ""
