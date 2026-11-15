class_name FakeResults
extends RefCounted
## Dev helper: plausible "won" results, so the win visuals can be checked without solving the puzzles.

static func newton() -> Dictionary:
	return {"won": true, "pyramids": [
		{"pos": Vector2(0.72, 1.44), "r": 0.38, "color": Color(0.1, 0.9, 0.95)},
		{"pos": Vector2(0.66, 0.19), "r": 0.34, "color": Color(1.0, 0.85, 0.1)},
		{"pos": Vector2(0.61, -0.87), "r": 0.17, "color": Color(1.0, 0.2, 0.7)}]}


## A winding teal-path-like route from (-1.5, 0) to (1.5, 0), as solver grid cells (n x n) for the game.
static func turing_cells(n := 128, table_r := 2.2) -> PackedInt32Array:
	var cells := PackedInt32Array()
	var steps := 160
	for i in steps + 1:
		var t := float(i) / steps
		var x := lerpf(-1.5, 1.5, t)
		var z := 0.35 * sin(t * TAU * 1.25) + 0.12 * sin(t * TAU * 3.0)
		var cx := clampi(int((x / (2.0 * table_r) + 0.5) * n), 0, n - 1)
		var cy := clampi(int((z / (2.0 * table_r) + 0.5) * n), 0, n - 1)
		var c := cy * n + cx
		if cells.is_empty() or cells[cells.size() - 1] != c:
			cells.append(c)
	return cells


static func turing() -> Dictionary:
	return {"won": true, "route": RomanAqueduct.route_from_cells(turing_cells(), 128, 2.2)}
