extends Control
## Opening story: 2D UI over a shader background + simple drawn graphics.
## Tap / click / A / E / Enter to advance. Edit PAGES to change the story.
##   art:     "woosh" (time-travel streaks) or "officer"
##   speaker: name shown above the text ("" for none)
##   text:    "" + auto=<seconds> makes a text-less beat that advances itself

const Style := preload("res://ui/game_style.gd")
const ROOM_SCENE := "res://scenes/room/room.tscn"
const COLONEL_MODEL := preload("res://assets/characters/officer_colonel.glb")

const PAGES := [
	{"art": "woosh", "speaker": "", "text": "", "auto": 3.2},
	{"art": "officer", "speaker": "Officer", "text": "Another time traveler… 21st century? Glued to your screen, just like they said."},
	{"art": "officer", "speaker": "Officer", "text": "Congratulations on figuring out the time machine. Not many from your century do. It's a second dark age, many say."},
	{"art": "officer", "speaker": "Officer", "text": "But there are some things you should know. First, you don't cross 1963. That's why you were intercepted and brought here."},
	{"art": "officer", "speaker": "Officer", "text": "Second, you're not the first. The United States government figured out time travel in 1945. Lots of others figured it out before, and since. The Romans. The Mayans. It's crowded here."},
	{"art": "officer", "speaker": "Officer", "text": "And none of them like an uninitiated tenderfoot crossing either way over 1963. So go pass all their little tests if you want out of this time travelers' purgatory I just captured you into…"},
]

# Background palettes per art type.
const PALETTES := {
	"woosh": {"top": Color(0.01, 0.02, 0.1), "bottom": Color(0.05, 0.15, 0.3), "stars": 1.0},
	"officer": {"top": Color(0.08, 0.09, 0.07), "bottom": Color(0.3, 0.27, 0.18), "stars": 0.25},
}

var _page := -1
var _woosh: Control
var _officer: OfficerArt
var _bg_mat: ShaderMaterial
var _panel: PanelContainer
var _speaker: Label
var _label: RichTextLabel
var _tween: Tween
var _fx_tween: Tween
var _starting := false


func _ready() -> void:
	theme = Style.theme()
	TouchControls.set_enabled(false)  # story is tap-to-advance
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE  # let taps reach _unhandled_input

	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = load("res://shaders/story_bg.gdshader")
	bg.material = _bg_mat
	_bg_mat.set_shader_parameter("top_color", PALETTES.woosh.top)  # params must exist to be tweened
	_bg_mat.set_shader_parameter("bottom_color", PALETTES.woosh.bottom)
	_bg_mat.set_shader_parameter("stars", PALETTES.woosh.stars)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	_woosh = WooshArt.new()
	_officer = OfficerArt.new()
	_officer.modulate.a = 0.0
	for a: Control in [_woosh, _officer]:
		a.set_anchors_preset(PRESET_FULL_RECT)
		a.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(a)

	_panel = preload("res://ui/conversation_sheet.gd").new()
	_panel.anchor_left = .08
	_panel.anchor_right = .92
	_panel.anchor_top = .65
	_panel.anchor_bottom = .65
	add_child(_panel)
	_speaker = _panel.speaker
	_label = _panel.copy

	var skip := Button.new()
	skip.text = "Skip intro  ›"
	skip.add_theme_font_size_override("font_size", 15)
	skip.set_anchors_preset(PRESET_TOP_RIGHT)
	skip.offset_left = -150
	skip.offset_top = 18
	skip.offset_bottom = 56
	skip.offset_right = -24
	skip.pressed.connect(_start_game)
	add_child(skip)

	_next_page()


func _next_page() -> void:
	_page += 1
	if _page >= PAGES.size():
		_start_game()
		return
	var p: Dictionary = PAGES[_page]
	_set_art(p.art)

	var has_text: bool = p.text != ""
	_panel.visible = has_text
	if has_text:
		_panel.arrive()
	_speaker.text = p.speaker
	_speaker.visible = p.speaker != ""
	_label.text = p.text
	_label.visible_ratio = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if has_text:
		_tween.tween_property(_label, "visible_ratio", 1.0, 0.02 * p.text.length())
	else:
		var this_page := _page
		_tween.tween_interval(p.auto)
		_tween.tween_callback(func(): if _page == this_page: _next_page())


func _set_art(art: String) -> void:
	var pal: Dictionary = PALETTES[art]
	if _fx_tween:
		_fx_tween.kill()
	_fx_tween = create_tween().set_parallel(true)
	_fx_tween.tween_property(_bg_mat, "shader_parameter/top_color", pal.top, 0.8)
	_fx_tween.tween_property(_bg_mat, "shader_parameter/bottom_color", pal.bottom, 0.8)
	_fx_tween.tween_property(_bg_mat, "shader_parameter/stars", pal.stars, 0.8)
	# Officer fades in over a dimmed time-warp; woosh page is the warp alone.
	_fx_tween.tween_property(_officer, "modulate:a", 1.0 if art == "officer" else 0.0, 0.7)
	_fx_tween.tween_property(_woosh, "modulate:a", 0.3 if art == "officer" else 1.0, 0.7)


