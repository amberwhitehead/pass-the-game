extends RefCounted
## Discoveries join the shuffled pool; opening size stays fixed as the deck grows.
const Catalog := preload("res://minigames/cards/card_catalog.gd")
const COLLECTIBLES: Array[String] = ["champion", "aegis", "tempest", "renewal", "thunderbolt"]
## Rewards from revisiting rooms (see docs/INTERCONNECTION.md). They join the deck like
## the hall's discoveries but aren't counted among "N / 5 found in the hall".
const BONUS: Array[String] = ["fuse", "scarab"]
const CORE_HAND: Array[String] = ["bruiser", "forkshot", "sentinel"]
const OPENING_HAND := 5


static func owned(found_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for id in COLLECTIBLES:
		if id in found_ids:
			result.append(id)
	return result


static func bonus(found_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for id in BONUS:
		if id in found_ids:
			result.append(id)
	return result


## Every card that can be collected: the hall's discoveries and revisit rewards.
static func all_collectible() -> Array[String]:
	var result: Array[String] = COLLECTIBLES.duplicate()
	result.append_array(BONUS)
	return result


static func build(found_ids: Array) -> Array[String]:
	var deck := Catalog.older_deck()
	deck.append_array(owned(found_ids))
	deck.append_array(bonus(found_ids))
	return deck
