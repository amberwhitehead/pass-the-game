extends CanvasLayer
## Escape menu over a paused hall or minigame. Callers open it only when "back" has no
## other job (releasing a wheel, closing a panel, leaving a solved puzzle...).

const Style := preload("res://ui/game_style.gd")
const TITLE_SCENE := "res://scenes/title/title.tscn"

signal closed

var resume_button: Button
var leave_button: Button
var sound_button: Button
var quit_button: Button
var _veil: ColorRect
var _place: Label
var _minigame: Node  # The minigame frozen under the menu, or null in the hall.
var _minigame_mode := Node.PROCESS_MODE_INHERIT
var _hall_was_paused := false
var _touch_was_enabled := true


func _ready() -> void:
	layer = 110  # Above minigames and the touch pad; below scene fades and Sound settings.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.theme = Style.theme()
	_veil.color = Color(Style.INK, .78)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.panel(Style.PANEL, Style.GOLD.darkened(.4), 30))
	panel.custom_minimum_size.x = 340
	center.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(Style.eyebrow("Paused"))
	_place = Style.label("", 26, Style.PAPER, true)
	column.add_child(_place)
	resume_button = _button(column, "Resume", close)
	leave_button = _button(column, "", _leave_minigame)
	sound_button = _button(column, "Sound", func(): Sound.get_node("SoundSettings").open())
	quit_button = _button(column, "Quit to title", _quit_to_title)
	_veil.hide()


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func is_open() -> bool:
	return _veil.visible


## Pauses the hall under the menu.
func open_hall() -> void:
	if is_open():
		return
	_minigame = null
	_hall_was_paused = get_tree().paused
	get_tree().paused = true
	_show("Refraction Hall")


## Freezes a running minigame under the menu. The hall is already paused behind it.
func open_minigame(game: Node, title: String) -> void:
	if is_open():
		return
	_minigame = game
	_minigame_mode = game.process_mode
	game.process_mode = Node.PROCESS_MODE_DISABLED
	leave_button.text = "Leave %s" % title
	_show(title)


func _show(place: String) -> void:
	_place.text = place
	leave_button.visible = _minigame != null
	quit_button.visible = _minigame == null
	_touch_was_enabled = TouchControls.is_enabled()
	TouchControls.set_enabled(false)
	_veil.show()
	resume_button.grab_focus()


func close() -> void:
	if not is_open():
		return
	_veil.hide()
	TouchControls.set_enabled(_touch_was_enabled)
	if is_instance_valid(_minigame):
		_minigame.process_mode = _minigame_mode
	elif _minigame == null:
		get_tree().paused = _hall_was_paused
	_minigame = null
	closed.emit()


func _leave_minigame() -> void:
	var game := _minigame
	close()
	if is_instance_valid(game):
		game.finish({"won": false, "quit": true})


func _quit_to_title() -> void:
	Game.save_now()
	Game.autosave = false
	close()
	get_tree().paused = false
	SceneManager.change_scene(TITLE_SCENE)


func _input(event: InputEvent) -> void:
	if not is_open() or Sound.settings_open:
		return
	if event.is_action_pressed("back") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()
