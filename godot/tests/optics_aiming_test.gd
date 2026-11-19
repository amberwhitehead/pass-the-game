extends "res://tests/test_suite.gd"
## Interaction and optical regressions for continuous rotation, rather than
## a test that merely repeats the discrete setup helper used by older scenes.

const Model := preload("res://scenes/escape/optics_model.gd")
var checks := 0
var failures := 0

class PlayerDouble extends Node:
	var interaction_locked := false
	var _look_finger := 3
	var velocity := Vector3.ONE

class OpenLoopModel extends Model:
	# Remove the engine only in this fixture to exercise a genuine closed path.
	func _rectangle_distance(_origin: Vector2, _direction: Vector2, _box: Rect2) -> float:
		return -1.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player := PlayerDouble.new()
	root.add_child(player)
	var aim: Node = load("res://scenes/escape/optics_aiming.gd").new()
	aim.configure(player)
	root.add_child(aim)
	var targets: Array[float] = [0.0, PI / 4]
	aim.begin("S", deg_to_rad(10), targets)
	check(player.interaction_locked and player._look_finger == -1 and player.velocity == Vector3(0, 1, 0),
		"begin borrows movement, clears ongoing camera drag, and keeps vertical velocity so a jump lands")
	check(not aim.snapped and is_equal_approx(aim.angle, deg_to_rad(10)), "free angle remains continuous away from hardware")
	aim.nudge(deg_to_rad(-7))
	check(aim.snapped and is_zero_approx(aim.angle), "enters detent within four degrees")
	aim.nudge(deg_to_rad(2))
	check(aim.snapped and is_zero_approx(aim.angle), "hysteresis holds between capture and release thresholds")
	aim.nudge(deg_to_rad(2))
	check(not aim.snapped and is_equal_approx(aim.angle, deg_to_rad(7)), "raw motion releases the detent without sticky accumulation")
	aim.nudge(deg_to_rad(35))
	check(aim.snapped and is_equal_approx(aim.angle, PI / 4), "motion can acquire a different socket")
	aim.finish()
	check(not player.interaction_locked and player._look_finger == -1, "finish restores movement without a stray camera drag")
	player.interaction_locked = true
	var across_seam: Array[float] = [deg_to_rad(-179)]
	aim.begin("S", deg_to_rad(179), across_seam)
	check(aim.snapped and is_equal_approx(aim.angle, deg_to_rad(-179)), "detent works across the angle wrapping seam")
	aim.finish()
	check(player.interaction_locked, "finish preserves a lock owned by another interaction")
	player.interaction_locked = false
	aim.begin("S", 0.0, targets)
	var cancel := InputEventAction.new()
	cancel.action = "back"
	cancel.pressed = true
	aim._unhandled_input(cancel)
	check(not aim.active_id.is_empty(), "the opening interaction cannot immediately close adjustment")
	await process_frame
	await process_frame
	aim._unhandled_input(cancel)
	check(aim.active_id.is_empty() and not player.interaction_locked, "back exits aiming and releases movement")
	_test_optics()
	await _test_pool_and_commit(player)
	aim.queue_free()
	player.queue_free()
	await process_frame
	print("OPTICS AIMING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_optics() -> void:
	var model := Model.new()
	check(model.source_snap_angles().size() == 5, "every distinct socket and lens direction has a source detent")
	check(Model.world(Model.RECEIVER).is_equal_approx(Vector3(10.78, 1.25, -1.72)), "receiver is on door two's north jamb")
	model.source_angle = deg_to_rad(12)
	var free_trace: Dictionary = model.trace()
	var free_direction: Vector2 = free_trace.segments[0].to - free_trace.segments[0].from
	check(is_equal_approx(free_direction.angle(), deg_to_rad(12)), "free aim traces a real angle instead of a hidden preset")
	model.source_angle = PI / 4
	model.items.A = "prism"
	model.items.B = "prism"
	model.items.J = ""
	model.items.K = ""
	model.items.L = "lens_yellow"
	model.items.M = "lens_blue"
	model.head_angles.A = -PI / 4
	model.head_angles.B = PI / 4
	check(model.trace().won, "absolute optical head angles solve the intended route")
	model.head_angles.A += deg_to_rad(3)
	var tolerant: Dictionary = model.trace()
	check(tolerant.won, "small inlet alignment tolerance still accepts the intended route")
	var incoming: Vector2 = tolerant.incoming.A
	var outgoing: Vector2 = tolerant.segments[2].to - tolerant.segments[2].from
	check(absf(incoming.normalized().dot(outgoing.normalized())) < 0.0001, "accepted head tolerance never grants a non-orthogonal outgoing beam")
	model.head_angles.A += deg_to_rad(6)
	check(model.trace().hit == "misaligned" and model.trace().alignment_id == "A", "misaligned prism blocks instead of allowing a free-angle shortcut")
	var restored := Model.new()
	restored.restore(model.save_state())
	check(restored.items == model.items and restored.head_angles == model.head_angles and restored.source_angle == model.source_angle, "items and continuous head angles survive restoring state")
	check(restored.trace().hit == "misaligned", "restoring does not silently correct an unsolved alignment")
	var loop := OpenLoopModel.new()
	loop.source_angle = PI / 4
	for id: String in loop.SOCKETS:
		loop.items[id] = "prism"
	loop.head_angles = {"A": -PI / 4, "B": PI / 4, "D": 3 * PI / 4, "C": -3 * PI / 4}
	var loop_trace: Dictionary = loop.trace()
	check(loop_trace.hit == "loop" and loop_trace.segments.size() <= 24, "closed optical path terminates within the segment budget")


func _test_pool_and_commit(player: Node) -> void:
	var game: Node = root.get_node("Game")
	game.set_flag("escape_optics_state", {})
	var optics: Node = load("res://scenes/escape/optics_controller.gd").new()
	optics.configure(null, player)
	root.add_child(optics)
	await process_frame
	var resources: Array[int] = []
	for segment: MeshInstance3D in optics._beams._segments:
		resources.append(segment.get_instance_id())
		resources.append(segment.mesh.get_instance_id())
	var saved: Dictionary = game.get_flag("escape_optics_state").duplicate(true)
	optics.begin_aim("S")
	for index in 200:
		optics.aiming.nudge(deg_to_rad(.17))
	check(game.get_flag("escape_optics_state") == saved, "live aiming does not rewrite persistent state on every frame")
	var unchanged := true
	for index in optics._beams._segments.size():
		var segment: MeshInstance3D = optics._beams._segments[index]
		unchanged = unchanged and segment.get_instance_id() == resources[index * 2] and segment.mesh.get_instance_id() == resources[index * 2 + 1]
	check(unchanged and optics._beams.get_child_count() == 27, "beam updates reuse the fixed node and mesh pool")
	var angle: float = optics.model.source_angle
	optics.end_aim()
	check(is_equal_approx(game.get_flag("escape_optics_state").source_angle, angle), "finishing adjustment commits the chosen angle")
	await _test_fixed_head(optics)
	optics.begin_aim("S")
	optics.queue_free()
	await process_frame
	check(not player.interaction_locked, "freeing optics leaves player input available")


func _test_fixed_head(optics: Node) -> void:
	optics.model.items.A = "prism"
	optics.model.items.B = "prism"
	optics.model.source_angle = PI / 4
	optics.refresh()
	await create_timer(.22).timeout
	var head: Node = optics.devices.B
	optics.begin_aim("B")
	check(is_equal_approx(head._contents.rotation.y, -3 * PI / 4), "beginning prism adjustment preserves its current outlet pose")
	optics.aiming.nudge(PI)
	check(is_equal_approx(head._contents.rotation.y, PI / 4), "manual prism rotation moves the visible outlet immediately")
	optics.end_aim()
	check(is_equal_approx(head._contents.rotation.y, PI / 4) and is_equal_approx(optics.model.head_angles.B, PI / 4), "finishing preserves the chosen pose opposite the legacy default")
	# Record the actual Tween reference, not only is_running(): recreating and
	# immediately killing a default-angle tween would otherwise escape this test.
	var old_tween: Tween = head._rotation_tween
	var stable := true
	optics.begin_aim("S")
	for index in 60:
		optics.aiming.nudge(deg_to_rad(.025 if index % 2 else -.025))
		stable = stable and head._rotation_tween == old_tween and is_equal_approx(head._contents.rotation.y, PI / 4)
	optics.end_aim()
	check(stable, "source adjustment never creates a transient default tween on a manually aimed prism")
	check(not head._rotation_tween or not head._rotation_tween.is_running(), "the adjusted portable head has no running rotation tween")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
