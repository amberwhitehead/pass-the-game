extends CanvasLayer
## Controls, opened from the pause menu (hall or minigame). Shows every keyboard binding
## with a Change button, plus how mouse, touch and gamepad play. Edits stay in a draft
## until Apply; Back returns to the pause menu. Navigation uses the built-in ui_* actions,
## so it keeps working whatever the gameplay keys are.
##
## Change waits for one fresh key press. Escape cancels; the Back / pause row has
## "Use Escape" so Escape can still be chosen. A key used by another action is refused
## with a message naming that action; nothing is swapped or unbound.

const Style := preload("res://ui/game_style.gd")
const KeyBindings := preload("res://autoload/key_bindings.gd")

signal closed

var apply_button: Button
var back_button: Button
var defaults_button: Button
var message: Label
var _veil: ColorRect
var _rows: Dictionary = {}  # action -> Array of {"key": Label, "change": Button}
var _draft: Dictionary = {}
var _applied: Dictionary = {}
var _capture_action := ""
var _capture_slot := -1
var _ignore_until_release: Dictionary = {}  # physical key held when capture began
var _confirm_back := false
var _confirm_defaults := false


func _ready() -> void:
	layer = 115  # Above the pause menu (110), below Sound settings (200) and fades.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.theme = Style.theme()
	_veil.color = Color(Style.INK, .9)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.panel(Style.PANEL, Style.GOLD.darkened(.4), 24))
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(Style.eyebrow("Preferences"))
	column.add_child(Style.label("Controls", 26, Style.PAPER, true))
	var about := Style.label("Mouse: in the hall the game takes the cursor and moving the mouse looks around; "
		+ "click the game once if it asks. Menus and puzzles give the cursor back.\n"
		+ "Touch: on-screen pad to walk and turn, A to interact, B to go back; drag to look.\n"
		+ "Gamepad: left stick walks and strafes, right stick looks, D-pad walks and turns, A interacts, B goes back.\n"
		+ "Touch and gamepad controls are not changed here.", 13, Style.MUTED)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size.x = 700
	column.add_child(about)
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true  # Arrow-key navigation keeps the focused row in view.
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for entry: Dictionary in KeyBindings.ACTIONS:
		_add_row(list, entry)
	message = Style.label("", 15, Style.GOLD)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(700, 44)
	column.add_child(message)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	defaults_button = _button(actions, "Restore defaults", _on_defaults)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	apply_button = _button(actions, "Apply", _on_apply)
	back_button = _button(actions, "Back", _on_back)
	_veil.hide()


func _add_row(list: VBoxContainer, entry: Dictionary) -> void:
	var row := HBoxContainer.new()
	list.add_child(row)
	var name_label := Style.label(entry.label, 16)
	name_label.custom_minimum_size.x = 150
	row.add_child(name_label)
	var slots: Array = []
	for index in (entry.keys as Array).size():
		var key := Style.label("", 16, Style.GOLD)
		key.custom_minimum_size.x = 100
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(key)
		var change := _button(row, "Change", _begin_capture.bind(entry.action, index))
		change.tooltip_text = "Change %s key %d" % [entry.label, index + 1]
		slots.append({"key": key, "change": change})
		if entry.action == "back":
			var escape := _button(row, "Use Escape", _use_escape.bind(index))
			escape.add_theme_font_size_override("font_size", 13)
			slots[index]["escape"] = escape
	_rows[entry.action] = slots


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func is_open() -> bool:
	return _veil.visible


func is_capturing() -> bool:
	return not _capture_action.is_empty()


func open() -> void:
	_applied = KeyBindings.current()
	_draft = _applied.duplicate(true)
	_capture_action = ""
	_reset_confirms()
	message.text = ""
	_refresh()
	_veil.show()
	_first_change().grab_focus()


## Closes without applying anything still in the draft.
func close() -> void:
	if not is_open():
		return
	_capture_action = ""
	_veil.hide()
	closed.emit()


func has_unapplied_changes() -> bool:
	return _draft != _applied


func _first_change() -> Button:
	return _rows[KeyBindings.ACTIONS[0].action][0].change


