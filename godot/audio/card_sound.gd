extends RefCounted
## Cues follow resolved rule events; silence is intentional for UI-only renders.
const Catalog := preload("res://minigames/cards/card_catalog.gd")

static func before(table: Control, event: Dictionary) -> void:
	match String(event.type):
		"spell":
			var healing: bool = Catalog.get_card(str(event.get("card", ""))).get("kind", "") == "heal"
			Sound.play("heal" if healing else "bolt", table)
		"death":
			Sound.play("card_death", table)
		"intercept", "swap":
			Sound.play("card_draw", table, -3, .9)
		"draw":
			if not event.get("burned", false):
				Sound.play("card_draw", table)

static func after(table: Control, event: Dictionary) -> void:
	match String(event.type):
		"play", "enemy_play", "intercept", "swap":
			Sound.play("card_place", table)
		"heal":
			Sound.play("heal", table, -5)
		"fatigue":
			Sound.play("card_direct", table, -5, .8)
		"victory":
			Sound.play("victory" if event.side == "player" else "defeat", table)
