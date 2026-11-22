extends RefCounted
## Generic playtest cards. Rules reference IDs; art and names can change independently.

const CARDS := {
	"scout": {"id": "scout", "name": "Scout", "cost": 1, "power": 1, "health": 2,
		"kind": "unit", "ability": "", "description": "A cheap creature. Attacks for 1 each turn."},
	"striker": {"id": "striker", "name": "Striker", "cost": 2, "power": 2, "health": 2,
		"kind": "unit", "ability": "", "description": "Hits hard, but needs protection."},
	"guard": {"id": "guard", "name": "Guard", "cost": 1, "power": 0, "health": 5,
		"kind": "unit", "ability": "", "description": "Blocks a lane. Cannot attack."},
	"heavy": {"id": "heavy", "name": "Heavy", "cost": 3, "power": 3, "health": 4,
		"kind": "unit", "ability": "", "description": "A sturdy attacker. Costs 3 Attention."},
	"medic": {"id": "medic", "name": "Medic", "cost": 2, "power": 1, "health": 3,
		"kind": "unit", "ability": "heal_allies", "description": "On play: heal every other ally for 1."},
	"bolt": {"id": "bolt", "name": "Bolt", "cost": 1, "power": 0, "health": 0,
		"kind": "damage", "ability": "", "description": "Deal 2 damage to one enemy creature."},
	"patch": {"id": "patch", "name": "Patch", "cost": 1, "power": 0, "health": 0,
		"kind": "heal", "ability": "", "description": "Restore 2 health to one injured ally."},
	"bruiser": {"id": "bruiser", "name": "Bruiser", "cost": 2, "power": 2, "health": 6,
		"kind": "unit", "ability": "", "description": "A sturdy fighter. Keeps damage between turns."},
	"defender": {"id": "defender", "name": "Defender", "cost": 3, "power": 1, "health": 8,
		"kind": "unit", "ability": "", "description": "Holds a lane and wears its opponent down."},
	"sentinel": {"id": "sentinel", "name": "Sentinel", "cost": 2, "power": 0, "health": 8,
		"kind": "unit", "ability": "intercept", "description": "Intercepts one hit in an empty adjacent lane each combat."},
	"forkshot": {"id": "forkshot", "name": "Forkshot", "cost": 3, "power": 1, "health": 6,
		"kind": "unit", "ability": "diagonal", "description": "Attacks both diagonal lanes. Never straight ahead."},
	"switcheroo": {"id": "switcheroo", "name": "Switcheroo", "cost": 1, "power": 0, "health": 0,
		"kind": "swap", "ability": "", "description": "Swap two adjacent friendly creatures."},
	"champion": {"id": "champion", "name": "Champion", "cost": 2, "power": 2, "health": 10,
		"kind": "unit", "ability": "", "collectible": true, "description": "A relentless fighter. Keeps damage between turns."},
	"aegis": {"id": "aegis", "name": "Aegis", "cost": 2, "power": 1, "health": 10,
		"kind": "unit", "ability": "intercept", "collectible": true, "description": "Intercepts one hit in an empty adjacent lane each combat."},
	"tempest": {"id": "tempest", "name": "Tempest", "cost": 2, "power": 1, "health": 10,
		"kind": "unit", "ability": "diagonal", "collectible": true, "description": "Attacks both diagonal lanes. Never straight ahead."},
	"renewal": {"id": "renewal", "name": "Renewal", "cost": 1, "power": 0, "health": 0,
		"kind": "heal", "ability": "", "amount": 4, "collectible": true, "description": "Restore 4 health to one injured ally."},
	"thunderbolt": {"id": "thunderbolt", "name": "Thunderbolt", "cost": 1, "power": 0, "health": 0,
		"kind": "damage", "ability": "", "amount": 4, "collectible": true, "description": "Deal 4 damage to one enemy creature."},
	"fuse": {"id": "fuse", "name": "Fuse", "cost": 1, "power": 1, "health": 6,
		"kind": "unit", "ability": "diagonal", "collectible": true, "description": "A ginger cat from 1955. Pounces on both diagonal lanes."},
	"scarab": {"id": "scarab", "name": "Sun Scarab", "cost": 1, "power": 0, "health": 0,
		"kind": "heal", "ability": "", "amount": 6, "collectible": true, "description": "The Egyptian's thanks. Restore 6 health to one injured ally."},
	"sigil_focus": {"id": "sigil_focus", "name": "Sigil of Focus", "cost": 2, "power": 2, "health": 4,
		"kind": "unit", "ability": "", "collectible": true, "description": "A focused mind. Attacks for 2 each turn."},
	"sigil_flow": {"id": "sigil_flow", "name": "Sigil of Flow", "cost": 1, "power": 0, "health": 0,
		"kind": "swap", "ability": "", "collectible": true, "description": "Swap two adjacent friendly creatures."},
	"sigil_aether": {"id": "sigil_aether", "name": "Sigil of Aether", "cost": 2, "power": 1, "health": 6,
		"kind": "unit", "ability": "intercept", "collectible": true, "description": "Intercepts one hit in an empty adjacent lane each combat."},
	"sigil_resonance": {"id": "sigil_resonance", "name": "Sigil of Resonance", "cost": 2, "power": 0, "health": 0,
		"kind": "damage", "ability": "", "amount": 3, "collectible": true, "description": "Deal 3 damage to one enemy creature."},
	"sigil_void": {"id": "sigil_void", "name": "Sigil of the Void", "cost": 3, "power": 3, "health": 3,
		"kind": "unit", "ability": "diagonal", "collectible": true, "description": "Attacks both diagonal lanes. Never straight ahead."},
	"veteran": {"id": "veteran", "name": "Veteran", "cost": 2, "power": 3, "health": 8,
		"kind": "unit", "ability": "", "description": "A seasoned fighter from the older brother's reserve."},
	"bulwark": {"id": "bulwark", "name": "Bulwark", "cost": 3, "power": 2, "health": 10,
		"kind": "unit", "ability": "", "description": "Holds its lane and hits back hard on its own turn."},
	"crossbow": {"id": "crossbow", "name": "Crossbow", "cost": 3, "power": 2, "health": 8,
		"kind": "unit", "ability": "diagonal", "description": "Attacks both diagonal lanes. Never straight ahead."},
	"sentry": {"id": "sentry", "name": "Sentry", "cost": 2, "power": 0, "health": 10,
		"kind": "unit", "ability": "intercept", "description": "Intercepts one hit in an empty adjacent lane each combat."},
}


static func get_card(id: String) -> Dictionary:
	return CARDS.get(id, {}).duplicate(true)


static func starter_deck() -> Array[String]:
	# The first four form the teaching hand; only the remaining twelve are shuffled.
	return ["scout", "striker", "guard", "bolt", "scout", "scout", "striker", "striker",
		"guard", "heavy", "heavy", "medic", "medic", "bolt", "patch", "patch"]


static func older_deck() -> Array[String]:
	# Twelve cards: three reliable creatures, then nine cards for the shuffled pool.
	return ["bruiser", "forkshot", "sentinel", "bruiser", "bruiser", "forkshot",
		"defender", "bolt", "bolt", "patch", "patch", "switcheroo"]
