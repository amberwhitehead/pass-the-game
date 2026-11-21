extends Node3D
## A brass-edged placard on a stand, in front of where the player first comes into the
## hall, listing the controls: keyboard and mouse on the left, the controller on the right.
## Keyboard keys come from KeyBindings, so a key changed in Controls shows up here after
## the pause menu closes. The front faces local +Z; the floor is y = 0.

const Geometry := preload("res://scenes/escape/hub_geometry.gd")
const Sign := preload("res://ui/world_sign.gd")
const KeyBindings := preload("res://autoload/key_bindings.gd")
const PadLabels := preload("res://autoload/pad_labels.gd")
const PadGlyph := preload("res://ui/pad_glyph.gd")

const BOARD_AT := Vector3(0, 1.3, .06)
const BOARD_SIZE := Vector2(.95, .62)

const LINE_H := .05
const GLYPH_PX := 48.0        ## Drawn button height, in pixels, before it goes on the board...
const GLYPH_H := .042         ## ...and its height on the board, in metres.
const ROWS := 7
## Per section, one row per line: [action label, button label, glyph slots]. The action is
## pinned left and the button right, so the buttons line up down the section's right edge.
## Controller buttons are drawn (ui/pad_glyph.gd) to look like the pad that is plugged in.
var keyboard: Array = []
var controller: Array = []


func _init() -> void:
	name = "ControlsPlacard"


func _ready() -> void:
	_build()
	refresh()
	PauseMenu.closed.connect(refresh)  # Keys may have been changed in Controls.
	Input.joy_connection_changed.connect(func(_d: int, _c: bool): refresh())


func refresh() -> void:
	_fill(keyboard, keyboard_lines())
	_fill(controller, controller_lines())


func _fill(rows: Array, lines: Array) -> void:
	var kind := PadLabels.kind()
	for i in rows.size():
		var pair: Array = lines[i] if i < lines.size() else ["", ""]
		var row: Array = rows[i]
		row[0].text = pair[0]
		var glyphs: Array = pair[1] if pair[1] is Array else []
		row[1].text = pair[1] if pair[1] is String else ""
		# Lay the drawn buttons right to left from the section's right edge.
		var right: float = row[1].position.x
		for k in row[2].size():
			var slot: Dictionary = row[2][k]
			var sprite: Sprite3D = slot.sprite
			sprite.visible = k < glyphs.size()
			if not sprite.visible:
				continue
			var glyph: Control = slot.glyph
			glyph.button = glyphs[glyphs.size() - 1 - k]
			glyph.kind = kind
			var px := PadGlyph.size_for(glyph.button, kind, GLYPH_PX)
			slot.viewport.size = Vector2i(px.ceil())
			glyph.size = px
			slot.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			var width := px.x * sprite.pixel_size
			sprite.position = Vector3(right - width * 0.5, row[1].position.y, row[1].position.z + .002)
			right -= width + .015


## [action, button] per line.
static func keyboard_lines() -> Array:
	var k := func(action: String) -> String: return KeyBindings.label(action)
	return [
		["Look", "Mouse"],
		["Move", "%s %s %s %s" % [k.call("move_up"), k.call("strafe_left"), k.call("move_down"), k.call("strafe_right")]],
		["Jump", k.call("jump")],
		["Use", "Click"],
		["Take", "Right-click"],
		["Menu", k.call("back")],
	]


## A list instead of a word means drawn buttons (ui/pad_glyph.gd names).
static func controller_lines() -> Array:
	return [
		["Look", "Right stick"],
		["Move", "Left stick"],
		["Jump", ["l1"]],
		["Use", ["r1", "a"]],
		["Take", ["r2", "x"]],
		["Menu", ["y"]],
		["Back", ["b"]],
	]


func _build() -> void:
	var body := Geometry.material(Color("16262b"), .3)
	var brass := Geometry.material(Color("b8955a"), .75)
	var face := Geometry.material(Color("0d1c1f"), 0.0, .25)
	Geometry.box(self, Vector3(0, .03, 0), Vector3(.5, .06, .36), body)
	Geometry.box(self, Vector3(-.3, .62, -.02), Vector3(.06, 1.12, .06), body, true)
	Geometry.box(self, Vector3(.3, .62, -.02), Vector3(.06, 1.12, .06), body, true)
	var board := Node3D.new()
	board.position = BOARD_AT
	board.rotation.x = -.18  # Leaning back a little toward someone standing in front.
	add_child(board)
	Geometry.box(board, Vector3(0, 0, -.03), Vector3(BOARD_SIZE.x + .06, BOARD_SIZE.y + .06, .05), brass)
	Geometry.box(board, Vector3(0, 0, 0), Vector3(BOARD_SIZE.x, BOARD_SIZE.y, .02), face)
	var top := BOARD_SIZE.y * .5
	var title := Label3D.new()
	Sign.style(title, .05, Sign.GOLD)
	title.text = "HOW TO PLAY"
	title.position = Vector3(0, top - .06, .012)
	board.add_child(title)
	for column in [-1.0, 1.0]:
		var heading := Label3D.new()
		Sign.style(heading, .026, Sign.MUTED)
		heading.text = "KEYBOARD  &  MOUSE" if column < 0 else "CONTROLLER"
		heading.position = Vector3(column * BOARD_SIZE.x * .25, top - .13, .012)
		board.add_child(heading)
		var center: float = column * BOARD_SIZE.x * .25
		var half := BOARD_SIZE.x * .2
		var rows: Array = keyboard if column < 0 else controller
		for i in ROWS:
			var y := top - .19 - i * LINE_H
			var action := Label3D.new()
			Sign.style(action, .03, Sign.PAPER)
			action.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			action.position = Vector3(center - half, y, .012)
			board.add_child(action)
			var button := Label3D.new()
			Sign.style(button, .03, Sign.GOLD)
			button.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			button.position = Vector3(center + half, y, .012)
			board.add_child(button)
			var slots: Array = []
			if column > 0:
				for k in 2:
					slots.append(_glyph_slot(board))
			rows.append([action, button, slots])


## A drawn controller button on the board: a small viewport holding a PadGlyph, shown on a
## Sprite3D. It is redrawn only when the button or the pad changes.
func _glyph_slot(board: Node3D) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.size = Vector2i(64, 48)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var glyph := PadGlyph.new()
	glyph.glyph_height = GLYPH_PX
	viewport.add_child(glyph)
	var sprite := Sprite3D.new()
	sprite.texture = viewport.get_texture()
	sprite.pixel_size = GLYPH_H / GLYPH_PX
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.visible = false
	board.add_child(sprite)
	return {"viewport": viewport, "glyph": glyph, "sprite": sprite}
