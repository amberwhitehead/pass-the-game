extends "res://minigames/workshop/thing.gd"
## The Futurescope: a television that shows the Workshop's future.
##
## It owns a second copy of the room (`future`, a World) inside a SubViewport, and shows
## that picture through a CRT shader. Story code stages the future room; the same feed
## also drives the full-screen close-up (`feed_texture()`).

const P := preload("res://minigames/workshop/palette.gd")
const CRT := preload("res://minigames/workshop/crt.gdshader")
const BODY := Rect2(832, 272, 176, 146)
const SCREEN := Rect2(846, 288, 124, 94)
const FEED_SIZE := Vector2i(600, 450)
## The 4:3 slice of the room the camera sees (stage space).
const VIEW := Rect2(420, 0, 1200, 900)

var has_tube := false:
	set(v):
		has_tube = v
		_refresh()
var on := false:
	set(v):
		on = v
		_refresh()
var tuned := false:
	set(v):
		tuned = v
		_refresh()
var alarm := false:
	set(v):
		alarm = v
		_refresh()

var future: Node2D
var _viewport: SubViewport
var _screen: Sprite2D
var _mat: ShaderMaterial


func _init() -> void:
	id = "tv"
	hover_name = "Futurescope"
	hit_rect = BODY.grow(4)


func setup(future_world: Node2D) -> void:
	_viewport = SubViewport.new()
	_viewport.size = FEED_SIZE
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	future = future_world
	var s := float(FEED_SIZE.x) / VIEW.size.x
	future.scale = Vector2(s, s)
	future.position = -VIEW.position * s
	_viewport.add_child(future)
	_mat = ShaderMaterial.new()
	_mat.shader = CRT
	_screen = Sprite2D.new()
	_screen.texture = _viewport.get_texture()
	_screen.centered = false
	_screen.position = SCREEN.position
	_screen.scale = SCREEN.size / Vector2(FEED_SIZE)
	_screen.material = _mat
	add_child(_screen)
	_refresh()


func feed_texture() -> Texture2D:
	return _viewport.get_texture()


func material() -> ShaderMaterial:
	return _mat


func _refresh() -> void:
	queue_redraw()
	if _mat == null:
		return
	_screen.visible = on
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	_mat.set_shader_parameter("static_amount", 0.0 if tuned else 0.85)
	_mat.set_shader_parameter("alarm", 1.0 if alarm else 0.0)


func _paint() -> void:
	# Rabbit-ear antenna.
	Ink.line(self, PackedVector2Array([Vector2(920, 274), Vector2(880, 196)]), P.CHROME, 3.0, 300)
	Ink.line(self, PackedVector2Array([Vector2(920, 274), Vector2(972, 204)]), P.CHROME, 3.0, 301)
	Ink.dot(self, Vector2(880, 196), 4, P.CHROME, 2.0, 302)
	Ink.dot(self, Vector2(972, 204), 4, P.CHROME, 2.0, 303)
	Ink.shape(self, Ink.ellipse(Vector2(920, 276), Vector2(18, 8), 14), Color("2d2d2d"), 2.5, 304)
	# Cabinet.
	Ink.shape(self, Ink.rrect(BODY, 16), Color("8b5a36"), 3.5, 305, 0.2, 0.18)
	Ink.shape(self, Ink.rrect(SCREEN.grow(6), 14), Color("2a2622"), 3.0, 306, 0.0, 0.0)
	if not on:
		Ink.shape(self, Ink.rrect(SCREEN, 12), Color("37403e"), 2.0, 307, 0.12, 0.0)
	# Knobs and a speaker grille.
	Ink.dot(self, Vector2(988, 306), 9, P.CREAM, 2.5, 308)
	Ink.dot(self, Vector2(988, 334), 9, P.CREAM, 2.5, 309)
	for k in 4:
		Ink.line(self, PackedVector2Array([Vector2(980, 352 + k * 9), Vector2(998, 352 + k * 9)]), Color("5a3a26"), 2.0, 310 + k)
	Ink.dot(self, Vector2(988, 306) + Vector2(0, -6).rotated(0.8 if tuned else -0.8), 2, Ink.OUTLINE, 0.0, 314)
	# The empty tube socket on the back shows as a dark gap until repaired.
	if not has_tube:
		Ink.shape(self, Ink.rrect(Rect2(940, 262, 26, 12), 3), Color("2a2a2a"), 2.0, 315)
	# The brand plate.
	var plate := Rect2(860, 392, 96, 16)
	Ink.shape(self, Ink.rrect(plate, 4), P.BRASS, 2.0, 316, 0.2)
	draw_string(Style.font(true), Vector2(plate.position.x, plate.position.y + 12), "FUTURESCOPE", HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 9, Ink.OUTLINE)
	if on:
		Ink.dot(self, Vector2(1000, 400), 3, Color("ff6040"), 0.0, 317, 0.0, 0.0)
