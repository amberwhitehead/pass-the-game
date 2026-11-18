extends "res://tests/test_suite.gd"
## Save file round trips, slots, autosave gating and batching, and the title screen.
## Uses its own slot files, so the player's real saves are never read or replaced.
const SaveGame := preload("res://autoload/save_game.gd")
const TITLE := "res://scenes/title/title.tscn"
var checks := 0
var failures := 0
var _game: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game = root.get_node("Game")
	SaveGame.slot_prefix = "user://test_save_slot_"
	_erase_all()
	_file_format()
	_slots()
	await _autosave()
	await _title_screen()
	_erase_all()
	_game.autosave = false
	_game.save_path = ""
	print("Save game: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _erase_all() -> void:
	for slot in SaveGame.SLOTS:
		SaveGame.erase(SaveGame.slot_path(slot))


func _file_format() -> void:
	var path := SaveGame.slot_path(0)
	check(SaveGame.read(path).is_empty() and SaveGame.saved_at(path) == 0, "A missing save reads as empty")
	var state := {"flags": {"escape_optics_state": {"head_angles": {"A": 1.5}, "items": ["prism", ""]}},
		"completed_minigames": {"newton": {"won": true, "pyramids": [{"pos": Vector2(.2, -.1), "color": Color(0, 1, 1)}]},
			"turing": {"won": true, "route": PackedVector2Array([Vector2(1, 2), Vector2(3, 4)])}},
		"collected_cards": ["champion", "aegis"]}
	check(SaveGame.write(state, path) == OK, "Progress writes to disk")
	var loaded := SaveGame.read(path)
	check(SaveGame.same_data(loaded, state), "Nested flags, colors, vectors and routes survive a round trip")
	check(loaded.completed_minigames.newton.pyramids[0].pos is Vector2 and loaded.completed_minigames.newton.pyramids[0].color is Color \
		and loaded.completed_minigames.turing.route is PackedVector2Array, "Godot types come back as real Godot types")
	var odd := {"v": Vector2(0.1, 1.0 / 3.0), "c": Color(0.92, 0.28, 0.72, 0.5)}
	SaveGame.write(odd, path)
	var exact := SaveGame.read(path)
	check(exact.v == odd.v and exact.c == odd.c and "0.92," in FileAccess.get_file_as_string(path),
		"Vector and color components are written short yet come back exactly")
	SaveGame.write(state, path)
	SaveGame.write({"flags": {"turns": {"A": -1}, "angle": 0.25}}, path)
	var numbers: Dictionary = SaveGame.read(path).flags
	check(is_equal_approx(float(numbers.turns.A), -1.0) and numbers.angle == 0.25, "Numbers come back as plain JSON numbers")
	check(SaveGame.same_data({"turn": 2}, {"turn": 2.0}) and not SaveGame.same_data({"turn": 2}, {"turn": 3}),
		"same_data treats 2 and 2.0 alike but still tells values apart")
	SaveGame.write(state, path)
	check(absi(SaveGame.saved_at(path) - int(Time.get_unix_time_from_system())) < 5, "Saves record when they were written")
	check(SaveGame.describe(state) == "Egypt ✓ · Roman Flow ✓ · 2/5 cards", "Slot summary lists wins and found cards")
	check(SaveGame.describe({}) == "Just started", "An empty save has a summary")
	var text := FileAccess.get_file_as_string(path)
	check(JSON.parse_string(text) is Dictionary and "\"version\": 2" in text and "\"Vector2\": [" in text \
		and "\"collected_cards\": [" in text and not "s:" in text, "Saves are readable JSON any tool can read")
	_write_text(path, text.replace("\"version\": 2", "\"version\": 3"))
	check(SaveGame.read(path).is_empty() and SaveGame.saved_at(path) == 0, "A save from another format version is ignored")
	_write_text(path, "{ not json")
	check(SaveGame.read(path).is_empty(), "A corrupt save reads as empty")
	SaveGame.write({"flags": {}}, path)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	document.progress = {"flags": {"probe": {"Object": ["RefCounted"]}, "res": {"Resource": ["res://icon.svg"]}}}
	_write_text(path, JSON.stringify(document))
	var probe: Dictionary = SaveGame.read(path).flags
	check(probe.probe is Dictionary and probe.res is Dictionary, "Saves never build objects or load resources, even when a file names one")
	check(SaveGame.encode({"node": RefCounted.new()}).node == null, "Objects cannot be written into a save")
	var damaged := [{"Vector2": ["a", 1]}, {"Vector2": [1]}, {"Color": "red"}, {"Vector2i": [1, null]},
		{"PackedVector2Array": [[1, 2], ["x", 2]]}, {"PackedColorArray": [3]}]
	check(damaged.all(func(tag): return SaveGame.decode(tag) is Dictionary),
		"Damaged type tags load as plain data instead of stopping the loader")
	check(SaveGame.decode({"PackedVector2Array": [[1, 2], [3, 4]]}) == PackedVector2Array([Vector2(1, 2), Vector2(3, 4)]),
		"Well-formed packed arrays still load")
	SaveGame.erase(path)
	check(not SaveGame.exists(path), "Erase removes the save")
	_migration()


## Version 1 saves were ConfigFiles; they convert once and keep their time.
func _migration() -> void:
	var cfg := "user://test_save_legacy.cfg"
	var json := SaveGame.slot_path(0)
	var state := {"flags": {"escape_prism_solved": true, "items": {"A": "prism"}}, "completed_minigames": {},
		"collected_cards": ["aegis"]}
	var config := ConfigFile.new()
	config.set_value("meta", "version", 1)
	config.set_value("meta", "saved_at", 1234)
	for key: String in state:
		config.set_value("progress", key, state[key])
	config.save(cfg)
	check(SaveGame.migrate_cfg(cfg, json), "A version 1 save converts")
	check(SaveGame.same_data(SaveGame.read(json), state) and SaveGame.saved_at(json) == 1234 and not SaveGame.exists(cfg),
		"Conversion keeps progress and save time and removes the old file")
	SaveGame.erase(json)
	_write_text(cfg, "[meta]\nversion=1\n[progress]\nflags={\"probe\": Object(RefCounted,\"script\":null)}\n")
	check(not SaveGame.migrate_cfg(cfg, json) and SaveGame.exists(cfg) and not SaveGame.exists(json),
		"An old save that could build objects is refused and left untouched")
	SaveGame.erase(cfg)
	_write_text("user://test_save_slot_1.cfg", "[meta]\nversion=1\n")
	SaveGame.adopt_legacy()
	check(SaveGame.exists("user://test_save_slot_1.cfg") and not SaveGame.exists(json),
		"Automatic conversion never runs on test slots")
	SaveGame.erase("user://test_save_slot_1.cfg")


func _slots() -> void:
	check(SaveGame.latest_slot() == -1 and SaveGame.first_empty_slot() == 0, "With no saves, slot 1 is free and nothing continues")
	_write_at(1, {"flags": {"escape_prism_solved": true}}, 100)
	_write_at(2, {}, 200)
	check(SaveGame.latest_slot() == 2, "Continue picks the most recently saved slot")
	check(SaveGame.first_empty_slot() == 0, "New game uses the first empty slot")
	_write_at(0, {}, 50)
	check(SaveGame.first_empty_slot() == -1, "Full slots leave no empty slot")
	_erase_all()


func _autosave() -> void:
	_game.autosave = false
	_game.save_path = ""
	_game.set_flag("room_visited")
	await create_timer(_save_wait()).timeout
	check(SaveGame.latest_slot() == -1, "Without autosave, changes never touch the disk")

	_game.flags["stale"] = true
	_game.new_game(1)
	check(_game.autosave and _game.flags.is_empty() and _game.completed_minigames.is_empty() \
		and _game.collected_cards.is_empty(), "New game clears progress and enables autosave")
	check(SaveGame.saved_at(SaveGame.slot_path(1)) != 0, "New game claims its slot immediately")
	var claimed := SaveGame.read(SaveGame.slot_path(1))
	_game.set_flag("escape_prism_solved")
	check(SaveGame.read(SaveGame.slot_path(1)) == claimed, "Saving waits briefly so rapid changes batch into one write")
	_game.collect_card("champion")
	_game.record_win("newton", {"won": true})
	await create_timer(_save_wait()).timeout
	check(SaveGame.read(SaveGame.slot_path(1)).get("collected_cards", []) == ["champion"], "Autosave writes after changes settle")

	_game.autosave = false
	_game.flags.clear()
	_game.completed_minigames.clear()
	_game.collected_cards.clear()
	check(_game.load_slot(1), "Loading a slot succeeds")
	check(_game.flags.get("escape_prism_solved", false) and _game.completed_minigames.has("newton") \
		and _game.collected_cards == ["champion"], "Loading restores flags, wins and found cards")
	check(_game.collected_cards.get_typed_builtin() == TYPE_STRING, "Found cards keep their typed array")
	check(_game.autosave and _game.save_path == SaveGame.slot_path(1), "Loading autosaves back to that slot")
	check(not _game.load_slot(2), "Loading an empty slot fails")

	_game.set_flag("pending_change")
	_game.new_game(0)
	check(SaveGame.read(SaveGame.slot_path(1)).get("flags", {}).has("pending_change"), "Switching slots writes the pending save first")
	_game.new_game(1)
	check(SaveGame.read(SaveGame.slot_path(1)).get("collected_cards", ["x"]).is_empty(), "New game in a used slot replaces it")
	_game.autosave = false
	_erase_all()


func _title_screen() -> void:
	var title: Control = await _open_title()
	check(not title.continue_button.visible and title.load_button.disabled, "With no saves, only New game is offered")
	title.queue_free()
	await process_frame

	_write_at(0, {"completed_minigames": {"newton": {"won": true}}}, 100)
	_write_at(2, {}, 300)
	title = await _open_title()
	check(title.continue_button.visible and not title.load_button.disabled, "Saves offer Continue and Load game")
	check(title.continue_button.has_focus(), "Continue has keyboard and gamepad focus")
	title.load_button.pressed.emit()
	check(title.slot_buttons[0].text.begins_with("Slot 1  ·  Egypt ✓") and title.slot_buttons[1].disabled,
		"Load game lists slot progress and disables empty slots")
	title._show_menu()
	title.new_button.pressed.emit()
	check(_game.save_path == SaveGame.slot_path(1), "New game starts in the first empty slot")
	title.queue_free()
	await process_frame
	_game.autosave = false

	title = await _open_title()
	title.new_button.pressed.emit()
	check(title.slot_buttons[0].visible and title._overwriting, "With every slot full, New game asks which slot to replace")
	title.slot_buttons[0].pressed.emit()
	check(SaveGame.read(SaveGame.slot_path(0)).has("completed_minigames") and "Replace" in title.slot_buttons[0].text,
		"Replacing a slot asks for a second press")
	title.slot_buttons[0].pressed.emit()
	check(SaveGame.read(SaveGame.slot_path(0)).get("completed_minigames", {"x": 1}).is_empty(), "The second press replaces the slot")
	title.queue_free()
	await process_frame
	_game.autosave = false


func _open_title() -> Control:
	var title: Control = load(TITLE).instantiate()
	root.add_child(title)
	await process_frame
	title._leaving = true  # Exercise the menu without leaving for the intro or hall.
	return title


func _write_at(slot: int, state: Dictionary, time: int) -> void:
	SaveGame.write(state, SaveGame.slot_path(slot), time)


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)


func _save_wait() -> float:
	return _game.SAVE_DELAY + 0.3


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
