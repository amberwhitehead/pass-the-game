extends Control
## Developer save editor: open a save slot (or start blank), change wins, hall progress,
## found cards and unfinished minigames with controls, or anything at all in the raw
## JSON, then save to the slot, save as a new slot, or play it without saving.
## Opened from the title screen in developer mode (see DevMode), or with F6 in the editor.

const Style := preload("res://ui/game_style.gd")
const SaveGame := preload("res://autoload/save_game.gd")
const Edits := preload("res://scenes/dev/save_edits.gd")
const Progression := preload("res://minigames/cards/deck_progression.gd")
const Inventory := preload("res://scenes/escape/carry_inventory.gd")
const TITLE_SCENE := "res://scenes/title/title.tscn"
const ROOM_SCENE := "res://scenes/room/room.tscn"

var state: Dictionary = Edits.empty()
var slot := -1  # The slot being edited, or -1 for a blank save not yet written.
var slot_picker: OptionButton
var win_boxes := {}  # minigame id -> CheckBox
var card_boxes := {}  # card id -> CheckBox
var revealed_box: CheckBox
var door_box: CheckBox
var cradle_pickers: Array[OptionButton] = []
var held_picker: OptionButton
var raw: TextEdit
var save_button: Button
var save_new_button: Button
var play_button: Button
var back_button: Button
var warning_label: Label
var status_label: Label
var _summary: Label
var _progress_list: VBoxContainer
var _leaving := false


func _ready() -> void:
	theme = Style.theme()
	TouchControls.set_enabled(false)
	set_anchors_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Style.INK
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	scroll.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	var header := HBoxContainer.new()
	page.add_child(header)
	back_button = _button(header, "‹  Back", _back)
	header.add_child(Style.label("Save editor", 30, Style.PAPER, true))
	_summary = Style.label("", 16, Style.MUTED)
	_summary.size_flags_horizontal = SIZE_EXPAND_FILL
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_summary)
	slot_picker = OptionButton.new()
	slot_picker.item_selected.connect(func(index: int): _open(slot_picker.get_item_metadata(index)))
	header.add_child(slot_picker)

	var sections := HFlowContainer.new()
	sections.add_theme_constant_override("h_separation", 14)
	sections.add_theme_constant_override("v_separation", 14)
	page.add_child(sections)
	var wins := _section(sections, "Wins")
	for id: String in MiniGames.REGISTRY:
		win_boxes[id] = _check(wins, MiniGames.REGISTRY[id].title, func(on: bool): Edits.set_won(state, id, on))
	var hall := _section(sections, "Hall")
	revealed_box = _check(hall, "Egypt's prisms revealed", func(on: bool): Edits.set_flag(state, "escape_rewards_revealed", on))
	for index in 2:
		cradle_pickers.append(_picker(hall, "Cradle %d" % (index + 1), ["", "prism"],
			func(item: String): Edits.set_cradle(state, index, item)))
	held_picker = _picker(hall, "Holding", Inventory.ITEMS, func(item: String): Edits.set_flag(state, "escape_held_item", item))
	door_box = _check(hall, "Door 2 open (beam solved)", func(on: bool): Edits.set_flag(state, "escape_prism_solved", on))
	hall.add_child(Style.label("Optics layout: edit in raw JSON (escape_optics_state)", 13, Style.MUTED))
	var cards := _section(sections, "Found cards")
	for id: String in Progression.COLLECTIBLES:
		card_boxes[id] = _check(cards, Edits.card_name(id), func(on: bool): Edits.set_card(state, id, on))
	_progress_list = _section(sections, "Unfinished minigames")

	warning_label = Style.label("", 15, Style.GOLD)
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(warning_label)

	page.add_child(Style.eyebrow("Raw JSON: everything in the save"))
	raw = TextEdit.new()
	raw.custom_minimum_size.y = 260
	raw.add_theme_font_size_override("font_size", 13)
	page.add_child(raw)
	var raw_row := HBoxContainer.new()
	page.add_child(raw_row)
	_button(raw_row, "Apply JSON", _apply_raw)
	_button(raw_row, "Reset JSON", _refresh)

	var actions := HBoxContainer.new()
	page.add_child(actions)
	save_button = _button(actions, "Save", _save)
	save_new_button = _button(actions, "Save as new slot", _save_new)
	play_button = _button(actions, "Play (unsaved)", _play)
	status_label = Style.label("", 15, Style.TEAL)
	page.add_child(status_label)

	_fill_picker(SaveGame.latest_slot())
	_open(SaveGame.latest_slot())