func _process(_delta: float) -> void:
	# the Colonel's mouth moves while his line is still being typed out
	_officer.talking = _panel.visible and _label.visible_ratio < 1.0


func _advance() -> void:
	if _panel.visible and _label.visible_ratio < 1.0:
		_tween.kill()
		_label.visible_ratio = 1.0
		return
	_next_page()


func _start_game() -> void:
	if _starting:
		return
	_starting = true
	TouchControls.set_enabled(true)
	SceneManager.change_scene(ROOM_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if Sound.settings_open:
		return
	if event.is_action_pressed("interact") \
			or (event is InputEventMouseButton and event.pressed):
		_advance()


## Procedural art so the intro works with zero imported assets.
## Swap for TextureRects/AnimatedSprites when real graphics exist.

## Time-travel warp: streaks rushing out of the centre plus expanding rings.
class WooshArt extends Control:
	const STREAKS := 90
	var _t := 0.0
	var _angle: Array[float] = []
	var _speed: Array[float] = []
	var _offset: Array[float] = []
	var _hue: Array[int] = []

	func _init() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1963
		for i in STREAKS:
			_angle.append(rng.randf() * TAU)
			_speed.append(rng.randf_range(0.5, 1.4))
			_offset.append(rng.randf())
			_hue.append(rng.randi() % 3)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var max_r := size.length() * 0.6
		var cols := [Color(0.3, 0.9, 1.0), Color(0.9, 0.35, 1.0), Color(1, 1, 1)]
		for i in STREAKS:
			var p := fposmod(_t * _speed[i] * 0.7 + _offset[i], 1.0)
			var dir := Vector2.from_angle(_angle[i])
			var r0 := p * p * max_r
			var r1 := r0 + 12.0 + p * max_r * 0.35
			var col: Color = cols[_hue[i]]
			col.a = sin(p * PI) * 0.9
			draw_line(c + dir * r0, c + dir * r1, col, 1.5 + p * 4.0, true)
		for k in 3:
			var rp := fposmod(_t * 0.45 + k / 3.0, 1.0)
			draw_arc(c, rp * max_r, 0.0, TAU, 96, Color(0.5, 0.9, 1.0, (1.0 - rp) * 0.6), 2.0 + rp * 6.0, true)
		draw_circle(c, 30.0 + sin(_t * 8.0) * 6.0, Color(0.8, 0.95, 1.0, 0.25))
		draw_circle(c, 12.0, Color(1, 1, 1, 0.6))


## The Colonel: the rigged 3D character rendered into the story screen (transparent background, so
## the story colours show through). Idles and blinks on its own; `talking` runs the mouth animation.
## Same rig convention as the room NPCs: body "idle", face-only "blink" and "talk" animations.
class OfficerArt extends Control:
	var talking := false:
		set(value):
			if value == talking:
				return
			talking = value
			_set_talking(value)

	var _body_anim: AnimationPlayer
	var _face_anim: AnimationPlayer
	var _meshes: Array[MeshInstance3D] = []
	var _blink_in := 2.5

	func _ready() -> void:
		var container := SubViewportContainer.new()
		container.stretch = true
		container.set_anchors_preset(PRESET_FULL_RECT)
		container.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(container)
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.handle_input_locally = false
		container.add_child(vp)

		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-30, 35, 0)
		key.light_energy = 1.1
		vp.add_child(key)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-10, -140, 0)
		fill.light_energy = 0.5
		fill.light_color = Color(0.7, 0.8, 1.0)
		vp.add_child(fill)
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.55, 0.55, 0.6)
		env.ambient_light_energy = 0.6
		var we := WorldEnvironment.new()
		we.environment = env
		vp.add_child(we)

		# Head and shoulders in the upper part of the screen (the text panel covers the lower 40%).
		var cam := Camera3D.new()
		cam.fov = 30.0
		cam.position = Vector3(0.0, 1.2, 3.2)
		vp.add_child(cam)

		var model: Node3D = COLONEL_MODEL.instantiate()
		vp.add_child(model)
		for m in model.find_children("*", "MeshInstance3D", true, false):
			_meshes.append(m)
		_body_anim = model.find_child("AnimationPlayer", true, false)
		if _body_anim:
			# second player over the same library so a face animation can layer over the body one
			_face_anim = AnimationPlayer.new()
			_body_anim.get_parent().add_child(_face_anim)
			_face_anim.root_node = _body_anim.root_node
			for lib in _body_anim.get_animation_library_list():
				_face_anim.add_animation_library(lib, _body_anim.get_animation_library(lib))
			if _body_anim.has_animation("idle"):
				_body_anim.play("idle")

	func _process(delta: float) -> void:
		_blink_in -= delta
		if _blink_in <= 0.0:
			_blink_in = randf_range(2.0, 6.0)
			if not talking and _face_anim and _face_anim.has_animation("blink"):
				_face_anim.play("blink")

	func _set_talking(value: bool) -> void:
		if _face_anim == null:
			return
		if value and _face_anim.has_animation("talk"):
			_face_anim.play("talk")
		else:
			_face_anim.stop()
			for m in _meshes:   # stop() leaves blend shapes where they were
				for i in m.get_blend_shape_count():
					m.set_blend_shape_value(i, 0.0)
