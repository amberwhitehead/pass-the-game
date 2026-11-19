extends RefCounted
## Everything said in the Workshop, in one place for easy rewriting.
##
## The Workshop is a game of looking and poking, not of being told: the Engineer speaks
## at story beats and otherwise mostly mutters. The Officer explains nothing.

const INTRO := [
	"Oh! A visitor. Mind the cat.",
	"My Futurescope's been dark all week. A man likes to know what's coming.",
]

const TUBE := "The radio's tube! Why didn't I think of that?"

const UNWOUND := "That's my yarn. From... later?"

const WIRED := "Copper wire across a fuse socket. My father would be appalled. Brilliant."

const REJECTED := "It spat him out! Something's not the same."

const AFTER_VISION := [
	"Was... was that Fuse? Wearing a sardine lid?",
]

const OFFICER_ARRIVES := [
	"Well, well. A cat. Two of them, in fact. Rookies.",
	"This timeline is now scheduled for deletion. I'd say it was nice knowing you, but I have standards.",
]

const AFTER_OFFICER := [
	"...Deletion?",
]

const LID := "There it is! The lid, right on his ear."

const LOOP_CLOSED := "He went! And the clock's ticking again!"

const CASCADE := [
	"Oh no. He liked it.",
]

const FINALE := [
	"Huh. You look older, Fuse. Same lid, though.",
]

const OFFICER_LEAVES := [
	"Hm. One cat. One timeline. Beginner's luck.",
	"Deletion postponed. Don't get comfortable.",
]

const GOODBYE := "Come back any time. Bring sardines."

## Visiting again after the Workshop is won (story.gd epilogue).
const EPILOGUE := [
	"Back again! Fuse wandered off through the ring. Toward your century, I'd guess.",
	"And the Futurescope's been picking up other channels ever since. Strange ones.",
]

const SENT := "Off it goes. Mind how it lands."

## What the Engineer mutters when clicked, by phase. Never instructions.
const MUTTERS := {
	"setup": [
		"Don't mind me. Just inventing.",
		"Nobody respects a slide rule anymore.",
		"Fuse sleeps eighteen hours a day. I'm told that's normal.",
	],
	"loop": [
		"Deletion. He said deletion.",
		"Two cats. I only bought food for one.",
		"I'm not panicking. This is my thinking face.",
	],
	"break": [
		"He's got that look again.",
		"Don't let him near that lever.",
	],
	"epilogue": [
		"I keep the wire handy now. In case anything needs sending.",
		"Fuse sends postcards. Well. Hair.",
		"I wonder what's on the other channels.",
	],
	"done": [
		"Same cat. Older. Wiser? No.",
		"I may take up knitting full time.",
	],
}


static func mutter(phase: String, n: int) -> String:
	var pool: Array = MUTTERS.get(phase, MUTTERS.done)
	return pool[n % pool.size()]
