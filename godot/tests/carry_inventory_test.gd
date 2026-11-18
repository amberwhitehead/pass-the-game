extends "res://tests/test_suite.gd"
## Real item exchanges, persistence and camera cancellation/restore.

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)


func _run() -> void:
	Engine.time_scale = 10.0
	Engine.max_fps = 120
	var game: Node = root.get_node("Game")
	game.flags.clear()
	var inventory: Node = load("res://scenes/escape/carry_inventory.gd").new()
	root.add_child(inventory)
	_expect(inventory.held_item.is_empty(), "Fresh hand is empty")
	var tray: Node3D = load("res://scenes/escape/carry_slot.gd").new()
	tray.configure(inventory, "lens_yellow")
	root.add_child(tray)
	tray.interact(null)
	_expect(inventory.held_item == "lens_yellow" and tray.slot_item.is_empty(), "Pickup transfers one item into hand")
	tray.set_item("lens_blue")
	tray.interact(null)
	_expect(inventory.held_item == "lens_blue" and tray.slot_item == "lens_yellow", "Occupied tray atomically swaps colors")
	var cradle: Node3D = load("res://scenes/escape/carry_slot.gd").new()
	cradle.configure(inventory, "prism", "prism")
	root.add_child(cradle)
	cradle.interact(null)
	_expect(inventory.held_item == "lens_blue" and cradle.slot_item == "prism", "Incompatible cradle rejects exchange without losing either item")
	tray.set_item("")
	tray.interact(null)
	_expect(inventory.held_item.is_empty() and tray.slot_item == "lens_blue", "Empty tray safely parks a carried item")
	cradle.interact(null)
	_expect(inventory.held_item == "prism" and cradle.slot_item.is_empty(), "Empty hand can pick up compatible prism")
	tray.interact(null)
	_expect(inventory.held_item == "lens_blue" and tray.slot_item == "prism", "Neutral tray supports exchanging unlike item types")
	var restored_inventory: Node = load("res://scenes/escape/carry_inventory.gd").new()
	root.add_child(restored_inventory)
	_expect(restored_inventory.held_item == "lens_blue", "Hand survives rebuilding inventory from session state")
	restored_inventory.free()
	tray.set_available(false)
	var prior_item: String = inventory.held_item
	tray.interact(null)
	_expect(inventory.held_item == prior_item and tray.slot_item == "prism", "Disabled slot cannot exchange")
	tray.free()
	cradle.free()
	inventory.exchange("")
	var pedestal: Node3D = load("res://scenes/escape/reward_pedestal.gd").new()
	pedestal.configure(inventory)
	pedestal.position = Vector3(0, 0, -3)
	root.add_child(pedestal)
	_expect(not pedestal.visible and pedestal.slots.size() == 2, "Reward starts hidden with two individual cradles")
	_expect(not pedestal.slots[0].monitorable and not pedestal.slots[1].monitorable, "Hidden reward cannot be focused or taken")
	pedestal.slots[0].interact(null)
	_expect(inventory.held_item.is_empty(), "Hidden reward refuses direct interaction")
	var player: Node3D = load("res://scenes/room/player.tscn").instantiate()
	root.add_child(player)
	player.camera.rotation = Vector3(0.16, 0.23, 0.05)
	player.camera.fov = 69.0
	var saved_transform: Transform3D = player.camera.transform
	var reveal: Node = load("res://scenes/escape/reward_reveal.gd").new()
	reveal.configure(player, pedestal)
	root.add_child(reveal)
	reveal.play()
	_expect(reveal.active and player.cinematic_locked, "Reveal locks movement while camera pans")
	reveal.cancel()
	_expect(not reveal.active and not player.cinematic_locked, "Early cancellation restores movement")
	_expect(player.camera.transform.is_equal_approx(saved_transform) and is_equal_approx(player.camera.fov, 69.0), "Cancellation restores exact camera transform and FOV")
	_expect(pedestal.visible and pedestal.slots[0].monitorable, "Skipping still materializes the reward")
	pedestal.slots[0].interact(null)
	_expect(inventory.held_item == "prism" and pedestal.slots[0].slot_item.is_empty(), "First prism transfers from reward to hand")
	pedestal.reveal(false)
	_expect(pedestal.slots[0].slot_item.is_empty(), "Repeated reveal does not duplicate collected rewards")
	var restored_pedestal: Node3D = load("res://scenes/escape/reward_pedestal.gd").new()
	restored_pedestal.configure(inventory)
	root.add_child(restored_pedestal)
	restored_pedestal.reveal(false)
	_expect(restored_pedestal.slots[0].slot_item.is_empty() and restored_pedestal.slots[1].slot_item == "prism", "Reconstructed pedestal preserves collected and remaining rewards")
	restored_pedestal.free()
	reveal.play()
	for frame in 600:
		if not reveal.active:
			break
		await process_frame
	_expect(not reveal.active and not player.cinematic_locked, "Full reveal finishes without requiring dialogue input")
	_expect(player.camera.transform.is_equal_approx(saved_transform) and is_equal_approx(player.camera.fov, 69.0), "Full reveal restores exact camera transform and FOV")
	player.cinematic_locked = true
	reveal.play()
	reveal.cancel()
	_expect(player.cinematic_locked, "Reveal preserves a preexisting cinematic lock")
	player.cinematic_locked = false
	reveal.play()
	reveal.free()
	_expect(not player.cinematic_locked and player.camera.transform.is_equal_approx(saved_transform), "Removing reveal mid-animation restores camera and controls")
	pedestal.free()
	player.free()
	inventory.free()
	print("Carry/reward: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
