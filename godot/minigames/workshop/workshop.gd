extends MiniGame
## 04 Workshop: the 50s Engineer's garage lab, a hand-drawn 2D point-and-click story.
##
## Click things to poke them; click an inventory item to hold it, then click where to use
## it (right-click or Escape puts it back). On a controller the left stick (or D-pad) moves
## the cursor, A (Cross) clicks and B (Circle) puts a held item back, otherwise leaves
## (pad_pointer.gd). The story lives in story.gd and lines.gd; the room is built by
## world.gd; everything is drawn from code (ink.gd).

const World := preload("res://minigames/workshop/world.gd")
const Cat := preload("res://minigames/workshop/cat.gd")
const Story := preload("res://minigames/workshop/story.gd")
const Bubble := preload("res://minigames/workshop/bubble.gd")
const Overlays := preload("res://minigames/workshop/overlays.gd")
const RadioView := preload("res://minigames/workshop/radio_view.gd")
const PadPointer := preload("res://minigames/workshop/pad_pointer.gd")
const GlyphWarmup := preload("res://ui/glyph_warmup.gd")
const STAGE_SIZE := Vector2(1600, 900)

var _stage: Node2D
var _world: Node2D
var _story: Node
var _bubble: Node2D
var _inventory: Node2D
var _cursor: Node2D
var _hovered: Node2D
var _held := ""
var _pad: Node  ## PadPointer: the controller's cursor, used while it is active.


func _ready() -> void:
	use_touch_controls = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hide_system_cursor()
	var bg := ColorRect.new()
	bg.color = Color("1d1410")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)
	_world = World.new()
	_stage.add_child(_world)
	var alarm := Overlays.Alarm.new()
	_stage.add_child(alarm)
	var deletion := Overlays.Deletion.new()
	_stage.add_child(deletion)
	_inventory = Overlays.Inventory.new()
	_stage.add_child(_inventory)
	var closeup := Overlays.Closeup.new()
	_stage.add_child(closeup)
	var radio_view := RadioView.new()
	_stage.add_child(radio_view)
	_bubble = Bubble.new()
	_stage.add_child(_bubble)
	# Speech text (bubble.gd) and the cursor label, so the first line doesn't hitch.
	GlyphWarmup.add_to(_stage, [[Style.font(), Bubble.FONT_SIZE], [Style.font(true), 15], [Style.font(true), 18]])
	_cursor = Overlays.Cursor.new()
	_cursor.follow = _stage_mouse
	_stage.add_child(_cursor)
	_pad = PadPointer.new()
	_pad.bounds = Rect2(Vector2.ZERO, STAGE_SIZE)
	_pad.mouse_position = func() -> Vector2: return _stage.get_local_mouse_position()
	add_child(_pad)
	_story = Story.new()
	_story.world = _world
	_story.bubble = _bubble
	_story.inventory = _inventory
	_story.closeup = closeup
	_story.alarm = alarm
	_story.deletion = deletion
	_story.radio_view = radio_view
	add_child(_story)
	_story.won.connect(func(): finish({"won": true}))
	resized.connect(_fit_stage)
	_fit_stage()
	super()
	_story.begin(resume_state)


func _fit_stage() -> void:
	var s := minf(size.x / STAGE_SIZE.x, size.y / STAGE_SIZE.y)
	_stage.scale = Vector2(s, s)
	_stage.position = (size - STAGE_SIZE * s) * 0.5


func save_state() -> Dictionary:
	if _story == null or _story.flags.phase in ["done", "epilogue"]:
		return {}
	return _story.save_state()


func _back_leaves() -> bool:
	return _story != null and _story.flags.phase == "done"


func _process(_delta: float) -> void:
	_update_hover()


## Where the player is pointing, in stage coordinates: the controller's cursor while it
## is in use, otherwise the mouse.
func _stage_mouse() -> Vector2:
	if _pad != null and _pad.active:
		return _pad.position
	return _stage.get_local_mouse_position()


