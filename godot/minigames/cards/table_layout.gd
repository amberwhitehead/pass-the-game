extends RefCounted
## Shared physical coordinates for either brother's board and its ornaments.
const SPACING := 1.25
const DESKTOP_ASPECT := 16.0 / 9.0

static func camera_fov(count: int, view_size: Vector2) -> float:
	var base := 48.0 if count == 4 else 44.0
	var aspect := maxf(1.0, view_size.x) / maxf(1.0, view_size.y)
	# Preserve the desktop horizontal field on narrow windows. The camera keeps
	# vertical FOV, and the physical hand uses that same projection for its width.
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(base) * .5) * maxf(1.0, DESKTOP_ASPECT / aspect)))

static func lane_x(lane: int, count: int) -> float:
	return (lane - (count - 1) * .5) * SPACING

static func lane_position(side: String, lane: int, count: int) -> Vector3:
	return Vector3(lane_x(lane, count), .035, -.95 if side == "enemy" else .55)

static func side_extension(count: int) -> float:
	return maxf(0, count - 3) * SPACING * .5
