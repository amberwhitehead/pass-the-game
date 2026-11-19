extends RefCounted
## The Raider's three weapons, each with three power levels. ThunderForce-style: every
## weapon you have collected stays in your arsenal and you switch between them freely.
##   0 PULSE   twin cannon; level 2 adds a diagonal pair, level 3 a rear pair.
##   1 FAN     a widening spread: 3, 5 or 7 shots.
##   2 SEEKER  a light forward shot plus homing missiles: 1, 2 or 4 at a time.

const Entities := preload("res://minigames/arcade/entities.gd")

const PULSE := 0
const FAN := 1
const SEEKER := 2
const COOLDOWN := [5, 8, 6]


## Adds this frame's shots for `weapon` at `level` from the ship's nose `at`.
static func fire(game, weapon: int, level: int, at: Vector2, frame: int) -> void:
	match weapon:
		PULSE:
			for dy in [-3.0, 3.0]:
				game.add_shot(Entities.Shot.new(at + Vector2(0, dy), Vector2(7.5, 0), "pulse"))
			if level >= 2:
				for s in [-1.0, 1.0]:
					game.add_shot(Entities.Shot.new(at + Vector2(-4, s * 4), Vector2(6.8, s * 2.2), "pulse"))
			if level >= 3:
				for s in [-1.0, 1.0]:
					game.add_shot(Entities.Shot.new(at + Vector2(-20, s * 3), Vector2(-6.5, s * 0.4), "pulse"))
		FAN:
			var n: int = [3, 5, 7][level - 1]
			var spread := deg_to_rad(9.0)
			for i in n:
				var a := (i - (n - 1) / 2.0) * spread
				game.add_shot(Entities.Shot.new(at, Vector2(6.0, 0).rotated(a), "fan"))
		SEEKER:
			game.add_shot(Entities.Shot.new(at, Vector2(7.0, 0), "pulse"))
			if frame % 3 == 0:
				var n: int = [1, 2, 4][level - 1]
				for i in n:
					var s := 1.0 if i % 2 == 0 else -1.0
					var lift := s * (1.6 + 0.8 * (i / 2))
					game.add_shot(Entities.Shot.new(at + Vector2(-8, s * 5), Vector2(2.6, lift), "missile"))
