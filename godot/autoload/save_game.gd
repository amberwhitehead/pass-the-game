extends RefCounted
## Progress on disk, one JSON file per slot. Game owns the state and decides when to save;
## this file only reads, writes and summarizes it. On the Web, user:// is kept in the
## browser's IndexedDB.
##
## Saves are ordinary JSON: objects, arrays, strings, numbers, booleans. Godot value types
## become one-key objects such as {"Vector2": [0.5, 0.2]} and are restored on read. Nothing
## else (objects, resources, callables) can be saved, so a file only ever holds plain data.
## Numbers come back as JSON numbers: readers convert with int()/float(), and code that
## compares whole saved structures uses same_data().

const DeckProgression := preload("res://minigames/cards/deck_progression.gd")
const SLOTS := 3
const VERSION := 2  # 1 was a ConfigFile (.cfg); see migrate_cfg().

const DEFAULT_PREFIX := "user://save_slot_"
const LEGACY_PATH := "user://savegame.cfg"  # The single save before slots existed.
## Text that would make a ConfigFile build objects or load resources while reading.
const UNSAFE_CFG := ["Object(", "Resource(", "SubResource(", "ExtResource("]

## Tests point this elsewhere so they never touch the player's saves.
static var slot_prefix := DEFAULT_PREFIX


static func slot_path(slot: int) -> String:
	return "%s%d.json" % [slot_prefix, slot + 1]


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path)


## saved_at defaults to now; migration passes the original time so Continue still
## picks the right slot.
static func write(state: Dictionary, path: String, saved_at := 0) -> Error:
	var time := saved_at if saved_at > 0 else int(Time.get_unix_time_from_system())
	var document := {"version": VERSION, "saved_at": time, "progress": encode(state)}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	# Tabs and sorted keys keep committed test saves readable and their diffs small;
	# full precision keeps every float exact.
	file.store_string(JSON.stringify(document, "\t", true, true) + "\n")
	return OK


## Godot value types and the JSON tag that stores each as a list of numbers.
const TAGGED := {TYPE_VECTOR2: "Vector2", TYPE_VECTOR2I: "Vector2i", TYPE_VECTOR3: "Vector3",
	TYPE_VECTOR3I: "Vector3i", TYPE_COLOR: "Color", TYPE_PACKED_VECTOR2_ARRAY: "PackedVector2Array",
	TYPE_PACKED_VECTOR3_ARRAY: "PackedVector3Array", TYPE_PACKED_COLOR_ARRAY: "PackedColorArray"}


## Turns saved state into plain JSON data. Unsupported values are dropped with an error.
static func encode(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return String(value)
		TYPE_DICTIONARY:
			var out := {}
			for key: Variant in value:
				if not (key is String or key is StringName):
					push_error("Save data keys must be strings, not %s" % type_string(typeof(key)))
					continue
				out[String(key)] = encode(value[key])
			return out
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
				TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			return Array(value).map(encode)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return {TAGGED[typeof(value)]: [_short(value.x), _short(value.y)]}
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return {TAGGED[typeof(value)]: [_short(value.x), _short(value.y), _short(value.z)]}
		TYPE_COLOR:
			return {"Color": [_short(value.r), _short(value.g), _short(value.b), _short(value.a)]}
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			return {TAGGED[typeof(value)]: Array(value).map(func(item): return encode(item).values()[0])}
	push_error("Cannot save a %s; saves hold plain data only" % type_string(typeof(value)))
	return null


## Vector and color components are single precision; written in full they read as
## 0.9200000166893005. Use the shortest decimal that converts back to the same value.
static func _short(component: Variant) -> Variant:
	if component is int:
		return component
	for decimals in range(1, 10):
		var candidate := String.num(component, decimals).to_float()
		if Vector2(candidate, 0).x == Vector2(component, 0).x:
			return candidate
	return component


## Restores tagged Godot types inside parsed JSON. Everything else stays plain data.
static func decode(value: Variant) -> Variant:
	if value is Array:
		return value.map(decode)
	if not value is Dictionary:
		return value
	if value.size() == 1:
		var tag: String = value.keys()[0]
		var numbers: Variant = value[tag]
		if tag in TAGGED.values():
			var made: Variant = _tagged(tag, numbers)
			if made != null:
				return made
	var out := {}
	for key: String in value:
		out[key] = decode(value[key])
	return out


## Builds an allow-listed type, or returns null (the caller keeps plain data) when the
## numbers are missing, the wrong count or not numbers, as in a hand-edited file.
static func _tagged(tag: String, n: Variant) -> Variant:
	var element: String = {"PackedVector2Array": "Vector2", "PackedVector3Array": "Vector3",
		"PackedColorArray": "Color"}.get(tag, "")
	if not n is Array:
		return null
	if element != "":
		var items := []
		for item: Variant in n:
			var made: Variant = _tagged(element, item)
			if made == null:
				return null
			items.append(made)
		match tag:
			"PackedVector2Array": return PackedVector2Array(items)
			"PackedVector3Array": return PackedVector3Array(items)
			"PackedColorArray": return PackedColorArray(items)
	if not n.all(func(x): return x is float or x is int):
		return null
	match [tag, n.size()]:
		["Vector2", 2]: return Vector2(n[0], n[1])
		["Vector2i", 2]: return Vector2i(int(n[0]), int(n[1]))
		["Vector3", 3]: return Vector3(n[0], n[1], n[2])
		["Vector3i", 3]: return Vector3i(int(n[0]), int(n[1]), int(n[2]))
		["Color", 4]: return Color(n[0], n[1], n[2], n[3])
	return null


## True when two values save identically, treating 2 and 2.0 as the same number.
static func same_data(a: Variant, b: Variant) -> bool:
	return _numbers_as_floats(encode(a)) == _numbers_as_floats(encode(b))


static func _numbers_as_floats(value: Variant) -> Variant:
	if value is int:
		return float(value)
	if value is Array:
		return value.map(_numbers_as_floats)
	if value is Dictionary:
		var out := {}
		for key: String in value:
			out[key] = _numbers_as_floats(value[key])
		return out
	return value


## The whole document (version, saved_at, encoded progress), or {} if unreadable.
static func _document(path: String) -> Dictionary:
	if not exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("version", 0)) != VERSION:
		return {}
	return parsed


