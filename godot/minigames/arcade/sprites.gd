extends RefCounted
## CHRONO RAIDER's pixel art, as ASCII (palette in pixel_art.gd). Rows of a sprite must all
## be the same length. Things that rotate (gears, the boss's clock hands) are drawn from
## shapes in code instead.

const Pix := preload("res://minigames/arcade/pixel_art.gd")

## The Raider: the player's ship, nose to the right.
const SHIP := [
	"....kkk.................",
	"...kBbbk................",
	"...kBbblkk..............",
	"..kGgggglllkkkk.........",
	".kGgggggccCgggggkkk.....",
	"kGGgggcCwwcCggggggglkk..",
	"kGGgggcCwwcCgggggggglllk",
	".kGgggggccCgggggggkkkkk.",
	"..kGGGGGGGGGGGkkkk......",
	"...kBbblkk..............",
	"...kBbbk................",
	"....kkk.................",
]

const FLAME := [
	"..oy",
	"ooyw",
	"..oy",
]

## Tick: a small clockwork drone that weaves in a sine wave.
const TICK := [
	"...kkkkk....",
	"..kYyyyYk...",
	".kYwwwwwYk..",
	"kYwwwkwwwYk.",
	"kYwwwkwwwYkk",
	"kYwwwkkkwYkr",
	"kYwwwwwwwYkk",
	".kYwwwwwYk..",
	"..kYyyyYk...",
	"...kkkkk....",
]

## Hourglass mine: drifts, and bursts into sand when shot or when its time runs out.
const HOURGLASS := [
	"kkkkkkkkkk",
	"kYYYYYYYYk",
	".kssssssk.",
	".ksssssSk.",
	"..ksssSk..",
	"...kSSk...",
	"....kk....",
	"...k.sk...",
	"..k..ssk..",
	".k..sssSk.",
	".k.ssssSk.",
	"kYYYYYYYYk",
	"kkkkkkkkkk",
]

## Patrol gunship: the Officer's temporal patrol. Swoops in, aims, leaves.
const GUNSHIP := [
	"..........kkkkkk............",
	"........kkGgggggkk..........",
	".....kkkGggrrrrggGkk........",
	"..kkkGGgggrRwwRrgggGkkk.....",
	"kkrrrGgggggrrrrgggggggGkkk..",
	"kRrrrGggggggggggggggggggGGkk",
	"kkrrrGGGGGGGGGGGGGGGGGGGkk..",
	"..kkkkGGGkkkkkkkkGGGkkkk....",
	".....kYYk.......kYYk........",
	"......kk.........kk.........",
]

## Courier: a carrier that drops a weapon capsule when destroyed.
const COURIER := [
	"......kkkkkkkk........",
	"....kkpppppppPkk......",
	"..kkpPPPPPPPPPPpkk....",
	".kpPPnnnnnnnnnnPPpk...",
	"kpPPnNkkkkkkkkNnPPpkk.",
	"kpPPnNkyyyyyykNnPPppkk",
	"kpPPnNkkkkkkkkNnPPpkk.",
	".kpPPnnnnnnnnnnPPpk...",
	"..kkpPPPPPPPPPPpkk....",
	"....kkpppppppPkk......",
	"......kkkkkkkk........",
]

const LIFE := [
	".kk....",
	"kBlkkk.",
	"kgccggk",
	"kBlkkk.",
	".kk....",
]


static func tex(name: String) -> ImageTexture:
	return Pix.tex(name, _rows(name))


static func flash(name: String) -> ImageTexture:
	return Pix.flash(name, _rows(name))


static func _rows(name: String) -> Array:
	match name:
		"ship": return SHIP
		"flame": return FLAME
		"tick": return TICK
		"hourglass": return HOURGLASS
		"gunship": return GUNSHIP
		"courier": return COURIER
		"life": return LIFE
	push_error("No sprite " + name)
	return ["k"]
