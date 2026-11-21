extends Node3D
## Physical card with a cached face texture and a raycast target.

signal pressed

const CardFace := preload("res://minigames/cards/card_face.gd")
const UI := preload("res://minigames/cards/card_ui.gd")
const CARD_SIZE := Vector2(0.95, 1.28)
const FACE_SIZE := Vector2i(384, 512)

var disabled := false
var card_data: Dictionary = {}
var is_empty := true
var collider: StaticBody3D
var _selected := false
var _available := true
var _hovered := false
var _empty_text := "Empty lane"
var _side := "player"
var _viewport: SubViewport
var _face: Control
var _body: MeshInstance3D
var _edge_material: StandardMaterial3D
var _face_material: StandardMaterial3D
var _pulse_tween: Tween
var _pulse_color := Color.BLACK
var _built := false
## "Choose me next": a quiet pulsing frame (and, on targets, a small marker) round a card
## or lane the player can pick for the current step. Set by the table each render. The
## one the pointer or controller is on gets a bold white frame and a full-size marker, so
## "what I'm on" always stands out from "what I could pick".
enum Cue { NONE, TARGET, HOSTILE, PLAYABLE }
const CUE_COLORS := {Cue.TARGET: Color("ffd36b"), Cue.HOSTILE: Color("ff5a3c"), Cue.PLAYABLE: Color("7fe0cf")}
var cue := Cue.NONE
var _cue_frame: Node3D
var _cue_material: StandardMaterial3D
var _cue_marker: Label3D
var _cue_t := 0.0


func _ready() -> void:
	_build()
	_refresh_face()
	_refresh_edge()


func _build() -> void:
	if _built:
		return
	_built = true
	_viewport = SubViewport.new()
	_viewport.size = FACE_SIZE
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_viewport.gui_disable_input = true
	add_child(_viewport)
	_face = CardFace.new()
	_face.size = Vector2(FACE_SIZE)
	_viewport.add_child(_face)
	_edge_material = StandardMaterial3D.new()
	_edge_material.albedo_color = Color("b8ad91")
	_edge_material.roughness = 0.8
	_edge_material.emission_enabled = true
	var body := MeshInstance3D.new()
	_body = body
	var box := BoxMesh.new()
	box.size = Vector3(CARD_SIZE.x + 0.025, 0.025, CARD_SIZE.y + 0.025)
	body.mesh = box
	body.material_override = _edge_material
	add_child(body)
	var top := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = CARD_SIZE
	top.mesh = plane
	top.rotation.x = -PI / 2.0
	top.position.y = 0.014
	_face_material = StandardMaterial3D.new()
	_face_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_face_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_face_material.albedo_texture = _viewport.get_texture()
	_face_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	top.material_override = _face_material
	add_child(top)
	collider = StaticBody3D.new()
	collider.collision_layer = 1
	collider.collision_mask = 0
	collider.set_meta("card_actor", self)
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(CARD_SIZE.x, 0.08, CARD_SIZE.y)
	shape.shape = bounds
	collider.add_child(shape)
	add_child(collider)


func configure(card: Dictionary, _compact: bool = false) -> void:
	if not is_empty and card_data == card:
		return
	card_data = card.duplicate(true)
	is_empty = card.is_empty()
	_refresh_face()
	_refresh_edge()


func set_empty(value: String, side: String = "player") -> void:
	if is_empty and _empty_text == value and _side == side:
		return
	is_empty = true
	card_data = {}
	_empty_text = value
	_side = side
	_refresh_face()
	_refresh_edge()


func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	_refresh_edge()


func set_cue(kind: Cue) -> void:
	if cue == kind:
		return
	cue = kind
	_cue_t = 0.0
	_refresh_cue()


