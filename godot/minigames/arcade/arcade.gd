extends MiniGame
## The secret room's arcade cabinet: CHRONO RAIDER, a 1985 horizontal shooter smuggled
## back across the 1963 line. The game (shooter.gd) renders at 384 x 216 into a
## SubViewport, shown scaled with crisp pixels through a light CRT shader.
## Nothing is won here: leaving always reports {"won": false}, so no progress depends on it.

const Shooter := preload("res://minigames/arcade/shooter.gd")
const CRT := preload("res://minigames/arcade/arcade_crt.gdshader")

var shooter: Node2D
var _viewport: SubViewport
var _screen: TextureRect


func _ready() -> void:
	use_touch_controls = false
	var bg := ColorRect.new()
	bg.color = Color("050308")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_viewport = SubViewport.new()
	_viewport.size = Shooter.SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)
	shooter = Shooter.new()
	shooter.sound.connect(_play_sound)
	_viewport.add_child(shooter)
	_screen = TextureRect.new()
	_screen.texture = _viewport.get_texture()
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	# A bezel around the picture, clear of the leave button in the corner.
	_screen.offset_left = 48
	_screen.offset_right = -48
	_screen.offset_top = 70
	_screen.offset_bottom = -24
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = CRT
	_screen.material = mat
	add_child(_screen)
	super()


func _play_sound(cue: String) -> void:
	Sound.play(cue, self)


## The pause menu disables this node; stop drawing the screen too.
func _notification(what: int) -> void:
	if _viewport == null:
		return
	if what == NOTIFICATION_DISABLED:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	elif what == NOTIFICATION_ENABLED:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
