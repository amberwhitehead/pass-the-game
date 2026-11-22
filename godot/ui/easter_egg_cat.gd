extends CanvasLayer
## Secret title-screen easter egg: Fuse the cat, dancing under the stars.
## Click the dim star on the title background to open it; Escape or a click closes it.

const Cat := preload("res://minigames/workshop/cat.gd")
const Style := preload("res://ui/game_style.gd")

var _cat: Node2D
var _t := 0.0
var _base_scale := 3.2
var _closed := false


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/story_bg.gdshader")
	material.set_shader_parameter("top_color", Color(0.02, 0.01, 0.08))
	material.set_shader_parameter("bottom_color", Color(0.16, 0.06, 0.22))
	material.set_shader_parameter("stars", 1.0)
	bg.material = material
	add_child(bg)
	bg.gui_input.connect(_on_input)

	var title := Style.label("A secret cat", 44, Style.PAPER, true)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.offset_top = 34
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var hint := Style.label("click or press Escape to go back", 18, Style.PAPER.darkened(0.3))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.offset_top = -70
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	_cat = Cat.new()
	_cat.pose = "stand"
	_cat.tail_mood = 4.0
	_cat.scale = Vector2(_base_scale, _base_scale)
	add_child(_cat)
	_cat.position = get_viewport().get_visible_rect().size * Vector2(0.5, 0.62)


func _process(delta: float) -> void:
	_t += delta
	if _cat == null:
		return
	var size := get_viewport().get_visible_rect().size
	var bounce := absf(sin(_t * 5.0))
	_cat.position = Vector2(size.x * 0.5 + sin(_t * 2.5) * 60.0, size.y * 0.62 - bounce * 46.0)
	_cat.rotation = sin(_t * 5.0) * 0.18
	_cat.tail_mood = 4.0
	# cycle a few poses so it reads as dancing
	var poses := ["stand", "crouch", "jump", "stand"]
	var idx := int(_t * 3.0) % poses.size()
	if _cat.pose != poses[idx]:
		_cat.pose = poses[idx]


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if _closed:
		return
	_closed = true
	queue_free()