## Frame and marker for the current cue and hover: none, quiet (an option), or bold (the
## one being pointed at).
func _refresh_cue() -> void:
	var show := cue != Cue.NONE or (_hovered and not disabled)
	if show and _cue_frame == null:
		_build_cue()
	if _cue_frame == null:
		return
	_cue_frame.visible = show
	var target := cue == Cue.TARGET or cue == Cue.HOSTILE
	_cue_marker.visible = target
	var tint: Color = CUE_COLORS.get(cue, Color.WHITE)
	if _hovered:
		_cue_material.albedo_color = Color(1, 1, 1, 1)
		_cue_frame.scale = Vector3(1.05, 1, 1.05)
		_cue_marker.modulate = Color(tint, 1.0)
		_cue_marker.pixel_size = 0.0034
	else:
		_cue_material.albedo_color = Color(tint, 0.25)
		_cue_frame.scale = Vector3.ONE
		_cue_marker.modulate = Color(tint, 0.55)
		_cue_marker.pixel_size = 0.0022


func _process(delta: float) -> void:
	if _cue_frame == null or not _cue_frame.visible:
		return
	_cue_t += delta
	var wave := 0.5 + 0.5 * sin(_cue_t * 3.0)
	if _hovered:
		_cue_marker.position.y = 0.46 + 0.05 * wave  # The one you're on: solid, marker bobbing.
		return
	var soft := cue == Cue.PLAYABLE
	_cue_material.albedo_color.a = (0.08 + 0.14 * wave) if soft else (0.16 + 0.22 * wave)
	_cue_marker.position.y = 0.4


func _build_cue() -> void:
	_cue_frame = Node3D.new()
	_cue_frame.name = "Cue"
	add_child(_cue_frame)
	_cue_material = StandardMaterial3D.new()
	_cue_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cue_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var w := CARD_SIZE.x + 0.12
	var h := CARD_SIZE.y + 0.12
	var bar := 0.06
	for spec in [[Vector3(0, 0, -h * .5), Vector3(w, .01, bar)], [Vector3(0, 0, h * .5), Vector3(w, .01, bar)],
			[Vector3(-w * .5, 0, 0), Vector3(bar, .01, h)], [Vector3(w * .5, 0, 0), Vector3(bar, .01, h)]]:
		var piece := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = spec[1]
		piece.mesh = mesh
		piece.position = spec[0] + Vector3(0, .02, 0)
		piece.material_override = _cue_material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cue_frame.add_child(piece)
	_cue_marker = Label3D.new()
	_cue_marker.text = "▼"
	_cue_marker.font_size = 96
	_cue_marker.pixel_size = 0.0028
	_cue_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cue_marker.no_depth_test = true
	_cue_marker.outline_size = 10
	_cue_marker.outline_modulate = Color(0, 0, 0, .6)
	_cue_marker.position = Vector3(0, 0.42, 0)
	_cue_frame.add_child(_cue_marker)


func set_available(value: bool) -> void:
	if _available == value:
		return
	_available = value
	_refresh_edge()


func set_hovered(value: bool) -> void:
	if _hovered == value:
		return
	_hovered = value
	_refresh_edge()
	_refresh_cue()


func pulse(color: Color) -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_color = color
	_refresh_edge()
	_pulse_tween = create_tween()
	_pulse_tween.tween_method(func(weight: float):
		_pulse_color = color * weight
		_refresh_edge(), 1.0, 0.0, 0.35)


func _refresh_face() -> void:
	if not _built:
		return
	_face.configure(card_data, _empty_text, _side)
	_body.visible = not is_empty
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _refresh_edge() -> void:
	if not _built:
		return
	if _face.set_highlight(_selected or _hovered):
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var base := Color("b8ad91") if not is_empty else Color("34575c")
	var glow := Color.BLACK
	if _selected or _hovered:
		base = UI.GOLD if _selected else Color("9cdbd0")
		glow = base * (0.75 if _selected else 0.35)
	_edge_material.albedo_color = base
	_edge_material.emission = glow + _pulse_color
	_face_material.albedo_color = Color.WHITE if _available else Color(0.65, 0.65, 0.65)
