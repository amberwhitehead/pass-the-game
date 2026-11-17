extends RefCounted
## Progress on disk. Game owns the state and decides when to save; this file only
## reads and writes it. On the Web, user:// is kept in the browser's IndexedDB.

const PATH := "user://savegame.cfg"
const VERSION := 1


static func exists(path := PATH) -> bool:
	return FileAccess.file_exists(path)


static func write(state: Dictionary, path := PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("meta", "version", VERSION)
	for key: String in state:
		config.set_value("progress", key, state[key])
	return config.save(path)


## Returns an empty Dictionary for a missing, unreadable or incompatible save.
static func read(path := PATH) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path) != OK or int(config.get_value("meta", "version", 0)) != VERSION:
		return {}
	var state := {}
	if config.has_section("progress"):
		for key in config.get_section_keys("progress"):
			state[key] = config.get_value("progress", key)
	return state


static func erase(path := PATH) -> void:
	if exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
