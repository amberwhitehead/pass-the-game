extends RefCounted
## Encounter copy stays separate from selection, animation, and match state.
const Encounter := preload("res://minigames/cards/match_encounter.gd")
const CARD_HINTS := {
	"champion": "Try the servers beside our doorway. I may have left something there.",
	"aegis": "There is a service shelf along the wall near the hall entrance. Very easy to overlook.",
	"tempest": "The Memory Bank beside the pyramid room has more than memories in it.",
	"renewal": "Look between the Workshop and Calendar doorways. Check the server rack.",
	"thunderbolt": "Something bright was tucked into the Chronology rack, beneath the hall sign.",
}

static func opening(older: bool, found_count := 0) -> String:
	if not older:
		return "LITTLE BROTHER: I have been practicing. For at least several minutes."
	if found_count == 0:
		return "OLDER BROTHER: That deck? Against me? You might want to look around the hall first."
	if found_count < 5:
		return "OLDER BROTHER: %d of my missing cards. I was wondering where those went." % found_count
	return "OLDER BROTHER: All five? Those were supposed to be difficult to find."

static func rules(older: bool, settings: Dictionary = {}, collected: Array = []) -> String:
	if older:
		var tuning := Encounter.settings("older_brother") if settings.is_empty() else settings
		var progression := "%d / 5 cards found in the hall. Your deck has %d cards." % [collected.size(), tuning.deck.size()]
		if collected.is_empty():
			progression += " His deck is much stronger than your starting deck. Explore the hall for cards, then return for a rematch."
		else:
			progression += " Found cards are shuffled into your deck. They may appear in your opening hand or in later draws."
		progression += " Every deal starts with five cards: Bruiser, Forkshot, Sentinel, and two random draws. Finding cards increases your deck size, not your opening hand."
		var steps: PackedStringArray = []
		for value in range(int(tuning.starting_attention), int(tuning.attention_cap) + 1):
			steps.append(str(value))
		return "Push the balance to +%d to win. He wins at −%d. Four lanes, persistent wounds, and a finite reserve on both sides. His opening creatures are already on the table.\n\n%s\n\nSpend Attention to play cards. It refills each turn: %s. Draw one card per new turn.\n\nINTERCEPT: before a creature hits an empty adjacent lane, an interceptor moves there and blocks. Once per enemy combat phase; if two can react, the leftmost goes first. The shield shows READY or SPENT. Spells do not trigger interception.\n\nDIAGONAL: attacks the two diagonally opposite lanes, left then right, for its printed attack each. It never attacks straight ahead. At the edge it has only one target. Hover a creature to inspect its paths.\n\nSWITCHEROO: choose a friendly creature, then an occupied adjacent friendly lane. They swap places for 1 Attention. Click the first creature again to cancel.\n\nYour creatures attack left to right, then he deploys in the glowing lane and attacks. His incoming card stays hidden. An empty lane sends damage to the balance; a blocker takes the whole hit.\n\nEmpty draws cause increasing fatigue; his reserve is shown on the table. Hand limit: 8.\n\nMove to the bottom edge to raise your hand. Select a card, then its target. Ring the bell to attack. Esc cancels a pending swap, closes a panel, or leaves the table." % [tuning.goal, tuning.goal, progression, " → ".join(steps)]
	return "Win by pushing the score to +10. He wins at −10.\n\nSpend Attention to play cards: select a card, then click a lane. Units need an empty friendly lane. Bolt targets an enemy; Patch heals a wounded ally.\n\nEnd turn: your creatures attack left to right. A blocker takes the whole hit; an empty lane sends damage to the score. New creatures attack immediately.\n\nThen he plays into the glowing enemy lane and attacks. The glow marks his destination; his card stays hidden until played. You draw one card and refill Attention (2 → 3 → 4). Cards in play keep their wounds. Medic heals other allies by 1 when played.\n\nYour deck has 16 cards. If it runs out, missed draws cause increasing fatigue damage. Hand limit: 8.\n\nMove to the bottom edge to raise your hand (tap there on touch). Select a card to lower the hand, then click its target. Hover to inspect. Ring the brass bell to end your turn. Esc leaves the table."

static func result(older: bool, won: bool, collected: Array = []) -> String:
	if older:
		if won:
			return "With your starting deck? ...I am going to need a moment.\n\nYou have earned a seat at this table. My little brother is never hearing about this." if collected.is_empty() else "So THAT is where my cards went.\n\nFine. You have earned a seat at this table. My little brother is never hearing about this."
		if collected.size() < 5:
			var clue := ""
			for id: String in CARD_HINTS:
				if id not in collected:
					clue = CARD_HINTS[id]
					break
			return "Your cards need a little help. Mine certainly did.\n\n%s\n\n%d / 5 cards found. Anything you find in the hall joins your deck when we play again." % [clue, collected.size()]
		return "You have all five. Now make them work together.\n\nPut diagonal attackers in the middle, keep an opening beside an interceptor, and use your stronger spells before combat. I'll deal again when you're ready."
	return "NYA HA HA! A practice victory! Against a practice opponent!\n\nYou'll never defeat my older brother. He has an EPIC card. Found it just lying around, too.\n\nHe's waiting beside my table. Four lanes. Very serious." if won else "A victory! For ME! I knew those practice minutes would pay off.\n\nTry blocking his strongest lane and using Bolt before combat. Your own open lanes push the score back."

static func banter(older: bool, state: Dictionary) -> String:
	if older:
		if state.balance >= 5:
			return "OLDER BROTHER: Those openings were intentional. Allegedly."
		if state.turn == 2:
			return "OLDER BROTHER: Watch the spaces between the cards. That is where games are won."
	else:
		if state.turn == 2:
			return "LITTLE BROTHER: Those were my introductory moves. The real moves are coming."
		if state.balance >= 4:
			return "LITTLE BROTHER: I was going to put a creature in that lane. Eventually."
	return ""
