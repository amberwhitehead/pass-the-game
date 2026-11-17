extends RefCounted
## Discoveries join the shuffled pool; opening size stays fixed as the deck grows.
const Catalog := preload("res://minigames/cards/card_catalog.gd")
const COLLECTIBLES: Array[String] = ["champion", "aegis", "tempest", "renewal", "thunderbolt"]
const CORE_HAND: Array[String] = ["bruiser", "forkshot", "sentinel"]
const OPENING_HAND := 5


static func owned(found_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for id in COLLECTIBLES:
		if id in found_ids:
			result.append(id)
	return result


static func build(found_ids: Array) -> Array[String]:
	var found := owned(found_ids)
	var deck := Catalog.older_deck()
	deck.append_array(found)
	return deck
