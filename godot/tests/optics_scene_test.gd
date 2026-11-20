extends "res://tests/test_suite.gd"

var checks := 0
var failures := 0

class Carry extends Node:
	signal changed(item: String)
	var held_item := ""
	func exchange(item: String) -> String:
		var old := held_item
		held_item = item
		changed.emit(held_item)
		return old


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var carry := Carry.new()
	root.add_child(carry)
	var optics: Node3D = load("res://scenes/escape/optics_controller.gd").new()
	optics.configure(carry)
	root.add_child(optics)
	await process_frame
	check(optics.devices.size() == 11, "all optical devices exist (with the lamp socket F and its mount N)")
	check(optics.result.hit == "receiver" and optics.result.color == 1, "initial rendered trace")
	check(optics.devices.A.turn_handle.collision_layer == 0, "empty socket cannot rotate")
	optics.exchange_item("J")
	check(carry.held_item == "lens_yellow" and optics.model.items.J == "", "take yellow")
	optics.exchange_item("A")
	check(carry.held_item == "lens_yellow" and optics.model.items.A == "", "incompatible placement preserves both items")
	optics.exchange_item("K")
	check(carry.held_item == "lens_blue" and optics.model.items.K == "lens_yellow", "one-item swap is atomic")
	optics.exchange_item("M")
	optics.exchange_item("K")
	optics.exchange_item("L")
	carry.held_item = "prism"
	optics.exchange_item("A")
	carry.held_item = "prism"
	optics.exchange_item("B")
	optics.rotate_prism("S")
	optics.rotate_prism("B")
	check(optics.result.won, "full interaction sequence solves")
	check(bool(root.get_node("Game").get_flag("escape_prism_solved")), "success persists")
	check(optics.devices.B.turn_handle.collision_layer == 1, "installed prism can rotate")
	for _direction in 4:
		optics.rotate_prism("S")
		await create_timer(0.28).timeout
		var head: Node3D = optics.devices.S._contents
		var axis: Vector3 = head.transform.basis.x.normalized()
		var target: Vector2 = optics.model.SOURCE_TARGETS[optics.model.source_direction].normalized()
		check(Vector2(axis.x, -axis.z).dot(target) > 0.999, "starter output nozzle tracks its actual source direction")
	check(optics.devices.A._status.visibility_range_end > 0 and optics.devices.A._status.visibility_range_end <= 7.0, "hardware labels are distance-limited")
	check(optics.devices.A._turn_label.visibility_range_end > 0 and optics.devices.A._turn_label.visibility_range_end <= 3.5, "handle labels are limited to nearby controls")
	optics.queue_free()
	carry.queue_free()
	await process_frame
	print("OPTICS SCENE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
