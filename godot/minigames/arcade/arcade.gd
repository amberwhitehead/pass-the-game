extends MiniGame
## The secret room's arcade cabinet: CHRONO RAIDER, a 1985 horizontal shooter smuggled
## back across the 1963 line. The game (shooter.gd) renders at 384 x 216 into a
## SubViewport, shown scaled with crisp pixels through a light CRT shader.
## Nothing is won here: leaving always reports {"won": false}, so no progress depends on it.

const Shooter := preload("res://minigames/arcade/shooter.gd")
const CRT := preload("res://minigames/arcade/arcade_crt.gdshader")
const MusicPlayer := preload("res://audio/music/music_player.gd")
const Songs := preload("res://minigames/arcade/songs.gd")
const Stage := preload("res://minigames/arcade/stage.gd")

var shooter: Node2D
var music: Node
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
	music = MusicPlayer.new()
	music.songs = Songs.all()
	add_child(music)
	super()


func _process(_delta: float) -> void:
	var id := song_for(shooter)
	if id != "":
		music.play(id, 0.15 if id in ["clear", "over"] else 0.8)


## Which song suits the shooter's state: the title tune, the stage, the boss (from its
## warning on), then the stage-clear or game-over jingle, which plays once.
static func song_for(s) -> String:
	match s.mode:
		"title":
			return "title"
		"play":
			return "boss" if s.stage_frame >= Stage.BOSS_AT else "stage"
		"clear":
			return "clear"
		"over":
			return "over"
	return ""


func _play_sound(cue: String) -> void:
	Sound.play(cue, self)


## The pause menu disables this node; stop drawing the screen and pause the music too.
func _notification(what: int) -> void:
	if _viewport == null or music == null:
		return
	if what == NOTIFICATION_DISABLED:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		music.paused = true
	elif what == NOTIFICATION_ENABLED:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		music.paused = false
