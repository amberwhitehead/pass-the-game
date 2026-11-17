extends Interactable
## A real passage: the collision opens only after the two leaves clear it.

signal opened

const Geometry := preload("res://scenes/escape/hub_geometry.gd")
const HALF_WIDTH := 0.70
const OPEN_X := 2.15

var unlocked := false
var is_open := false
var _left: Node3D
var _right: Node3D
var _blocker: CollisionShape3D
var _status: Label3D
var _glow: StandardMaterial3D
var _motion: Tween


func _ready() -> void:
	super()
	prompt = "Inspect sealed door"
	var metal := Geometry.material(Color(0.105, 0.14, 0.16), 0.65)
	var panel := Geometry.surface(Color(0.18, 0.24, 0.25), .55, .36)
	_glow = Geometry.material(Color(0.55, 0.75, 0.25), 0.0, 1.1)
	for side in [-1, 1]:
		var leaf := Node3D.new()
		leaf.position = Vector3(side * HALF_WIDTH, 0, 0)
		add_child(leaf)
		Geometry.box(leaf, Vector3(0, 1.75, 0), Vector3(1.4, 3.5, 0.22), metal)
		Geometry.box(leaf, Vector3(0, 1.75, 0.125), Vector3(1.18, 2.85, 0.045), panel)
		Geometry.box(leaf, Vector3(-side * 0.58, 1.75, 0.16), Vector3(0.055, 2.8, 0.06), _glow)
		for height in [.48, 1.05, 2.95]:
			Geometry.box(leaf, Vector3(0, height, .17), Vector3(1.16, .065, .055), metal)
		if side < 0:
			_left = leaf
		else:
			_right = leaf
	var body := StaticBody3D.new()
	add_child(body)
	_blocker = CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(2.8, 3.5, 0.30)
	_blocker.shape = volume
	_blocker.position.y = 1.75
	body.add_child(_blocker)
	var interaction := CollisionShape3D.new()
	var area := BoxShape3D.new()
	area.size = Vector3(2.8, 2.5, 1.1)
	interaction.shape = area
	interaction.position = Vector3(0, 1.25, 0.4)
	add_child(interaction)
	_status = Geometry.label(self, "SEALED · GREEN LIGHT REQUIRED", Vector3(0, 2.55, 0.16),
		0.0, Color(0.72, 0.85, 0.54), 24, 0.0045)


func interact(_player: Node3D) -> void:
	if unlocked:
		return
	await get_node("/root/Dialogue").say("Door 2", ["The green receiver beside this door controls the lock. A beam reaches it already, but something is missing from its color."])


func unlock(animate := true) -> void:
	if unlocked:
		return
	unlocked = true
	prompt = "Door 2 unlocked"
	_status.text = "ROMAN FLOW · OPEN"
	_glow.albedo_color = Color(0.2, 1.0, 0.55)
	_glow.emission = Color(0.2, 1.0, 0.55)
	if not animate:
		_left.position.x = -OPEN_X
		_right.position.x = OPEN_X
		_finish_open()
		return
	_motion = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	Sound.play_at("door", global_position + Vector3.UP, self, 0, 1.2)
	_motion.tween_property(_left, "position:x", -OPEN_X, 1.25)
	_motion.tween_property(_right, "position:x", OPEN_X, 1.25)
	_motion.chain().tween_callback(_finish_open)


func _finish_open() -> void:
	_blocker.set_deferred("disabled", true)
	is_open = true
	monitorable = false
	_status.hide()
	opened.emit()
