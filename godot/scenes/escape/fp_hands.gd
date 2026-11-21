extends Node3D
## The player's own hands, seen in first person: built from a few primitive meshes in the
## hall's dark-teal and brass, parented to the camera.
##
## - Walking swings them back and forth, alternately, with step speed; jumping lifts them
##   and landing dips them.
## - Interacting reaches one hand out toward the thing (the free one, if one holds an item).
## - A conversation opening gets a wave from the left hand, which then relaxes.
## - A carried item sits in the right hand (`grip`), its fingers curled round it.
## - Hidden while a minigame runs (its camera handoff included), in cinematics, and while
##   aiming the optics.
##
## The whole rig is scaled by RIG_SCALE and pulled that much closer to the camera, which
## looks the same but keeps every part inside the player's collision capsule (radius
## 0.35), so the hands never poke into a wall, even mid-reach.

const Art := preload("res://scenes/escape/optics_art.gd")
const RIG_SCALE := 0.38
const REST := Vector3(0.27, -0.31, -0.56)   ## Right hand at rest (rig units); left mirrors.
const SWING := 0.035      ## Forward/back swing at full walking speed.
const BOB := 0.016        ## Up/down bob at full walking speed.
const STEP_RATE := 9.0    ## Swing phase per second at full walking speed.
const REACH_TIME := 0.5
const REACH_DISTANCE := 0.15
const WAVE_TIME := 2.0
const SKIN := Color(0.80, 0.61, 0.49)
const SLEEVE := Color(0.10, 0.21, 0.23)
const BRASS := Color(0.68, 0.50, 0.25)

var right: Node3D
var left: Node3D
var grip: Node3D           ## Where a carried item sits, in the right hand.
var holding := false       ## True while the inventory holds something.
var reach_t := -1.0        ## Seconds into a reach, or < 0.
var wave_t := -1.0         ## Seconds into a wave, or < 0.

var _player: Node3D
var _inventory: Node
var _phase := 0.0
var _speed := 0.0          ## Smoothed walking speed, 0..1.
var _air := 0.0            ## Smoothed lift while airborne.
var _land := 0.0           ## Landing dip, decaying.
var _was_on_floor := true
var _fall_speed := 0.0
var _reach_hand: Node3D
var _reach_dir := Vector3.FORWARD
var _was_talking := false


func configure(player: Node3D, inventory: Node) -> void:
	_player = player
	_inventory = inventory
	if player.has_signal("reached") and not player.reached.is_connected(reach):
		player.reached.connect(reach)
	if inventory and not inventory.changed.is_connected(_on_item_changed):
		inventory.changed.connect(_on_item_changed)
	_on_item_changed(inventory.held_item if inventory else "")


func _ready() -> void:
	name = "Hands"
	scale = Vector3.ONE * RIG_SCALE
	right = _build_hand(1.0)
	left = _build_hand(-1.0)
	grip = Node3D.new()
	grip.name = "Grip"
	grip.position = Vector3(0, -0.035, -0.09)
	right.add_child(grip)
	_pose(right, 1.0, Vector3.ZERO, Vector3.ZERO, 0.15)
	_pose(left, -1.0, Vector3.ZERO, Vector3.ZERO, 0.15)


## Starts a reach toward a thing being interacted with (the player's `reached` signal).
func reach(target: Node) -> void:
	_reach_hand = left if holding else right
	var point: Vector3 = target.get_focus_position() if target != null and target.has_method("get_focus_position") \
		else global_position - global_basis.z
	var local := to_local(point)
	_reach_dir = local.normalized() if local.length() > 0.001 else Vector3.FORWARD
	reach_t = 0.0


func wave() -> void:
	wave_t = 0.0


func _on_item_changed(item: String) -> void:
	holding = not item.is_empty()


func _process(delta: float) -> void:
	if _player == null:
		return
	visible = not (MiniGames.is_running() or bool(_player.get("cinematic_locked")) \
		or bool(_player.get("interaction_locked")))
	var talking := Dialogue.active
	if talking and not _was_talking:
		wave()
	_was_talking = talking
	_update_motion(delta)
	if reach_t >= 0.0:
		reach_t += delta
		if reach_t >= REACH_TIME:
			reach_t = -1.0
	if wave_t >= 0.0:
		wave_t += delta
		if wave_t >= WAVE_TIME:
			wave_t = -1.0

	# Walking: the hands swing in opposition, bobbing twice per stride.
	var swing := sin(_phase) * SWING * _speed
	var bob := absf(cos(_phase)) * BOB * _speed
	var lift := Vector3(0, _air * 0.05 - _land, 0)
	var r_offset := Vector3(0, -bob, -swing) + lift
	var l_offset := Vector3(0, -bob, swing) + lift
	var r_rot := Vector3(swing * 1.5, 0, 0)
	var l_rot := Vector3(-swing * 1.5, 0, 0)
	var r_curl := 1.15 if holding else 0.25
	var l_curl := 0.25
	if holding:
		r_offset += Vector3(-0.03, 0.04, 0.0)  # Held up a little, to show what's carried.

	var k := _reach_amount()
	if k > 0.0:
		var push := _reach_dir * REACH_DISTANCE * k + Vector3(0, 0.05, 0) * k
		if _reach_hand == right:
			r_offset += push
			r_rot.x += 0.35 * k
			r_curl = lerpf(r_curl, 0.0, k) if not holding else r_curl
		else:
			l_offset += push
			l_rot.x += 0.35 * k
			l_curl = lerpf(l_curl, 0.0, k)

	var w := _wave_amount()
	if w > 0.0:
		# Raised, palm out, fingers up, rocking side to side.
		l_offset += Vector3(0.10, 0.26, 0.05) * w
		l_rot += Vector3(1.35 * w, 0.0, sin(wave_t * 11.0) * 0.5 * w)
		l_curl = lerpf(l_curl, 0.0, w)

	_pose(right, 1.0, r_offset, r_rot, r_curl)
	_pose(left, -1.0, l_offset, l_rot, l_curl)


