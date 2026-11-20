extends RefCounted
## Connections between rooms: how winning one place changes another, and how things
## travel between them. All state lives in Game flags, so it saves with the game and
## anything can listen through Game.flag_changed. See docs/INTERCONNECTION.md.
##
## Two ideas:
##
## PROBLEMS are troubles a win sets off somewhere else, waiting to be noticed (the
## Futurescope shows them) and fixed (usually from yet another room). Each is active once
## its `after` minigame is won and until its `fixed_flag` is set.
##
## THE RING TRAY is where things sent from the Engineer's 1955 workshop arrive in the
## hall: the tray beside the Workshop's portal ring. It holds one item at a time, as a
## carry slot; items it accepts must be hall carry items (carry_inventory.gd ITEMS).

const TRAY_FLAG := "timelink_tray"            ## The item waiting in the ring tray, or "".
const SENT_FLAG := "timelink_sent"            ## Items ever sent from 1955 (so they aren't sent twice).

## id -> {after: minigame id that sets it off, fixed_flag: Game flag that ends it,
##        room: where it shows, title: what the Futurescope's channel calls it}
const PROBLEMS := {
	"egypt_dark": {"after": "workshop", "fixed_flag": "egypt_sun_restored", "room": "egypt",
		"title": "EGYPT · THE SUN HAS GONE OUT"},
	"fuse_loose": {"after": "workshop", "fixed_flag": "fuse_found", "room": "hall",
		"title": "THE HALL · A CAT ON THE LOOSE"},
}

## Things the workshop can send to the hall, by their workshop item id -> hall carry item.
const SENDABLE := {"flashlight": "flashlight"}


static func is_active(problem: String) -> bool:
	var p: Dictionary = PROBLEMS.get(problem, {})
	if p.is_empty():
		return false
	return Game.completed_minigames.has(p.after) and not bool(Game.get_flag(p.fixed_flag, false))


static func fix(problem: String) -> void:
	var p: Dictionary = PROBLEMS.get(problem, {})
	if not p.is_empty():
		Game.set_flag(p.fixed_flag, true)


static func active_problems() -> Array[String]:
	var out: Array[String] = []
	for id: String in PROBLEMS:
		if is_active(id):
			out.append(id)
	return out


## Sends a workshop item through the Chrono-Oscillator to the hall's ring tray.
## False if it can't go (not sendable, already sent, or the tray is occupied).
static func send_to_hall(workshop_item: String) -> bool:
	if not SENDABLE.has(workshop_item) or was_sent(workshop_item) or tray_item() != "":
		return false
	var sent: Array = Game.get_flag(SENT_FLAG, []).duplicate()
	sent.append(workshop_item)
	Game.set_flag(SENT_FLAG, sent)
	Game.set_flag(TRAY_FLAG, SENDABLE[workshop_item])
	return true


static func was_sent(workshop_item: String) -> bool:
	return workshop_item in Game.get_flag(SENT_FLAG, [])


static func tray_item() -> String:
	return str(Game.get_flag(TRAY_FLAG, ""))


static func set_tray_item(item: String) -> void:
	Game.set_flag(TRAY_FLAG, item)