func _refresh() -> void:
	for action: String in _rows:
		var slots: Array = _rows[action]
		for index in slots.size():
			var capturing := action == _capture_action and index == _capture_slot
			var keys: Array = _draft.get(action, [])
			var text := "Press a key…" if capturing else \
				(KeyBindings.key_label(int(keys[index])) if index < keys.size() else "—")
			slots[index].key.text = text
	apply_button.disabled = not has_unapplied_changes()


func _begin_capture(action: String, slot: int) -> void:
	_reset_confirms()
	_capture_action = action
	_capture_slot = slot
	# The Enter or Space that pressed Change is still down; ignore it until it is released.
	_ignore_until_release.clear()
	for key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if Input.is_physical_key_pressed(key):
			_ignore_until_release[key] = true
	message.text = "Press a key for %s. Escape cancels." % KeyBindings.action_label(action)
	_refresh()


func _end_capture(text: String) -> void:
	var button: Button = _rows[_capture_action][_capture_slot].change
	_capture_action = ""
	_capture_slot = -1
	message.text = text
	_refresh()
	button.grab_focus()


func _offer(key: int) -> void:
	var action := _capture_action
	var slot := _capture_slot
	var current := int((_draft[action] as Array)[slot])
	if key == current:
		_end_capture("%s is still %s." % [KeyBindings.action_label(action), KeyBindings.key_label(key)])
		return
	var owner := KeyBindings.conflict(_draft, key, action, slot)
	if owner != "":
		# Stay in capture: the player can try another key or press Escape.
		message.text = "%s is already used for %s. Press another key, or Escape to cancel." \
			% [KeyBindings.key_label(key), KeyBindings.action_label(owner)]
		return
	(_draft[action] as Array)[slot] = key
	_end_capture("%s: %s. Apply to keep it." % [KeyBindings.action_label(action), KeyBindings.key_label(key)])


func _use_escape(slot: int) -> void:
	_capture_action = "back"
	_capture_slot = slot
	_offer(KEY_ESCAPE)
	if is_capturing():  # Refused: Escape belongs to the other Back slot already.
		_end_capture(message.text.replace(" Press another key, or Escape to cancel.", ""))


func _on_apply() -> void:
	_reset_confirms()
	if not has_unapplied_changes():
		message.text = "Nothing to apply."
		return
	KeyBindings.apply(_draft)
	_applied = _draft.duplicate(true)
	var error := KeyBindings.save(_applied)
	if error == OK:
		message.text = "Applied and saved."
	else:
		message.text = "Applied for this session, but the controls could not be saved (%s)." % error_string(error)
	_refresh()
	back_button.grab_focus()


func _on_back() -> void:
	_confirm_defaults = false
	defaults_button.text = "Restore defaults"
	if has_unapplied_changes() and not _confirm_back:
		_confirm_back = true
		back_button.text = "Discard changes?"
		message.text = "You have changes that are not applied. Press Back again to discard them, or Apply."
		return
	close()


func _on_defaults() -> void:
	_confirm_back = false
	back_button.text = "Back"
	if not _confirm_defaults:
		_confirm_defaults = true
		defaults_button.text = "Restore? Press again"
		message.text = "Restore every key to its default? You can still Back out before applying."
		return
	_reset_confirms()
	_draft = KeyBindings.defaults()
	message.text = "Defaults restored. Apply to keep them."
	_refresh()


func _reset_confirms() -> void:
	_confirm_back = false
	_confirm_defaults = false
	if back_button:
		back_button.text = "Back"
		defaults_button.text = "Restore defaults"


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if is_capturing():
		# Everything is consumed while waiting for a key, so nothing else reacts.
		get_viewport().set_input_as_handled()
		if event is InputEventKey:
			var key := int(event.physical_keycode)
			if not event.pressed:
				_ignore_until_release.erase(key)
				return
			if event.echo or _ignore_until_release.has(key) or key == 0:
				return
			if key == KEY_ESCAPE:
				_end_capture("Cancelled. %s is unchanged." % KeyBindings.action_label(_capture_action))
			elif KeyBindings.valid_key(key):
				_offer(key)
		elif (event is InputEventMouseButton and event.pressed) \
				or (event is InputEventJoypadButton and event.pressed):
			_end_capture("Cancelled. %s is unchanged." % KeyBindings.action_label(_capture_action))
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_on_back()


func _unhandled_input(_event: InputEvent) -> void:
	if is_open():
		get_viewport().set_input_as_handled()
