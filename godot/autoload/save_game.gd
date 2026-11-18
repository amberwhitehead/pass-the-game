extends RefCounted
## Progress on disk, one file per slot. Game owns the state and decides when to save;
## this file only reads, writes and summarizes it. On the Web, user:// is kept in the
## browser's IndexedDB.

const DeckProgression := preload("res://minigames/cards/deck_progression.gd")
const SLOTS := 3
const VERSION := 1

const DEFAULT_PREFIX := "user://save_slot_"
const LEGACY_PATH := "user://savegame.cfg"  # The single save before slots existed.

## Tests point this elsewhere so they never touch the player's saves.
static var slot_prefix := DEFAULT_PREFIX


## Moves a pre-slot save into an empty slot 1. Only touches the player's real saves.
static func adopt_legacy() -> void:
	if slot_prefix != DEFAULT_PREFIX or not exists(LEGACY_PATH) or exists(slot_path(0)):
		return
	DirAccess.rename_absolute(ProjectSettings.globalize_path(LEGACY_PATH), ProjectSettings.globalize_path(slot_path(0)))


static func slot_path(slot: int) -> String:
	return "%s%d.cfg" % [slot_prefix, slot + 1]


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path)


static func write(state: Dictionary, path: String) -> Error:
	var config := ConfigFile.new()
	config.set_value("meta", "version", VERSION)
	config.set_value("meta", "saved_at", int(Time.get_unix_time_from_system()))
	for key: String in state:
		config.set_value("progress", key, state[key])
	return config.save(path)


## Returns an empty Dictionary for a missing, unreadable or incompatible save.
static func read(path: String) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path) != OK or int(config.get_value("meta", "version", 0)) != VERSION:
		return {}
	var state := {}
	if config.has_section("progress"):
		for key in config.get_section_keys("progress"):
			state[key] = config.get_value("progress", key)
	return state


## Unix time of the last write, or 0 for a missing or incompatible save.
static func saved_at(path: String) -> int:
	var config := ConfigFile.new()
	if config.load(path) != OK or int(config.get_value("meta", "version", 0)) != VERSION:
		return 0
	return int(config.get_value("meta", "saved_at", FileAccess.get_modified_time(path)))


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
