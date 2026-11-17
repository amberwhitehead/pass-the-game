extends Node
## Edge-triggered audio for continuous optics; rendering updates stay silent.
var _controller: Node3D
var _active := ""
var _angle := 0.0
var _travel := 0.0
var _snapped := false
var _colors := 0
var _initialized := false

func _ready() -> void:
	_controller = get_parent()
	_controller.aiming.adjusted.connect(_adjusted)
	_controller.aiming.finished.connect(_finished)
	_controller.changed.connect(_trace_changed)

func _adjusted(angle: float, snapped: bool) -> void:
	var id: String = _controller.aiming.active_id
	var at: Vector3 = _controller.devices[id].global_position + Vector3.UP
	if _active != id:
		_active = id
		_angle = angle
		_travel = 0
		_snapped = snapped
		Sound.play_at("dial_grab", at, self)
		return
	_travel += absf(angle_difference(_angle, angle))
	_angle = angle
	if snapped and not _snapped:
		Sound.play_at("dial_snap", at, self)
		_travel = 0
	elif not snapped and _travel > deg_to_rad(12):
		Sound.play_at("dial_turn", at, self)
		_travel = 0
	_snapped = snapped

func _finished(_id: String) -> void:
	_active = ""

func _trace_changed() -> void:
	var color: int = _controller.result.get("color", 0)
	if _initialized and color != _colors and color != 0 and not _controller.result.get("won", false):
		Sound.play_at("lens_light", _controller.devices.S.global_position + Vector3.UP, self)
	_colors = color
	_initialized = true