## 0 → 1 → 0 over a reach.
func _reach_amount() -> float:
	if reach_t < 0.0:
		return 0.0
	return sin(PI * clampf(reach_t / REACH_TIME, 0.0, 1.0))


## Up quickly, wave, then down: 0..1.
func _wave_amount() -> float:
	if wave_t < 0.0:
		return 0.0
	var up := smoothstep(0.0, 0.25, wave_t)
	var down := 1.0 - smoothstep(WAVE_TIME - 0.4, WAVE_TIME, wave_t)
	return minf(up, down)


func _update_motion(delta: float) -> void:
	var on_floor: bool = _player.is_on_floor() if _player.has_method("is_on_floor") else true
	var velocity: Vector3 = _player.get("velocity") if _player.get("velocity") != null else Vector3.ZERO
	var top_speed: float = maxf(0.1, float(_player.get("speed")) if _player.get("speed") != null else 3.5)
	var flat := Vector2(velocity.x, velocity.z).length() / top_speed
	_speed = lerpf(_speed, clampf(flat, 0.0, 1.0) if on_floor else 0.0, minf(1.0, delta * 8.0))
	_phase = fmod(_phase + delta * STEP_RATE * _speed, TAU)
	if _speed < 0.05:
		_phase = lerpf(_phase, 0.0 if _phase < PI else TAU, minf(1.0, delta * 3.0))
	_air = lerpf(_air, 0.0 if on_floor else 1.0, minf(1.0, delta * 6.0))
	if not on_floor:
		_fall_speed = minf(_fall_speed, velocity.y)
	elif not _was_on_floor:
		_land = clampf(-_fall_speed * 0.012, 0.0, 0.07)
		_fall_speed = 0.0
	_land = move_toward(_land, 0.0, delta * 0.3)
	_was_on_floor = on_floor


func _pose(hand: Node3D, side: float, offset: Vector3, rot: Vector3, curl: float) -> void:
	hand.position = Vector3(REST.x * side, REST.y, REST.z) + Vector3(offset.x * side, offset.y, offset.z)
	# A slight inward turn reads as relaxed hands rather than two planks.
	hand.rotation = Vector3(0.12 + rot.x, 0.22 * side + rot.y, -0.10 * side + rot.z * side)
	for finger: Node3D in hand.get_meta("fingers"):
		finger.rotation.x = -curl
	var thumb: Node3D = hand.get_meta("thumb")
	thumb.rotation.x = -curl * 0.6


## Sleeve, brass cuff, palm, four fingers and a thumb. Fingers point down -Z, palm down;
## each finger hangs from a knuckle pivot so it can curl.
func _build_hand(side: float) -> Node3D:
	var hand := Node3D.new()
	hand.name = "Right" if side > 0.0 else "Left"
	add_child(hand)
	var skin := Art.material(SKIN)
	var sleeve := Art.cylinder(hand, 0.058, 0.36, Vector3(0, 0, 0.21), Art.material(SLEEVE))
	sleeve.rotation.x = PI / 2.0
	var cuff := Art.cylinder(hand, 0.064, 0.035, Vector3(0, 0, 0.035), Art.material(BRASS, false, true))
	cuff.rotation.x = PI / 2.0
	var wrist := Art.cylinder(hand, 0.036, 0.05, Vector3(0, 0, -0.005), skin)
	wrist.rotation.x = PI / 2.0
	Art.rounded_box(hand, Vector3(0.088, 0.034, 0.1), Vector3(0, 0, -0.06), skin, 0.014)
	var fingers: Array[Node3D] = []
	var lengths := [0.05, 0.058, 0.055, 0.045]
	for i in 4:
		var knuckle := Node3D.new()
		knuckle.position = Vector3((-0.031 + i * 0.0207) * side, 0, -0.108)
		hand.add_child(knuckle)
		Art.rounded_box(knuckle, Vector3(0.018, 0.02, lengths[i]), Vector3(0, 0, -lengths[i] * 0.5), skin, 0.008)
		fingers.append(knuckle)
	var thumb := Node3D.new()
	thumb.position = Vector3(-0.045 * side, -0.004, -0.045)
	thumb.rotation.y = 0.6 * side
	hand.add_child(thumb)
	var bone := Node3D.new()
	bone.rotation.y = 0.5 * side
	thumb.add_child(bone)
	Art.rounded_box(bone, Vector3(0.02, 0.02, 0.05), Vector3(0, 0, -0.025), skin, 0.008)
	hand.set_meta("fingers", fingers)
	hand.set_meta("thumb", thumb)
	for part in hand.find_children("*", "MeshInstance3D", true, false):
		(part as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return hand
