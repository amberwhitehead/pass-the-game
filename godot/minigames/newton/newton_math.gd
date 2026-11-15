## CPU twin of shaders/newton_fractal.gdshader, used to decide which basin (root) a
## point on the table falls into. Keep the two in sync (same iteration, tolerance, view).

const TOLERANCE := 0.0005
const VIEW_SCALE := 1.8
const MAX_ITER := 40


static func cmul(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x)


static func cdiv(a: Vector2, b: Vector2) -> Vector2:
	return cmul(a, Vector2(b.x, -b.y)) / maxf(b.dot(b), 1e-30)


static func clog(z: Vector2) -> Vector2:
	return Vector2(log(maxf(z.length(), 1e-20)), atan2(z.y, z.x))


static func cexp(z: Vector2) -> Vector2:
	return exp(clampf(z.x, -40.0, 40.0)) * Vector2(cos(z.y), sin(z.y))


## Table-local (x, z) in metres -> complex plane, same mapping as the shader.
static func to_plane(table_xz: Vector2, table_radius: float, angle: float) -> Vector2:
	return (table_xz / table_radius * VIEW_SCALE).rotated(angle)


## Returns the root this start point converges to, or null if it doesn't converge.
static func basin(table_xz: Vector2, table_radius: float, p: Vector2, relax: float, angle: float = 0.0) -> Variant:
	var z := to_plane(table_xz, table_radius, angle)
	var pm1 := p - Vector2(1, 0)
	for i in MAX_ITER:
		var zp1 := cexp(cmul(pm1, clog(z)))
		var f := cmul(zp1, z) - Vector2(1, 0)
		var dz := relax * cdiv(f, cmul(p, zp1))
		z -= dz
		if dz.length() < TOLERANCE:
			return z
		if z.dot(z) > 1e8:
			return null
	return null


# --- colours --------------------------------------------------------------------------
# A root's colour comes from its angle on a wheel with three key colours (cyan, yellow,
# magenta). Keep in sync with palette() in the shader.

const KEYS: Array[Color] = [Color(0.20, 0.85, 0.95), Color(1.0, 0.85, 0.25), Color(0.92, 0.28, 0.72)]


static func wheel_pos(root: Vector2) -> float:
	return fposmod(root.angle() / TAU, 1.0) * 3.0


## Which key colour (0 cyan, 1 yellow, 2 magenta) a root is closest to.
static func color_class(root: Vector2) -> int:
	return int(round(wheel_pos(root))) % 3


## discrete = exactly the three key colours; otherwise blend continuously around the wheel.
static func palette(root: Vector2, discrete: bool = true) -> Color:
	if discrete:
		return KEYS[color_class(root)]
	var x := wheel_pos(root)
	var i := int(floor(x))
	return KEYS[i % 3].lerp(KEYS[(i + 1) % 3], smoothstep(0.3, 0.7, x - i))
