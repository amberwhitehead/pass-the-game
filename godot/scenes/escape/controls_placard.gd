extends Node3D
## A brass-edged placard on a stand, in front of where the player first comes into the
## hall, listing the controls: keyboard and mouse on the left, the controller on the right.
## Keyboard keys come from KeyBindings, so a key changed in Controls shows up here after
## the pause menu closes. The front faces local +Z; the floor is y = 0.

const Geometry := preload("res://scenes/escape/hub_geometry.gd")
const Sign := preload("res://ui/world_sign.gd")
const KeyBindings := preload("res://autoload/key_bindings.gd")
const PadLabels := preload("res://autoload/pad_labels.gd")

const BOARD_AT := Vector3(0, 1.3, .06)
const BOARD_SIZE := Vector2(.95, .62)

const LINE_H := .05
const ROWS := 7
## Per section, one [action, button] pair of labels per line: the action pinned left, the
## button pinned right, so the buttons line up down the section's right edge.
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


static func _fill(rows: Array, lines: Array) -> void:
	for i in rows.size():
		var pair: Array = lines[i] if i < lines.size() else ["", ""]
		rows[i][0].text = pair[0]
		rows[i][1].text = pair[1]


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


static func controller_lines() -> Array:
	return [
		["Look", "Right stick"],
		["Move", "Left stick"],
		["Jump", "L1"],
		["Use", "R1 or %s" % PadLabels.face(JOY_BUTTON_A)],
		["Take", "R2"],
		["Menu", PadLabels.face(JOY_BUTTON_Y)],
		["Back", PadLabels.face(JOY_BUTTON_B)],
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
			rows.append([action, button])