func _update_hover() -> void:
	var found: Node2D = null
	if _story.radio_open():
		# The radio close-up has its own parts.
		if _hovered and is_instance_valid(_hovered):
			_hovered.hovered = false
		_hovered = null
		_cursor.label = _story.radio_view.hover_label(_stage_mouse())
		_cursor.held = ""
		return
	if not _story.busy and not _bubble.is_open():
		var p := _stage.to_global(_stage_mouse())
		for t in _world.hotspots():
			if t.hit_test(p):
				# The bare floor only matters while holding something.
				if t.id == "floor" and _held == "":
					continue
				found = t
				break
	if found != _hovered:
		if _hovered and is_instance_valid(_hovered):
			_hovered.hovered = false
		_hovered = found
		if _hovered:
			_hovered.hovered = _hovered.id != "floor"
	var label := ""
	if _hovered:
		label = "the floor" if _hovered.id == "floor" else _hovered.hover_name
	var inv_item: String = _inventory.item_at(_stage_mouse())
	if inv_item != "" and _held == "":
		label = Overlays.Items.NAMES.get(inv_item, inv_item)
	_cursor.label = label
	_cursor.held = _held


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_drop_held()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		_press()


## A click at the pointer, from the mouse or the controller's A button.
func _press() -> void:
	_cursor.poke()
	_update_hover()  # The pad may have moved the pointer since the last frame.
	if _bubble.advance():
		return
	if _story.busy:
		return
	if _story.radio_open():
		_story.radio_click(_stage_mouse())
		return
	var item: String = _inventory.item_at(_stage_mouse())
	if item != "":
		_held = "" if _held == item else item
		_inventory.selected = _held
		return
	if _hovered == null:
		_drop_held()
		return
	var held := _held
	_drop_held()
	_story.click(_hovered.id, held, _stage_mouse())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A \
			and not Sound.settings_open:
		get_viewport().set_input_as_handled()
		_pad.activate()
		_press()
		return
	if event.is_action_pressed("back") and _story.radio_open():
		get_viewport().set_input_as_handled()
		_story.radio_view.close()
		return
	if event.is_action_pressed("back") and _held != "":
		get_viewport().set_input_as_handled()
		_drop_held()
		return
	super(event)


## The drawn hand is the Workshop's cursor, so the system arrow is hidden over the scene:
## the scene uses a cursor shape no other screen does, swapped for a blank image while the
## Workshop is open. Buttons and menus keep the ordinary arrow.
func _hide_system_cursor() -> void:
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	var blank := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	blank.fill(Color(0, 0, 0, 0))
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(blank), Input.CURSOR_CROSS)


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)


func _drop_held() -> void:
	_held = ""
	_inventory.selected = ""


## Dev hook for tools/workshop_shot.gd.
func debug_step(step: String) -> void:
	match step:
		"poses":
			var x := 120.0
			for p in ["sit", "stand", "walk", "jump", "crouch", "eat", "sleep"]:
				var c := Cat.new()
				c.pose = p
				c.position = Vector2(x, 840)
				c.yarn = p == "sit"
				c.lid = p in ["sit", "stand"]
				c.displaced = p == "stand"
				_world.add_child(c)
				x += 210.0
		"epilogue":
			Game.completed_minigames["workshop"] = {"won": true}
			_story.epilogue.begin()
		"wrongdial":
			_story.flags.dial = (int(_story.flags.dial) + 1) % 720
			_world.things.machine.dial = _story.flags.dial
		"skip":
			_bubble.advance()
			_bubble.advance()
		_:
			if step.begins_with("click:"):
				var parts := step.substr(6).split("@")
				_story.click(parts[0], parts[1] if parts.size() > 1 else "", Vector2(700, 740))
			elif step.begins_with("phase:"):
				var state := {"phase": step.substr(6), "tube": "tv", "tuned": true}
				_story.load_state(state)
				_story.apply_flags()