## Returns an empty Dictionary for a missing, unreadable or incompatible save.
static func read(path: String) -> Dictionary:
	var progress: Variant = decode(_document(path).get("progress", {}))
	return progress if progress is Dictionary else {}


## Unix time of the last write, or 0 for a missing or incompatible save.
static func saved_at(path: String) -> int:
	return int(_document(path).get("saved_at", 0))


static func erase(path: String) -> void:
	if exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## The most recently saved slot, or -1 when no slot holds a usable save.
static func latest_slot() -> int:
	var best := -1
	var best_time := 0
	for slot in SLOTS:
		var time := saved_at(slot_path(slot))
		if time > best_time:
			best = slot
			best_time = time
	return best


static func first_empty_slot() -> int:
	for slot in SLOTS:
		if saved_at(slot_path(slot)) == 0:
			return slot
	return -1


## Converts a version 1 ConfigFile save to JSON at json_path and removes the old file.
## Refuses (and leaves the file alone) if its text could build objects when read.
static func migrate_cfg(cfg_path: String, json_path: String) -> bool:
	if not exists(cfg_path) or exists(json_path):
		return false
	var text := FileAccess.get_file_as_string(cfg_path)
	for marker in UNSAFE_CFG:
		if marker in text:
			push_warning("Not converting %s: it contains %s" % [cfg_path, marker])
			return false
	var config := ConfigFile.new()
	if config.parse(text) != OK or int(config.get_value("meta", "version", 0)) != 1:
		return false
	var state := {}
	if config.has_section("progress"):
		for key in config.get_section_keys("progress"):
			state[key] = config.get_value("progress", key)
	var saved := int(config.get_value("meta", "saved_at", FileAccess.get_modified_time(cfg_path)))
	if write(state, json_path, saved) != OK or not same_data(read(json_path), state):
		erase(json_path)
		return false
	erase(cfg_path)
	return true


## Converts the player's older saves: the pre-slot savegame.cfg into an empty slot 1, and
## version 1 .cfg slots to JSON. Only touches the player's real saves, never test slots.
static func adopt_legacy() -> void:
	if slot_prefix != DEFAULT_PREFIX:
		return
	for slot in SLOTS:
		migrate_cfg("%s%d.cfg" % [DEFAULT_PREFIX, slot + 1], slot_path(slot))
	migrate_cfg(LEGACY_PATH, slot_path(0))


## A short progress line for the slot list, e.g. "Egypt ✓ · Door 2 open · 3/5 cards".
static func describe(state: Dictionary) -> String:
	var flags: Dictionary = state.get("flags", {})
	var wins: Dictionary = state.get("completed_minigames", {})
	var parts: Array[String] = []
	for entry: Array in [["newton", "Egypt"], ["turing", "Roman Flow"], ["cards", "Little Brother"], ["cards_older", "Older Brother"]]:
		if wins.has(entry[0]):
			parts.append("%s ✓" % entry[1])
	if flags.get("escape_prism_solved", false):
		parts.append("Door 2 open")
	var cards: Array = state.get("collected_cards", [])
	if not cards.is_empty():
		parts.append("%d/%d cards" % [cards.size(), DeckProgression.COLLECTIBLES.size()])
	return " · ".join(parts) if not parts.is_empty() else "Just started"
