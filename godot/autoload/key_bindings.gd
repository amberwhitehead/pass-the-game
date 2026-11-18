extends RefCounted
## Keyboard bindings: the one list of rebindable actions, their default physical keys,
## the saved overrides in user://controls.cfg, and the labels hints show.
## Only InputEventKey events are ever replaced; gamepad events and deadzones stay as
## Game._register_actions made them. Bindings are physical keys (key position), and
## labels come from the player's keyboard layout, so AZERTY players see their letters.

const DEFAULT_PATH := "user://controls.cfg"
const SECTION := "keyboard"
const FORMAT := 1
## Tests point this elsewhere so they never touch the player's preferences.
static var path := DEFAULT_PATH

## Display order. Every key listed is live; each is one row slot in Controls.
const ACTIONS := [
	{"action": "move_up", "label": "Walk forward", "keys": [KEY_W, KEY_UP]},
	{"action": "move_down", "label": "Walk back", "keys": [KEY_S, KEY_DOWN]},
	{"action": "strafe_left", "label": "Strafe left", "keys": [KEY_A]},
	{"action": "strafe_right", "label": "Strafe right", "keys": [KEY_D]},
	{"action": "move_left", "label": "Turn left", "keys": [KEY_LEFT]},
	{"action": "move_right", "label": "Turn right", "keys": [KEY_RIGHT]},
	{"action": "jump", "label": "Jump", "keys": [KEY_SPACE]},
	{"action": "interact", "label": "Interact", "keys": [KEY_E, KEY_ENTER, KEY_F]},
	{"action": "back", "label": "Back / pause", "keys": [KEY_ESCAPE, KEY_BACKSPACE]},
]


## action -> Array of physical keycodes, fresh each call.
static func defaults() -> Dictionary:
	var result := {}
	for entry: Dictionary in ACTIONS:
		result[entry.action] = (entry.keys as Array).duplicate()
	return result


static func action_label(action: String) -> String:
	for entry: Dictionary in ACTIONS:
		if entry.action == action:
			return entry.label
	return action


## The keyboard keys an action has right now, read from the InputMap itself.
static func current() -> Dictionary:
	var result := {}
	for entry: Dictionary in ACTIONS:
		var keys: Array = []
		if InputMap.has_action(entry.action):
			for event in InputMap.action_get_events(entry.action):
				if event is InputEventKey:
					keys.append(int(event.physical_keycode))
		result[entry.action] = keys
	return result


## Replaces only the keyboard events of each listed action.
static func apply(bindings: Dictionary) -> void:
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = int(key) as Key
			InputMap.action_add_event(action, event)


## Name of the action already holding key in bindings (other than the one slot), or "".
static func conflict(bindings: Dictionary, key: int, action: String, slot: int) -> String:
	for other: String in bindings:
		var keys: Array = bindings[other]
		for index in keys.size():
			if int(keys[index]) == key and not (other == action and index == slot):
				return other
	return ""


## Saved bindings validated against the defaults. Anything missing, malformed or
## conflicting falls back to defaults; the file itself is never changed or deleted.
static func load_saved() -> Dictionary:
	var result := defaults()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return result
	if int(config.get_value("meta", "format", 0)) != FORMAT:
		return result
	var candidate := defaults()
	for action: String in candidate:
		if not config.has_section_key(SECTION, action):
			continue  # Not saved: keeps its default.
		var saved: Variant = config.get_value(SECTION, action)
		if not saved is Array or (saved as Array).size() != (candidate[action] as Array).size():
			return result
		var keys: Array = []
		for value: Variant in saved:
			if not (value is int or value is float) or not valid_key(int(value)):
				return result
			keys.append(int(value))
		candidate[action] = keys
	for action: String in candidate:
		var keys: Array = candidate[action]
		for index in keys.size():
			if conflict(candidate, keys[index], action, index) != "":
				return result
	return candidate


static func save(bindings: Dictionary) -> Error:
	var config := ConfigFile.new()
	config.set_value("meta", "format", FORMAT)
	for action: String in bindings:
		config.set_value(SECTION, action, (bindings[action] as Array).duplicate())
	return config.save(path)


static func valid_key(key: int) -> bool:
	return key > 0 and key != KEY_UNKNOWN and not OS.get_keycode_string(key).is_empty()


## What the key says on this keyboard (layout-aware), e.g. "W", "Space", "Escape".
static func key_label(key: int) -> String:
	var printed := DisplayServer.keyboard_get_label_from_physical(key as Key) if DisplayServer.get_name() != "headless" else KEY_NONE
	var text := OS.get_keycode_string(printed if printed != KEY_NONE else key as Key)
	return text if not text.is_empty() else "Key %d" % key


## The action's first key (or index) as a label, for one-key hints.
static func label(action: String, index := 0) -> String:
	var keys: Array = current().get(action, [])
	if keys.is_empty():
		return "—"
	return key_label(int(keys[mini(index, keys.size() - 1)]))


## Every key of the action, e.g. "E / Enter / F".
static func labels(action: String, limit := 3) -> String:
	var keys: Array = current().get(action, [])
	var names: Array[String] = []
	for key in keys.slice(0, limit):
		names.append(key_label(int(key)))
	return " / ".join(names) if not names.is_empty() else "—"
