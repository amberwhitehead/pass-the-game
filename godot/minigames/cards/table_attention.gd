extends Node3D
## A tilted enamel counter beside the bell. Reads match state; never spends it.
const Style := preload("res://ui/game_style.gd")
const Craft := preload("res://minigames/cards/table_craft.gd")
const MAX_ICONS := 8
var _amount: Label3D
var _sockets: Array[Node3D] = []
var _tokens: Array[MeshInstance3D] = []
var _motions: Array[Tween] = []
var _available: Material
var _spent: Material
var _current := -1
var _capacity := -1

func _ready() -> void:
	position = Vector3(2.47, .20, -.93)
	rotation.x = .20
	var brass := Craft.material(Color("a58954"), .4, .65)
	var enamel := Craft.material(Color("182b2b"), .8)
	var recess := Craft.material(Color("080f10"), .95)
	_available = Craft.material(Color("e6c980"), .4, .3)
	_spent = Craft.material(Color("1b2929"), .9)
	Craft.box(self, "Support", Vector3(1.08, .17, .27), Vector3(0, -.13, -.43), enamel)
	Craft.box(self, "BrassFrame", Vector3(1.33, .065, 1.43), Vector3.ZERO, brass)
	Craft.box(self, "EnamelFace", Vector3(1.25, .016, 1.35), Vector3(0, .04, 0), enamel, .01)
	_text("ATTENTION", -.46, 40, Style.GOLD)
	_amount = _text("", -.10, 65, Style.PAPER)
	Craft.box(self, "Divider", Vector3(1.02, .004, .008), Vector3(0, .052, .15), brass, .001)
	for i in MAX_ICONS:
		var socket := Node3D.new()
		socket.name = "AttentionIcon%d" % (i + 1)
		add_child(socket)
		var rim := Craft.box(socket, "Rim", Vector3(.175, .018, .175), Vector3(0, .06, 0), brass, .004)
		rim.rotation.y = PI / 4
		var hollow := Craft.box(socket, "Recess", Vector3(.145, .008, .145), Vector3(0, .073, 0), recess, .002)
		hollow.rotation.y = PI / 4
		var token := Craft.box(socket, "Token", Vector3(.115, .018, .115), Vector3(0, .09, 0), _available, .004)
		token.rotation.y = PI / 4
		_sockets.append(socket)
		_tokens.append(token)
		_motions.append(null)

func _text(copy: String, z: float, point: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.font = Style.font()
	label.font_size = point
	label.pixel_size = .0034
	label.text = copy
	label.modulate = color
	label.outline_size = 0
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.position = Vector3(0, .058, z)
	label.rotation.x = -PI / 2
	add_child(label)
	return label

func render(current: int, capacity: int) -> void:
	if current == _current and capacity == _capacity:
		return
	_amount.text = "%d / %d" % [current, capacity]
	_amount.modulate = Style.PAPER if current > 0 else Style.MUTED
	var count := clampi(capacity, 0, MAX_ICONS)
	for i in MAX_ICONS:
		_sockets[i].visible = i < count
		if i >= count:
			continue
		# Five Attention forms a balanced 3+2 arrangement inside the brass frame.
		var per_row := 3 if count in [5, 6] else 4
		var row := i / per_row
		var columns := mini(per_row, count - row * per_row)
		_sockets[i].position = Vector3((i % per_row - (columns - 1) * .5) * .27, 0, .37 if count <= 4 else .29 + row * .23)
		var active := i < current
		_tokens[i].material_override = _available if active else _spent
		var height := .10 if active else .072
		if _motions[i] != null:
			_motions[i].kill()
		if _current < 0 or i >= _capacity:
			_tokens[i].position.y = height
		else:
			_motions[i] = create_tween()
			_motions[i].tween_property(_tokens[i], "position:y", height, .18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_current = current
	_capacity = capacity
