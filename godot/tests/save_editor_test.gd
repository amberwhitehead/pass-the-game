extends "res://tests/test_suite.gd"
## The developer save editor: its edit rules and item warnings, then the real screen
## opening, editing, applying raw JSON, saving, and playing unsaved. Uses its own slots.
const SaveGame := preload("res://autoload/save_game.gd")
const Edits := preload("res://scenes/dev/save_edits.gd")
const DevMode := preload("res://autoload/dev_mode.gd")
var checks := 0
var failures := 0
var _game: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_game = root.get_node("Game")
	SaveGame.slot_prefix = "user://test_editor_slot_"
	_erase_all()
	_rules()
	await _screen()
	_erase_all()
	print("Save editor: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _rules() -> void:
	var state := Edits.empty()
	check(Edits.warnings(state).is_empty(), "A fresh save has every hall item accounted for")
	Edits.set_won(state, "newton", true)
	state.completed_minigames.newton["pyramids"] = [1]
	Edits.set_won(state, "newton", true)
	check(state.completed_minigames.newton.has("pyramids"), "Ticking an existing win keeps its details")
	Edits.set_won(state, "newton", false)
	check(not state.completed_minigames.has("newton"), "Unticking removes the win")
	Edits.set_card(state, "thunderbolt", true)
	Edits.set_card(state, "champion", true)
	check(state.collected_cards == ["champion", "thunderbolt"], "Found cards keep the game's own order")
	Edits.set_flag(state, "escape_held_item", "prism")
	check(Edits.warnings(state) == ["3 × Prism in the hall (expected 2)"], "A duplicated prism is flagged")
	Edits.set_cradle(state, 0, "")
	check(Edits.warnings(state).is_empty(), "Moving a prism from a cradle to the hand balances again")
	Edits.set_flag(state, "escape_optics_state", {"items": {"A": "prism", "B": "", "J": "", "K": "lens_blue", "L": "lens_yellow"}})
	check(Edits.warnings(state) == ["3 × Prism in the hall (expected 2)"], "Items on optics mounts are counted")
	Edits.set_flag(state, "escape_prism_solved", true)
	check("Door 2 is open but Egypt's prisms were never revealed" in Edits.warnings(state), "Skipped progress is flagged")
	check(Edits.normalize({"flags": "bad"}).flags is Dictionary and Edits.normalize({}).collected_cards is Array,
		"Damaged or missing containers are rebuilt")
	check(DevMode.enabled(), "Runs from the Godot editor binary count as developer mode")


func _screen() -> void:
	var saved := Edits.empty()
	Edits.set_won(saved, "turing", true)
	Edits.set_flag(saved, "minigame_progress", {"cards_older": {"seed": 3}})
	Edits.set_flag(saved, "talked_to_officer", true)
	SaveGame.write(saved, SaveGame.slot_path(0), 100)
	var editor: Control = load("res://scenes/dev/save_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	editor._leaving = true  # Exercise the screen without leaving it.
	check(editor.slot == 0 and editor.win_boxes.turing.button_pressed and not editor.save_button.disabled,
		"The editor opens the latest save and shows its wins")
	check(editor.slot_picker.item_count == 2, "The slot list offers a blank save and each slot")
	check(editor.back_button.get_parent().get_index() == 0 and editor.back_button.get_index() == 0,
		"Back is the first control at the top of the editor")

	editor.win_boxes.newton.button_pressed = true
	editor.card_boxes.aegis.button_pressed = true
	check(editor.state.completed_minigames.has("newton") and "aegis" in editor.state.collected_cards \
		and "\"aegis\"" in editor.raw.text, "Ticking boxes edits the save and the raw JSON follows")
	editor.held_picker.select(1)
	editor.held_picker.item_selected.emit(1)
	check(Edits.held(editor.state) == "prism" and "3 × Prism" in editor.warning_label.text, "The editor warns about a duplicated prism")
	editor.held_picker.select(0)
	editor.held_picker.item_selected.emit(0)
	check(editor.warning_label.text == "", "The warning clears once the items balance")

	var before: Dictionary = editor.state.duplicate(true)
	editor.raw.text = "{ not json"
	editor._apply_raw()
	check(SaveGame.same_data(editor.state, before) and "isn't a valid" in editor.status_label.text,
		"Invalid raw JSON changes nothing and says so")
	var edited: Dictionary = JSON.parse_string(JSON.stringify(SaveGame.encode(editor.state)))
	edited.flags["escape_prism_solved"] = true
	edited.flags["escape_rewards_revealed"] = true
	edited.flags["future_flag"] = {"Vector2": [1, 2]}
	editor.raw.text = JSON.stringify(edited)
	editor._apply_raw()
	check(editor.door_box.button_pressed and editor.state.flags.future_flag == Vector2(1, 2),
		"Raw JSON edits apply, including values the controls don't know")
	check(editor.state.flags.get("talked_to_officer", false), "Flags with no control are kept untouched")

	var clear := editor._progress_list.get_child(editor._progress_list.get_child_count() - 1).get_child(1) as Button
	clear.pressed.emit()
	check(Edits.minigame_progress(editor.state).is_empty(), "Clear removes a minigame's unfinished progress")

	editor.save_button.pressed.emit()
	var written := SaveGame.read(SaveGame.slot_path(0))
	check(written.completed_minigames.has("newton") and written.flags.get("escape_prism_solved", false) \
		and written.flags.future_flag == Vector2(1, 2), "Save writes the edited state to its slot")
	editor.save_new_button.pressed.emit()
	check(editor.slot == 1 and SaveGame.same_data(SaveGame.read(SaveGame.slot_path(1)), editor.state),
		"Save as new slot writes a new slot and switches to it")

	editor.slot_picker.select(0)
	editor.slot_picker.item_selected.emit(0)
	check(editor.slot == -1 and editor.save_button.disabled and editor.state.completed_minigames.is_empty(),
		"Choosing the blank save starts empty, and Save needs Save as new slot first")

	Edits.set_card(editor.state, "renewal", true)
	_game.flags.clear()
	editor.play_button.pressed.emit()
	check(_game.collected_cards == ["renewal"] and not _game.autosave and _game.save_path == "",
		"Play loads the edited state with nothing saved")
	check(SaveGame.slots() == [0, 1], "Playing unsaved writes no slot")
	editor.queue_free()
	await process_frame

	var title: Control = load("res://scenes/title/title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	check(title.editor_button != null and title.editor_button.get_parent() == title._menu,
		"The title screen offers the editor in developer mode")
	var settings: Node = root.get_node("Sound/SoundSettings")
	check(settings.get_children().filter(func(child): return child is Button).is_empty(),
		"There is no floating Sound button")
	title.sound_button.pressed.emit()
	check(root.get_node("Sound").settings_open, "The title screen's Sound item opens the mixer")
	settings._toggle(false)
	title.queue_free()
	await process_frame


func _erase_all() -> void:
	for slot in SaveGame.slots():
		SaveGame.erase(SaveGame.slot_path(slot))


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
