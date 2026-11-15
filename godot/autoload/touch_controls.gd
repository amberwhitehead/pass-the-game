extends CanvasLayer
## Always-on-top on-screen controls for mobile web.
##
## Layout (computed from the *actual* viewport, re-laid-out on resize/rotate):
##   - lower third of the screen
##   - left quarter  : D-pad  (move_up/down/left/right)
##   - right quarter : A (interact) and B (back)
## Pads are square and hug the bottom corners, in portrait and landscape.
##
## Buttons press/release the same InputMap actions as the keyboard, and each
## tracks its own finger, so multi-touch works (move + act at once).
## Show/hide from anywhere:  TouchControls.set_enabled(false)

const TouchButton := preload("res://scenes/ui/touch_button.gd")
const MARGIN := 12.0
const GAP := 6.0
const ACTIONS := ["move_up", "move_down", "move_left", "move_right", "interact", "back"]

var _root: Control
var _btn: Dictionary = {}   # action -> TouchButton
var _enabled := true   # scene-level switch (story/mini-games hide the pad)
var _awake := true     # fades out while keyboard/gamepad is in use, back on touch
var _fade: Tween


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep working while a mini-game pauses the tree
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var glyphs := {"move_up": "▲", "move_down": "▼", "move_left": "◀", "move_right": "▶",
		"interact": "A", "back": "B"}
	for action: String in ACTIONS:
		var b := TouchButton.new()
		b.action = action
		b.text = glyphs[action]
		_root.add_child(b)
		_btn[action] = b

	get_viewport().size_changed.connect(_layout)
	_layout()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_apply(false)


## True if a screen position is over a visible on-screen button.
func is_over_button(pos: Vector2) -> bool:
	if not _root.visible:
		return false
	for b: Control in _btn.values():
		if b.get_global_rect().grow(8.0).has_point(pos):
			return true
	return false


## Fade the pad out when another device is used; bring it back on touch.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not _awake:
			_awake = true
			_apply(true)
	elif (event is InputEventKey and event.pressed and not event.echo) \
			or event is InputEventJoypadButton \
			or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		if _awake:
			_awake = false
			_apply(true)


func _apply(animate: bool) -> void:
	var show := _enabled and _awake
	if _fade:
		_fade.kill()
	if show:
		_root.visible = true
		if animate:
			_fade = create_tween()
			_fade.tween_property(_root, "modulate:a", 1.0, 0.2)
		else:
			_root.modulate.a = 1.0
		return
	# Hiding: release anything held so no action sticks.
	for b: Control in _btn.values():
		b._fingers.clear()
		b._set_pressed(false)
	if animate and _enabled:
		_fade = create_tween()
		_fade.tween_property(_root, "modulate:a", 0.0, 0.6)
		_fade.tween_callback(func(): _root.visible = false)
	else:
		_root.modulate.a = 0.0
		_root.visible = false


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	# Pad = square that fits in a quarter-width x third-height zone.
	var pad := minf(vp.x * 0.25 - MARGIN, vp.y / 3.0 - MARGIN)
	pad = maxf(pad, 120.0)
	var top := vp.y - MARGIN - pad

	# Left: D-pad, 3x3 cells.
	var cell := (pad - 2.0 * GAP) / 3.0
	var lx := MARGIN
	_place("move_up", lx + cell + GAP, top, cell, cell)
	_place("move_left", lx, top + cell + GAP, cell, cell)
	_place("move_right", lx + 2.0 * (cell + GAP), top + cell + GAP, cell, cell)
	_place("move_down", lx + cell + GAP, top + 2.0 * (cell + GAP), cell, cell)

	# Right: A (big, lower right) and B (smaller, upper left of it).
	var rx := vp.x - MARGIN - pad
	_place("interact", rx + pad * 0.40, top + pad * 0.30, pad * 0.60, pad * 0.70)
	_place("back", rx, top, pad * 0.45, pad * 0.55)


func _place(action: String, x: float, y: float, w: float, h: float) -> void:
	var b: Control = _btn[action]
	b.custom_minimum_size = Vector2.ZERO
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	b.queue_redraw()
