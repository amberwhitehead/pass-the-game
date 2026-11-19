extends Node
## A single hand, with atomic exchange. World slots own all unheld items.

signal changed(item: String)

## "flashlight" arrives from 1955 through the Workshop's ring (autoload/time_link.gd).
const ITEMS := ["", "prism", "lens_yellow", "lens_blue", "flashlight"]
var held_item := ""


func _ready() -> void:
	var saved: String = str(Game.get_flag("escape_held_item", ""))
	if ITEMS.has(saved):
		held_item = saved
	changed.emit(held_item)


func exchange(slot_item: String) -> String:
	if not ITEMS.has(slot_item):
		push_warning("Cannot carry unknown item: " + slot_item)
		return slot_item
	var previous := held_item
	held_item = slot_item
	Game.set_flag("escape_held_item", held_item)
	changed.emit(held_item)
	return previous


static func item_name(item: String) -> String:
	match item:
		"prism": return "Prism"
		"lens_yellow": return "Yellow lens"
		"lens_blue": return "Blue lens"
		"flashlight": return "1955 flashlight"
	return "Empty hand"
