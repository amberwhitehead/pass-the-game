extends RefCounted
## Stage 1, "UPSTREAM 1963": the spawn timeline. Each entry is [frame, kind, y, count,
## spacing (frames), param]. The boss arrives at BOSS_AT. Edit freely in a design pass.

const BOSS_AT := 4200

const TIMELINE := [
	[60, "tick", 60, 5, 14, 0.0],
	[220, "tick", 150, 5, 14, 1.5],
	[400, "courier", 108, 1, 0, 0.0],
	[520, "tick", 40, 4, 12, 0.0],
	[540, "tick", 176, 4, 12, 3.0],
	[700, "hourglass", 70, 3, 40, 0.0],
	[760, "hourglass", 150, 3, 40, 1.0],
	[900, "gunship", 60, 1, 0, 0.0],
	[960, "gunship", 160, 1, 0, 1.0],
	[1150, "tick", 108, 8, 10, 0.0],
	[1300, "courier", 60, 1, 0, 0.0],
	[1400, "gear", 108, 1, 0, 0.0],
	[1500, "tick", 40, 6, 12, 0.0],
	[1620, "tick", 176, 6, 12, 2.0],
	[1800, "hourglass", 40, 5, 26, 0.0],
	[1830, "hourglass", 176, 5, 26, 2.0],
	[2000, "gunship", 50, 1, 0, 0.0],
	[2040, "gunship", 108, 1, 0, 1.0],
	[2080, "gunship", 170, 1, 0, 2.0],
	[2300, "courier", 150, 1, 0, 0.0],
	[2400, "gear", 60, 1, 0, 0.0],
	[2460, "gear", 160, 1, 0, 0.0],
	[2650, "tick", 108, 10, 8, 0.0],
	[2800, "tick", 60, 6, 10, 1.0],
	[2800, "tick", 160, 6, 10, 2.0],
	[3000, "courier", 100, 1, 0, 0.0],
	[3100, "hourglass", 108, 6, 20, 0.0],
	[3300, "gunship", 70, 1, 0, 0.0],
	[3320, "gunship", 150, 1, 0, 1.0],
	[3500, "gear", 108, 1, 0, 0.0],
	[3600, "tick", 40, 8, 10, 0.0],
	[3650, "tick", 176, 8, 10, 1.0],
]


## The spawns due at `frame`: [kind, Vector2 position, param].
static func spawns_at(frame: int) -> Array:
	var out := []
	for e in TIMELINE:
		var start: int = e[0]
		var count: int = e[3]
		var spacing: int = e[4]
		for i in count:
			if start + i * spacing == frame:
				out.append([e[1], Vector2(400, float(e[2])), float(e[5]) + i * 0.6])
	return out


## The year on the HUD: the Raider climbs the timestream from 1963 toward 1985.
static func year(frame: int) -> int:
	return 1963 + int(clampf(float(frame) / BOSS_AT, 0.0, 1.0) * 22.0)
