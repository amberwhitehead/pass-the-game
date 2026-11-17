extends Node3D
## Physical score instrument and draw pile. Presentation only; the match owns values.
const Style := preload("res://ui/game_style.gd")
const Meshes := preload("res://scenes/escape/hub_meshes.gd")
const DRAW_CENTER := Vector3(-2.6, 0, 1.42)
var marker: MeshInstance3D
var _score: Label3D
var _count: Label3D
var _layers: Array[MeshInstance3D] = []
var _motion: Tween
var _balance := 0
var _back: MeshInstance3D
var _player_goal: Label3D
var _enemy_goal: Label3D
var _reserve: Label3D
var _reserve_panel: Node3D

func _ready() -> void:
	_build_score()
	_build_deck()
	_build_reserve()

func _material(color: Color, metal := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metal
	result.roughness = .45 if metal else .85
	return result

func _box(at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = Meshes.chamfer_box(size, .018)
	node.material_override = material
	node.position = at
	add_child(node)
	return node

func _text(copy: String, at: Vector3, size := 42, color: Color = Style.PAPER, serif := false) -> Label3D:
	var label := Label3D.new()
	label.font = Style.font(serif)
	label.font_size = size
	label.pixel_size = .0025
	label.text = copy
	label.modulate = color
	label.outline_size = 0
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.position = at
	label.rotation.x = -PI / 2
	add_child(label)
	return label

func _build_score() -> void:
	var brass := _material(Color("af915c"), .65)
	var enamel := _material(Color("182b2b"))
	_box(Vector3(-2.6, .027, -.61), Vector3(.96, .055, 2.9), brass)
	_box(Vector3(-2.6, .059, -.61), Vector3(.91, .016, 2.84), enamel)
	_text("BALANCE", Vector3(-2.6, .072, -1.78), 34, Style.GOLD)
	_score = _text("+0", Vector3(-2.6, .074, -1.43), 72, Style.PAPER, true)
	_player_goal = _text("YOU  +10", Vector3(-2.6, .073, -1.06), 25, Style.TEAL)
	_enemy_goal = _text("HIM  −10", Vector3(-2.6, .073, .57), 25, Color("cf9c82"))
	_box(Vector3(-2.6, .075, -.25), Vector3(.022, .008, 1.38), brass)
	for i in 21:
		var major := i % 5 == 0
		_box(Vector3(-2.6, .08, -.25 + (i - 10) * .065), Vector3(.38 if major else .21, .009, .012), brass)
	marker = MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = .105
	shape.bottom_radius = .13
	shape.height = .055
	shape.radial_segments = 32
	marker.mesh = shape
	marker.material_override = brass
	marker.position = Vector3(-2.6, .125, -.25)
	add_child(marker)
	var inset := MeshInstance3D.new()
	var gem := SphereMesh.new()
	gem.radius = .055
	gem.height = .045
	inset.mesh = gem
	inset.position.y = .03
	inset.material_override = _material(Style.TEAL.darkened(.25), .2)
	marker.add_child(inset)

func _build_deck() -> void:
	var paper := _material(Color("d6c9aa"))
	var leather := _material(Color("233b39"))
	var brass := _material(Color("ad8d53"), .5)
	_box(DRAW_CENTER + Vector3(0, .018, 0), Vector3(.98, .035, 1.23), leather)
	for i in 7:
		_layers.append(_box(DRAW_CENTER + Vector3(sin(i * 4.0) * .008, .055 + i * .018, 0), Vector3(.73, .016, .99), paper))
	_back = _box(DRAW_CENTER + Vector3(0, .185, 0), Vector3(.73, .012, .99), leather)
	# Brass printed back design, deliberately independent of future face artwork.
	for sign_value in [-1, 1]:
		var side := _box(Vector3(sign_value * .31, .009, 0), Vector3(.008, .004, .86), brass)
		side.reparent(_back, false)
		var end := _box(Vector3(0, .009, sign_value * .43), Vector3(.62, .004, .008), brass)
		end.reparent(_back, false)
	for i in 3:
		var stamp := _box(Vector3(0, .011 + i*.006, 0), Vector3(.26 - i*.07, .006, .26 - i*.07), brass if i % 2 == 0 else leather)
		stamp.reparent(_back, false)
		stamp.rotation.y = PI / 4
	_text("DRAW PILE", DRAW_CENTER + Vector3(0, .037, .71), 29, Style.GOLD)
	_count = _text("16", DRAW_CENTER + Vector3(.48, .04, 0), 42, Style.PAPER, true)

func _build_reserve() -> void:
	# A small tilted dealer's counter sits behind the combat row. The accessory
	# parent shifts left for four lanes; this local x accounts for that shift.
	_reserve_panel = Node3D.new()
	_reserve_panel.name = "DealerReserve"
	_reserve_panel.position = Vector3(2.60, .20, -2.22)
	_reserve_panel.rotation.x = .35
	add_child(_reserve_panel)
	var brass := _material(Color("af915c"), .65)
	var enamel := _material(Color("182b2b"))
	var support := _box(Vector3(0, -.16, -.24), Vector3(1.1, .25, .23), enamel)
	support.reparent(_reserve_panel, false)
	var frame := _box(Vector3.ZERO, Vector3(1.35, .055, .94), brass)
	frame.reparent(_reserve_panel, false)
	var face := _box(Vector3(0, .036, 0), Vector3(1.27, .018, .86), enamel)
	face.reparent(_reserve_panel, false)
	var title := _text("RESERVE", Vector3(0, .052, -.24), 48, Style.GOLD)
	title.pixel_size = .0036
	title.reparent(_reserve_panel, false)
	_reserve = _text("", Vector3(0, .052, .16), 78, Style.PAPER)
	_reserve.pixel_size = .0036
	_reserve.reparent(_reserve_panel, false)
	_reserve_panel.visible = false

func render(balance: int, deck_count: int, goal := 10, reserve := -1) -> void:
	_score.text = "%+d" % balance
	_player_goal.text = "YOU  +%d" % goal
	_enemy_goal.text = "HIM  −%d" % goal
	_reserve_panel.visible = reserve >= 0
	_reserve.text = str(reserve)
	_score.modulate = Style.TEAL if balance > 0 else (Color("dfac91") if balance < 0 else Style.PAPER)
	_count.text = str(deck_count)
	var layers := clampi(ceili(deck_count / 2.0), 0, 7)
	for i in _layers.size():
		_layers[i].visible = i < layers
	_back.visible = deck_count > 0
	_back.position.y = .061 + layers * .018
	if balance == _balance:
		return
	_balance = balance
	if _motion:
		_motion.kill()
	_motion = create_tween()
	_motion.tween_property(marker, "position:z", -.25 - clampf(float(balance) / maxf(1, goal), -1, 1) * .65, .25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
