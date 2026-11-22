extends RefCounted
## Pure logic for the Aetheric Sigil Press: sigil definitions, attractor point clouds,
## target parameters, and cleanliness checks. No nodes, no scenes.

const SIGIL_COUNT := 5
const LAYERS := 4

# Each sigil: id, card id, target params (az, el, focus, valve1, valve2), and a point-cloud shape.
const SIGILS := [
	{"id": "focus", "card": "sigil_focus", "name": "The Lantern",
		"az": 0.6, "el": 0.3, "focus": 0.9, "v1": 0.6, "v2": 0.4, "shape": 0},
	{"id": "flow", "card": "sigil_flow", "name": "The Coil",
		"az": -0.9, "el": 0.5, "focus": 0.85, "v1": 0.3, "v2": 0.7, "shape": 1},
	{"id": "aether", "card": "sigil_aether", "name": "The Weave",
		"az": 1.4, "el": -0.4, "focus": 0.9, "v1": 0.8, "v2": 0.2, "shape": 2},
	{"id": "resonance", "card": "sigil_resonance", "name": "The Bell",
		"az": -1.6, "el": -0.2, "focus": 0.85, "v1": 0.5, "v2": 0.5, "shape": 3},
	{"id": "void", "card": "sigil_void", "name": "The Hollow",
		"az": 0.0, "el": 0.8, "focus": 0.95, "v1": 0.2, "v2": 0.9, "shape": 4},
]


static func sigil(i: int) -> Dictionary:
	return SIGILS[clampi(i, 0, SIGIL_COUNT - 1)]


# Generate a point cloud (Array of Vector3) for a sigil shape. Centered at origin, radius ~1.
static func attractor_points(shape: int, count: int = 600) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345 + shape * 997
	match shape:
		0: # spiral (open enough to read as a shape)
			for n in count:
				var t := float(n) / float(count) * TAU * 3.0
				var r := 0.15 + (float(n) / float(count)) * 0.85
				pts.append(Vector3(cos(t) * r, sin(t * 0.5) * 0.25, sin(t) * r))
		1: # rosette
			for n in count:
				var t := float(n) / float(count) * TAU * 5.0
				var r := 0.9 * (0.5 + 0.5 * cos(3.0 * t))
				pts.append(Vector3(cos(t) * r, cos(t * 2.0) * 0.2, sin(t) * r))
		2: # knot (trefoil-ish)
			for n in count:
				var t := float(n) / float(count) * TAU * 2.0
				pts.append(Vector3(
					sin(t) + 2.0 * sin(2.0 * t),
					cos(t) - 2.0 * cos(2.0 * t),
					- sin(3.0 * t)) * 0.35)
		3: # double helix
			for n in count:
				var t := float(n) / float(count) * TAU * 4.0
				var s := 1.0 if (n % 2 == 0) else -1.0
				pts.append(Vector3(cos(t) * 0.7, (float(n) / float(count) - 0.5) * 1.6, sin(t) * 0.7 + s * 0.15))
		4: # void: ring with void center
			for n in count:
				var t := float(n) / float(count) * TAU
				var r := 0.85 + rng.randf() * 0.1
				pts.append(Vector3(cos(t) * r, (rng.randf() - 0.5) * 0.15, sin(t) * r))
		_:
			for n in count:
				pts.append(Vector3.ZERO)
	return pts


static func resolved(az: float, el: float, focus: float, s: Dictionary) -> bool:
	return abs(az - s.az) < 0.12 and abs(el - s.el) < 0.12 and focus > s.focus - 0.1


static func layer_clean(v1: float, v2: float, s: Dictionary) -> bool:
	return abs(v1 - s.v1) < 0.12 and abs(v2 - s.v2) < 0.12


static func all_clean(plate: Array) -> bool:
	if plate.is_empty():
		return false
	for c in plate:
		if not bool(c):
			return false
	return true
