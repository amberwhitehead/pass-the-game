extends Interactable
## A standing console near the hall's entrance, about the player's height, that shows the
## current objective (objectives.gd) on its slanted screen. On top sits a small laser
## pointer: interacting turns it toward the next objective and blinks the beam three
## times at it. The front faces local +Z; the floor is y = 0.
##
## `locate` turns an objective place ("egypt", "prisms", ...) into a world position;
## room.gd supplies it. Unknown places leave the pointer where it is.

const Geometry := preload("res://scenes/escape/hub_geometry.gd")
const Sign := preload("res://ui/world_sign.gd")
const Objectives := preload("res://scenes/escape/objectives.gd")

const SCREEN_AT := Vector3(0, 1.38, .1)
const SCREEN_SIZE := Vector2(.62, .40)
const POINTER_AT := Vector3(0, 1.72, -.06)
const TURN_TIME := .7
const BLINKS := 3
const BLINK_ON := .22
const BLINK_OFF := .16
const BEAM_COLOR := Color(1, .16, .12)

var locate: Callable = func(_place: String) -> Variant: return null
var pointing := false   ## True while turning and blinking.
var blinks_done := 0    ## Beam flashes in the latest pointing (tests read this).

var _chapter: Label3D
var _text: Label3D
var _pivot: Node3D
var _beam: MeshInstance3D
var _beam_mesh: CylinderMesh
var _dot: MeshInstance3D


func _init() -> void:
	name = "ObjectiveConsole"
	prompt = "Ask the way"


func _ready() -> void:
	super()
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	var bounds := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.8, 1.8, .6)
	bounds.shape = box
	bounds.position = Vector3(0, .9, 0)
	add_child(bounds)
	_build()
	refresh()
	Game.flag_changed.connect(func(flag: String, _v: Variant):
		if flag in Objectives.FLAGS:
			refresh())


func refresh() -> void:
	var o := Objectives.current()
	_chapter.text = o.chapter.to_upper()
	_text.text = o.text


func interact(_player: Node3D) -> void:
	if not pointing:
		await point()
	interacted.emit()


## Turns toward the current objective and blinks the laser at it three times.
func point() -> void:
	var where: Variant = locate.call(Objectives.current().place)
	if not where is Vector3:
		return
	pointing = true
	blinks_done = 0
	var target: Vector3 = where + Vector3(0, 1.0, 0)  # About chest height at the place.
	var from := _pivot.global_position
	var aim := Basis.looking_at(target - from, Vector3.UP)
	var local := (_pivot.get_parent() as Node3D).global_basis.inverse() * aim
	var turn := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn.tween_property(_pivot, "quaternion", local.get_rotation_quaternion(), TURN_TIME)
	await turn.finished
	var length := from.distance_to(target)
	_beam_mesh.height = length
	_beam.position = Vector3(0, 0, -length * .5)
	_dot.position = Vector3(0, 0, -length)
	for i in BLINKS:
		_set_beam(true)
		blinks_done += 1
		Sound.play_at("ui_tick", from, self)
		await get_tree().create_timer(BLINK_ON).timeout
		_set_beam(false)
		await get_tree().create_timer(BLINK_OFF).timeout
	pointing = false


func _set_beam(on: bool) -> void:
	_beam.visible = on
	_dot.visible = on


func _build() -> void:
	var body := Geometry.material(Color("16262b"), .3)
	var brass := Geometry.material(Color("b8955a"), .75)
	var glass := Geometry.material(Color("0b1a1c"), 0.0, .35)
	# A slim pedestal on a wide foot, rising to a slanted screen at eye level.
	Geometry.box(self, Vector3(0, .03, 0), Vector3(.62, .06, .46), body)
	Geometry.box(self, Vector3(0, .62, -.02), Vector3(.22, 1.12, .2), body, true)  # Solid: walk around it.
	Geometry.box(self, Vector3(0, 1.17, 0), Vector3(.74, .05, .3), brass)
	var head := Node3D.new()
	head.position = SCREEN_AT
	head.rotation.x = -.42  # Tilted back toward someone standing in front.
	add_child(head)
	Geometry.box(head, Vector3(0, 0, -.04), Vector3(SCREEN_SIZE.x + .1, SCREEN_SIZE.y + .1, .07), body)
	Geometry.box(head, Vector3(0, 0, .0), Vector3(SCREEN_SIZE.x, SCREEN_SIZE.y, .01), glass)
	Geometry.box(head, Vector3(0, SCREEN_SIZE.y * .5 + .05, -.01), Vector3(SCREEN_SIZE.x + .1, .012, .02), brass)
	var eyebrow := Label3D.new()
	Sign.style(eyebrow, .022, Sign.MUTED)
	eyebrow.text = "FIELD NOTES  /  NEXT"
	eyebrow.position = Vector3(-SCREEN_SIZE.x * .5 + .04, SCREEN_SIZE.y * .5 - .05, .012)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(eyebrow)
	_chapter = Label3D.new()
	Sign.style(_chapter, .045, Sign.GOLD)
	_chapter.position = Vector3(-SCREEN_SIZE.x * .5 + .04, SCREEN_SIZE.y * .5 - .11, .012)
	_chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(_chapter)
	_text = Label3D.new()
	Sign.style(_text, .032, Sign.PAPER)
	_text.position = Vector3(-SCREEN_SIZE.x * .5 + .04, SCREEN_SIZE.y * .5 - .16, .012)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.width = (SCREEN_SIZE.x - .08) / _text.pixel_size
	head.add_child(_text)
	# The laser pointer: a brass collar on the console's back edge with a turning barrel.
	Geometry.box(self, POINTER_AT + Vector3(0, -.08, 0), Vector3(.08, .1, .08), brass)
	_pivot = Node3D.new()
	_pivot.name = "LaserPivot"
	_pivot.position = POINTER_AT
	add_child(_pivot)
	Geometry.box(_pivot, Vector3(0, 0, 0), Vector3(.07, .07, .07), body)
	Geometry.box(_pivot, Vector3(0, 0, -.08), Vector3(.03, .03, .14), brass)
	var lens := MeshInstance3D.new()
	var lens_mesh := SphereMesh.new()
	lens_mesh.radius = .014
	lens_mesh.height = .028
	lens.mesh = lens_mesh
	lens.material_override = _glow(BEAM_COLOR)
	lens.position = Vector3(0, 0, -.155)
	_pivot.add_child(lens)
	# The beam runs along the barrel's -Z; hidden until it blinks.
	var beam_holder := Node3D.new()
	beam_holder.position = Vector3(0, 0, -.16)
	_pivot.add_child(beam_holder)
	_beam_mesh = CylinderMesh.new()
	_beam_mesh.top_radius = .006
	_beam_mesh.bottom_radius = .006
	_beam_mesh.radial_segments = 6
	_beam_mesh.rings = 1
	_beam = MeshInstance3D.new()
	_beam.mesh = _beam_mesh
	_beam.rotation.x = PI * .5   # Cylinders run along Y; lay it along -Z.
	_beam.material_override = _glow(BEAM_COLOR)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam_holder.add_child(_beam)
	_dot = MeshInstance3D.new()
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = .05
	dot_mesh.height = .1
	_dot.mesh = dot_mesh
	_dot.material_override = _glow(BEAM_COLOR, true)
	beam_holder.add_child(_dot)
	_set_beam(false)


static func _glow(color: Color, see_through := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if see_through:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = .8
		mat.no_depth_test = true  # The spot shows on the target even behind a wall.
	return mat
