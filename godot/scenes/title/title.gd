extends Control
## Title screen: Continue the latest save, start a New game in a new slot, or Load any slot.
## Slots are unlimited; Load game lists them newest first, each with its own Delete.
## Starting or loading here is what turns on autosave (see Game.autosave).

const Style := preload("res://ui/game_style.gd")
const SaveGame := preload("res://autoload/save_game.gd")
const INTRO_SCENE := "res://scenes/intro/intro.tscn"
const ROOM_SCENE := "res://scenes/room/room.tscn"
const EDITOR_SCENE := "res://scenes/dev/save_editor.tscn"
const DevMode := preload("res://autoload/dev_mode.gd")
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var continue_button: Button
var new_button: Button
var load_button: Button
var editor_button: Button  # Developer mode only.
var slot_buttons: Array[Button] = []  # One row per save, newest first.
var delete_buttons: Array[Button] = []
var slot_order: Array[int] = []  # The slot each row shows.
var _menu: VBoxContainer
var _slots: PanelContainer
var _slots_heading: Label
var _rows: VBoxContainer
var _back: Button
var _confirm_delete := -1  # A slot whose Delete was pressed once.
var _leaving := false


func _ready() -> void:
	theme = Style.theme()
	TouchControls.set_enabled(false)
	SaveGame.adopt_legacy()
	set_anchors_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/story_bg.gdshader")
	material.set_shader_parameter("top_color", Color(0.01, 0.02, 0.1))
	material.set_shader_parameter("bottom_color", Color(0.05, 0.15, 0.3))
	material.set_shader_parameter("stars", 1.0)
	bg.material = material
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 28)
	center.add_child(column)
	var title := Style.label("Pass The Game", 54, Style.PAPER, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_menu = VBoxContainer.new()
	_menu.custom_minimum_size.x = 300
	column.add_child(_menu)
	continue_button = _button(_menu, "Continue", _continue)
	new_button = _button(_menu, "New game", _new_game)
	load_button = _button(_menu, "Load game", _show_slots)
	if DevMode.enabled():
		editor_button = _button(_menu, "Save editor", func(): _go(EDITOR_SCENE))

	_slots = PanelContainer.new()
	_slots.custom_minimum_size.x = 560
	column.add_child(_slots)
	var list := VBoxContainer.new()
	_slots.add_child(list)
	_slots_heading = Style.label("", 22, Style.GOLD, true)
	list.add_child(_slots_heading)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 330
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	_back = _button(list, "Back", _show_menu)
	_show_menu()


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _show_menu() -> void:
	_slots.hide()
	_menu.show()
	var latest := SaveGame.latest_slot()
	continue_button.visible = latest >= 0
	load_button.disabled = latest < 0
	(continue_button if latest >= 0 else new_button).grab_focus()


func _show_slots() -> void:
	_confirm_delete = -1
	_refresh_slots()
	_menu.hide()
	_slots.show()
	(slot_buttons[0] if not slot_buttons.is_empty() else _back).grab_focus()


## Rebuilds one row per save, newest first. Delete takes a second press.
func _refresh_slots() -> void:
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	slot_buttons.clear()
	delete_buttons.clear()
	slot_order = SaveGame.slots_by_recent()
	_slots_heading.text = "Load game  ·  %d save%s" % [slot_order.size(), "" if slot_order.size() == 1 else "s"]
	for slot in slot_order:
		var path := SaveGame.slot_path(slot)
		var row := HBoxContainer.new()
		_rows.add_child(row)
		var open := _button(row, "Slot %d  ·  %s\n%s" % [slot + 1, SaveGame.describe(SaveGame.read(path)),
			_when(SaveGame.saved_at(path))], _choose_slot.bind(slot))
		open.alignment = HORIZONTAL_ALIGNMENT_LEFT
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var remove := _button(row, "Delete?  Press again" if slot == _confirm_delete else "Delete", _delete_slot.bind(slot))
		remove.add_theme_font_size_override("font_size", 15)
		slot_buttons.append(open)
		delete_buttons.append(remove)


func _delete_slot(slot: int) -> void:
	if _confirm_delete != slot:
		_confirm_delete = slot
		_refresh_slots()
		delete_buttons[slot_order.find(slot)].grab_focus()
		return
	_confirm_delete = -1
	SaveGame.erase(SaveGame.slot_path(slot))
	if SaveGame.slots_by_recent().is_empty():
		_show_menu()
		return
	_refresh_slots()
	slot_buttons[0].grab_focus()


func _continue() -> void:
	var latest := SaveGame.latest_slot()
	if latest >= 0 and Game.load_slot(latest):
		_go(ROOM_SCENE)


## Always a fresh slot, so starting over never touches an existing save.
func _new_game() -> void:
	Game.new_game(SaveGame.new_slot())
	_go(INTRO_SCENE)


func _choose_slot(slot: int) -> void:
	if Game.load_slot(slot):
		_go(ROOM_SCENE)


func _go(scene: String) -> void:
	if _leaving:
		return
	_leaving = true
	Sound.play("confirm", self)
	SceneManager.change_scene(scene)


func _unhandled_input(event: InputEvent) -> void:
	if _slots.visible and event.is_action_pressed("back"):
		get_viewport().set_input_as_handled()
		_show_menu()


## "Nov 17, 15:40" in local time.
static func _when(unix: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var t := Time.get_datetime_dict_from_unix_time(unix + bias)
	return "%s %d, %02d:%02d" % [MONTHS[t.month - 1], t.day, t.hour, t.minute]
