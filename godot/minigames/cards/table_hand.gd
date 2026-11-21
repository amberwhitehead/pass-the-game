extends Node3D
## Camera-relative physical hand, tucked below the board until approached.
signal chosen(index: int)
const Actor := preload("res://minigames/cards/card_actor.gd")
const Catalog := preload("res://minigames/cards/card_catalog.gd")
const REVEAL_EDGE := 0.78
const RETREAT_EDGE := 0.59
const DEPTH := 2.6
var cards: Array = []
var expanded := false
var _ids: Array = []
var _selected := -1
var _lift := 0.0
var _locked := true
var _await_pointer_exit := false
var _camera: Camera3D
var _view_size := Vector2.ZERO
var _fov := -1.0

func _ready() -> void:
	_camera = get_parent() as Camera3D

func render(ids: Array, energy: int, selected: int, locked: bool) -> void:
	if selected >= 0 and selected != _selected:
		expanded = false
		_await_pointer_exit = true
	elif selected < 0:
		_await_pointer_exit = false
	_selected = selected
	_locked = locked
	if locked:
		expanded = false
	if _ids != ids:
		for card: Node3D in cards:
			card.free()
		cards.clear()
		_ids = ids.duplicate()
		for i in ids.size():
			var card := Actor.new()
			add_child(card)
			card.configure(Catalog.get_card(ids[i]))
			card.pressed.connect(func(): chosen.emit(i))
			cards.append(card)
	for i in cards.size():
		cards[i].set_selected(i == selected)
		var affordable := int(Catalog.get_card(ids[i]).cost) <= energy
		cards[i].set_available(affordable)
		cards[i].set_cue(Actor.Cue.PLAYABLE if affordable and selected < 0 and not locked else Actor.Cue.NONE)
		cards[i].disabled = locked
	_update_collisions()
	_layout()

func set_expanded(value: bool) -> void:
	if value and not expanded and not _locked:
		Sound.play("card_hand", self)
	expanded = value and not _locked
	_update_collisions()

func _update_collisions() -> void:
	# Retreating cards must not intercept a quick click on the board behind them.
	for card: Node3D in cards:
		card.collider.collision_layer = 1 if expanded and not _locked else 0

func pointer_at(point: Vector2, view_size: Vector2) -> void:
	if _locked or view_size.y <= 0:
		return
	var fraction := point.y / view_size.y
	if _await_pointer_exit:
		if fraction < REVEAL_EDGE:
			_await_pointer_exit = false
		return
	if fraction >= REVEAL_EDGE and Rect2(Vector2.ZERO, view_size).has_point(point):
		set_expanded(true)
	elif fraction < RETREAT_EDGE:
		set_expanded(false)

func reveal_touch(point: Vector2, view_size: Vector2) -> bool:
	if not _locked and not expanded and point.y >= view_size.y * REVEAL_EDGE:
		_await_pointer_exit = false
		set_expanded(true)
		return true
	return false

func is_settled() -> bool:
	return absf(_lift - (1.0 if expanded else 0.0)) < 0.002

func _process(delta: float) -> void:
	var target := 1.0 if expanded else 0.0
	var next := move_toward(_lift, target, delta * 4.5)
	var current_size := Vector2(_camera.get_viewport().size)
	if next != _lift or current_size != _view_size or _fov != _camera.fov:
		_lift = next
		_view_size = current_size
		_fov = _camera.fov
		_layout()

func _layout() -> void:
	if _camera == null:
		return
	var view_size := Vector2(_camera.get_viewport().size)
	var half_height := tan(deg_to_rad(_camera.fov / 2.0)) * DEPTH
	var width := half_height * 2.0 * view_size.x / maxf(1.0, view_size.y)
	var spacing := minf(0.51, (width * 0.83 - 0.46) / maxf(1.0, cards.size() - 1))
	var ease := smoothstep(0.0, 1.0, _lift)
	# Resting card headers peek above the bottom edge; raised cards fit above it.
	var center_y := lerpf(-half_height * 1.06, -half_height * 0.57, ease)
	for i in cards.size():
		var offset: float = i - (cards.size() - 1) / 2.0
		var card: Node3D = cards[i]
		card.position = Vector3(offset * spacing, center_y - absf(offset) * 0.012 + (0.04 if i == _selected else 0.0), -DEPTH + i * 0.006)
		card.rotation = Vector3(PI / 2.0 - 0.08, 0, deg_to_rad(-offset * 2.5))
		card.scale = Vector3.ONE * 0.46