func _section(parent: Control, heading: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 270
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(Style.eyebrow(heading))
	return box


func _check(parent: Control, text: String, changed: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.toggled.connect(func(on: bool):
		changed.call(on)
		_refresh())
	parent.add_child(box)
	return box


func _picker(parent: Control, text: String, items: Array, changed: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Style.label(text, 16)
	label.custom_minimum_size.x = 80
	row.add_child(label)
	var picker := OptionButton.new()
	for item: String in items:
		picker.add_item(Inventory.item_name(item) if item != "" else "Empty")
		picker.set_item_metadata(picker.item_count - 1, item)
	picker.item_selected.connect(func(index: int):
		changed.call(picker.get_item_metadata(index))
		_refresh())
	row.add_child(picker)
	return picker


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## Lists "Blank save" then every slot newest first, selecting the given slot.
func _fill_picker(selected: int) -> void:
	slot_picker.clear()
	slot_picker.add_item("Blank save (not yet saved)")
	slot_picker.set_item_metadata(0, -1)
	for each in SaveGame.slots_by_recent():
		var path := SaveGame.slot_path(each)
		slot_picker.add_item("Slot %d  ·  %s" % [each + 1, SaveGame.describe(SaveGame.read(path))])
		slot_picker.set_item_metadata(slot_picker.item_count - 1, each)
	for index in slot_picker.item_count:
		if slot_picker.get_item_metadata(index) == selected:
			slot_picker.select(index)


func _open(which: int) -> void:
	slot = which
	var loaded := SaveGame.read(SaveGame.slot_path(which)) if which >= 0 else {}
	state = Edits.normalize(loaded if not loaded.is_empty() else Edits.empty())
	status_label.text = "Editing slot %d" % (which + 1) if which >= 0 else "Editing a blank save"
	_refresh()


## Shows the state in every control (without re-triggering their edits) and the raw JSON.
func _refresh() -> void:
	for id: String in win_boxes:
		win_boxes[id].set_pressed_no_signal(state.completed_minigames.has(id))
	for id: String in card_boxes:
		card_boxes[id].set_pressed_no_signal(id in state.collected_cards)
	revealed_box.set_pressed_no_signal(bool(Edits.flag(state, "escape_rewards_revealed")))
	door_box.set_pressed_no_signal(bool(Edits.flag(state, "escape_prism_solved")))
	var contents := Edits.cradles(state)
	for index in 2:
		_select(cradle_pickers[index], contents[index])
	_select(held_picker, Edits.held(state))
	for child in _progress_list.get_children().slice(1):
		child.queue_free()
	var progress := Edits.minigame_progress(state)
	if progress.is_empty():
		_progress_list.add_child(Style.label("None", 16, Style.MUTED))
	for id: String in progress:
		var row := HBoxContainer.new()
		_progress_list.add_child(row)
		var game_title := Style.label(MiniGames.REGISTRY.get(id, {}).get("title", id), 16)
		game_title.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(game_title)
		_button(row, "Clear", func():
			Edits.clear_progress(state, id)
			_refresh())
	var problems := Edits.warnings(state)
	warning_label.text = "" if problems.is_empty() else "⚠ " + "\n⚠ ".join(problems)
	_summary.text = SaveGame.describe(state)
	raw.text = JSON.stringify(SaveGame.encode(state), "\t", true, true)
	save_button.disabled = slot < 0


func _select(picker: OptionButton, item: String) -> void:
	for index in picker.item_count:
		if picker.get_item_metadata(index) == item:
			picker.select(index)
			return
	picker.select(-1)  # Something the controls don't offer; the raw JSON shows it.


## Replaces the whole save with the raw JSON, if it parses to an object.
func _apply_raw() -> void:
	var parsed: Variant = JSON.parse_string(raw.text)
	if not parsed is Dictionary:
		status_label.text = "The raw JSON isn't a valid JSON object; nothing changed."
		return
	state = Edits.normalize(SaveGame.decode(parsed))
	status_label.text = "Applied the raw JSON."
	_refresh()


func _save() -> void:
	if slot >= 0 and SaveGame.write(state, SaveGame.slot_path(slot)) == OK:
		status_label.text = "Saved slot %d." % (slot + 1)
		_fill_picker(slot)


func _save_new() -> void:
	var fresh := SaveGame.new_slot()
	if SaveGame.write(state, SaveGame.slot_path(fresh)) == OK:
		slot = fresh
		status_label.text = "Saved as new slot %d." % (slot + 1)
		_fill_picker(slot)
		_refresh()


## Loads this state into the hall without a save slot, so playing it writes nothing.
func _play() -> void:
	Game.play_unsaved(state)
	_go(ROOM_SCENE)


func _back() -> void:
	_go(TITLE_SCENE)


func _go(scene: String) -> void:
	if _leaving:
		return
	_leaving = true
	SceneManager.change_scene(scene)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back") and not raw.has_focus():
		get_viewport().set_input_as_handled()
		_back()
