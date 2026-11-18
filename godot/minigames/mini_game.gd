class_name MiniGame
extends Control
## Base class for all mini-games. Each mini-game is its own scene under
## res://minigames/<id>/ and loads whatever it needs itself.
##
## Call finish({"won": true, ...}) when done. Pressing "back" opens the pause menu,
## which can leave the game; override _back_leaves() for states where back should
## leave directly (a solved puzzle, a finished match).
## Set `use_touch_controls = false` for games that use tap/drag UI instead.
## To resume where the player left off, return progress from save_state() and read it
## back from resume_state in _ready(). Progress is kept until the game is won.

const Style := preload("res://ui/game_style.gd")

signal finished(result: Dictionary)

var use_touch_controls := true
var resume_state: Dictionary = {}  # Set by MiniGames before _ready() when there is saved progress.
var _done := false


func _enter_tree() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	theme = Style.theme()
	TouchControls.set_enabled(use_touch_controls)
	# Always-available exit, even when the touch pad is hidden.
	var close := Button.new()
	close.text = "×"
	close.tooltip_text = "Leave · Esc (keyboard) / B (controller or touch) opens the menu"
	close.add_theme_font_size_override("font_size", 24)
	close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -68
	close.offset_top = 18
	close.offset_bottom = 56
	close.offset_right = -24
	close.pressed.connect(func(): finish({"won": false, "quit": true}))
	add_child(close)


func _unhandled_input(event: InputEvent) -> void:
	if Sound.settings_open:
		return
	if not event.is_action_pressed("back") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	# A camera move into the minigame keeps its original cancel-by-back behavior.
	if _back_leaves() or MiniGames.transition != null:
		finish({"won": false, "quit": true})
	else:
		PauseMenu.open_minigame(self, MiniGames.current_title() if MiniGames.current == self else name)


## True when back should leave directly instead of opening the pause menu.
func _back_leaves() -> bool:
	return false


## Progress to restore on the next visit, or {} to start fresh. Values must be plain
## data (numbers, strings, vectors, arrays, dictionaries) so they fit in the save file.
func save_state() -> Dictionary:
	return {}


func finish(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	TouchControls.set_enabled(true)
	finished.emit(result)


## Helper: simple centered title label.
func make_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Style.font(true))
	l.add_theme_font_size_override("font_size", 36)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = 16
	add_child(l)
	return l
