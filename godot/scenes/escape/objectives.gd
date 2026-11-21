extends RefCounted
## What the player should do next in the hall, worked out from the save's flags: a
## chapter title, a sentence, and which place it is about. The objective console shows
## it and points its laser at the place (room.gd turns the place into a position).
##
## Places: "egypt" (the amber room's station), "prisms" (the reward pedestal),
## "receiver" (the green receiver beside Room 2), "roman" (Roman Flow's station).

static func current() -> Dictionary:
	if Game.get_flag("escape_prism_solved"):
		return {"chapter": "02  /  Roman flow", "text": "The green receiver has opened the east room.", "place": "roman"}
	if Game.get_flag("escape_rewards_revealed"):
		var rewards: Array = Game.get_flag("escape_reward_items", [])
		var remaining := rewards.count("prism")
		if remaining > 0:
			return {"chapter": "The light in the hall",
				"text": "%d prism%s await%s in Egypt. Bring green light to Room 2." % [remaining, "s" if remaining > 1 else "", "" if remaining > 1 else "s"],
				"place": "prisms"}
		return {"chapter": "The light in the hall", "text": "Bring green light to the receiver beside Room 2.", "place": "receiver"}
	return {"chapter": "01  /  Egypt fractal", "text": "Start in the amber room. The hall is missing its prisms.", "place": "egypt"}


## Flags that can change the objective.
const FLAGS := ["escape_rewards_revealed", "escape_reward_items", "escape_prism_solved"]
