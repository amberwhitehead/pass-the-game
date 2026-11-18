extends "res://tests/test_suite.gd"

const Model := preload("res://scenes/escape/optics_model.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	var model := Model.new()
	var initial: Dictionary = model.trace()
	check(initial.hit == "receiver" and initial.color == 1 and not initial.won, "initial direct shot is yellow")
	model.source_direction = 1
	model.items.J = ""
	model.items.L = "lens_yellow"
	check(model.trace().color == 3, "green can be discovered before earning prisms")
	model.items.C = "prism"
	model.items.D = "prism"
	model.turns.D = 1
	check(model.trace().hit == "obstacle", "far socket route hits central obstacle")
	model.items.C = ""
	model.items.D = ""
	model.items.A = "prism"
	model.items.B = "prism"
	model.turns.B = 1
	check(model.trace().hit == "receiver" and model.trace().color == 1, "early turn bypasses blue lens")
	model.items.K = ""
	model.items.M = "lens_blue"
	check(model.trace().won, "A/B route solves with moved lenses and empty D")
	model.items.L = "lens_blue"
	model.items.M = "lens_yellow"
	check(model.trace().won, "lens order is interchangeable")
	var copy := Model.new()
	copy.restore(model.save_state())
	check(copy.trace().won, "saved arrangement restores")
	check(not model.accepts("A", "lens_blue") and not model.accepts("L", "prism"), "incompatible items rejected")
	check(model.accepts("A", "") and model.accepts("L", ""), "empty hands may take any mounted item")
	_exhaustive()
	print("OPTICS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _exhaustive() -> void:
	var all_slots: Array = ["", "A", "B", "C", "D"]
	var all_mounts: Array = ["", "J", "K", "L", "M"]
	var winning_states := 0
	var tested := 0
	var source_angles := Model.new().source_snap_angles()
	for first: String in all_slots:
		for second: String in all_slots:
			# Unordered unique placements, including inventory for missing prisms.
			if second < first or (first == second and not first.is_empty()):
				continue
			for yellow: String in all_mounts:
				for blue: String in all_mounts:
					if yellow == blue and not yellow.is_empty():
						continue
					for source in source_angles.size():
						for first_turn in [-1, 1]:
							if first.is_empty() and first_turn == 1:
								continue
							for second_turn in [-1, 1]:
								if second.is_empty() and second_turn == 1:
									continue
								var model := Model.new()
								for id: String in model.items:
									model.items[id] = ""
								if not first.is_empty():
									model.items[first] = "prism"
									model.turns[first] = first_turn
								if not second.is_empty():
									model.items[second] = "prism"
									model.turns[second] = second_turn
								if not yellow.is_empty():
									model.items[yellow] = "lens_yellow"
								if not blue.is_empty():
									model.items[blue] = "lens_blue"
								model.source_angle = source_angles[source]
								tested += 1
								if model.trace().won:
									winning_states += 1
									check(first == "A" and second == "B" and source == 1 and yellow in ["L", "M"] and blue in ["L", "M"], "no bypass in winning arrangement")
	check(winning_states == 2, "exactly two winning configurations across all placements and rotations")
	print("Enumerated %d optical states; %d solutions." % [tested, winning_states])


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
