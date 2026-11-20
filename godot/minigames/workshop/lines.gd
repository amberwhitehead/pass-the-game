extends RefCounted
## Everything said in the Workshop, in one place for easy rewriting.
##
## The Workshop is a game of looking and poking, not of being told: the Engineer talks
## about himself, his things and his cat, gets steadily more put out as you rummage, and
## only nudges when you're nearly there. The Officer explains nothing.

# --- the Engineer arriving ------------------------------------------------------------

## The very first visit: he wanders in after you and can't stop talking about his TV.
const KICKOFF := [
	"Oh! A visitor. In my workshop. Touching nothing, I hope. Mind the cat; he's asleep. He's always asleep.",
	"You'll have come to see the Futurescope. Everyone does. It shows what's coming! Tomorrow's weather. Next week's ball scores. Whether a soufflé will rise.",
	"Showed. Past tense. It went dark last Tuesday, and nobody makes the tube it needs. Well, somebody will. In 1957.",
	"A man likes to know what's coming. Now I just... find out. When it happens. Like an animal.",
]

## Later visits: he turns up a moment after you, every time.
const FOLLOWING := [
	"Oh, it's you again. I heard the ring hum. Just making sure you're alright. And that the milk is.",
	"Back so soon? Wipe your feet. On the timestream.",
	"I wasn't following you. I was walking in the same direction, very quickly, through a portal.",
	"You know there's a whole hall out there? With other people's things in it?",
]

# --- the story's beats -----------------------------------------------------------------

const TUBE := "The radio's tube! In the Futurescope! Why didn't I think of that? ...You owe me a radio."

const AFTER_VISION := ["Was... was that Fuse? Wearing a sardine lid? In my good yarn?"]

const BOTH_SEE := "...There are two of him."

const OFFICER_ARRIVES := [
	"Well, well. A cat. Two of them, in fact. Rookies.",
	"Form 27-B: unlicensed feline recursion. This timeline is scheduled for deletion.",
	"I'd say it was nice knowing you, but I have standards.",
]

const AFTER_OFFICER := ["...Deletion? I only just had the floors done."]

const LID := "There it is! The lid, right on his ear."

const UNWOUND := "That's my good red yarn. From... later? He's wearing my future knitting."

const WIRED := "Copper wire across a fuse socket. My father would be appalled. Brilliant."

const REJECTED := "It spat him out! Something's not the same as on the Futurescope."

const LOOP_CLOSED := "He went! And the clock's ticking again!"

const CASCADE := ["Oh no. He liked it.", "He's going to do it again. We'll be up to our ears in Fuses."]

const FINALE := ["Huh. You look older, Fuse. Same lid, though."]

const OFFICER_LEAVES := [
	"Hm. One cat. One timeline. Beginner's luck.",
	"Deletion postponed. Don't get comfortable. I'm keeping the form.",
]

const GOODBYE := "Come back any time. Bring sardines. Leave the milk."

# --- his things -------------------------------------------------------------------------

## The first time you touch each of his things (once each).
const MINE := {
	"icebox": "That's my icebox. There's a jelly in there for Thursday.",
	"drawer": "Those drawers are organised. By a system. My system.",
	"radio_back": "Are you taking apart my radio? I was listening to that.",
	"tube": "That's the good tube! ...Well. Science requires sacrifice. Apparently mine.",
	"wire": "My wire. I was going to make something with that. Probably.",
	"box": "Fuse's box. He's very particular about it.",
	"jelly": "Lime. For Thursday. Don't wobble it.",
	"clock": "It's a very good clock. It came free with a vacuum cleaner.",
}

## His milk. He really wants that for himself.
const MILK := [
	"Ah, ah. That's mine. I'll take that.",
	"Not the milk. I'll put a lock on that icebox. A time lock.",
	"Fine. FINE. There. Now nobody has it.",
]

## As the rummaging adds up.
const ANNOYED := {
	4: "Do you go through everyone's things like this?",
	8: "I'm starting a list.",
	12: "The list has a second page now.",
	16: "I'm going to need a bigger list.",
}

# --- the radio --------------------------------------------------------------------------

const STATIONS := {
	0: "Ah, WLTM. Music to invent by.",
	1: "Bach! A man who understood engineering. All those little gears.",
	2: "Radio Havana? How do we even get that? ...Don't tell anyone.",
}

# --- nudges when you're close -----------------------------------------------------------

const NUDGES := {
	"sardines_early": "He didn't even twitch. Usually he comes running for sardines. He seems to be... waiting for something.",
	"tin_closed": "He can smell them through the tin. No thumbs, though. Tragic, for a cat.",
	"yarn_up_high": "He's not coming down to play. Not while that other one's around.",
	"socket": "Blown. And no spare fuse. Anything copper would do in a pinch.",
	"box_shade": "He gave it a look. A cold box, though. Fuse is a sunshine cat.",
	"sunbeam": "Look at that sunbeam. Prime napping real estate, that.",
	"fixated_1": "He's fixated on that lever.",
	"fixated_2": "What does a cat love more than a lever, I wonder?",
	"fixated_3": "A warm box, I'd wager. Ideally in the sun.",
	"wire_watched": "Careful! He'll jump on that lever the moment you reach for the wire.",
	"lever_hand": "Don't! In the picture it was Fuse who pulled it, not you.",
	"lever_asleep": "He's asleep. Pointing lights at a sleeping cat is just rude.",
}

# --- the flashlight (pounce reactions) --------------------------------------------------

const POUNCE := {
	"tv": "He's sitting on the Futurescope. Of course he is. It's warm.",
	"machine": "Not on the tubes! Those tubes are older than you. Well. Than him.",
	"radio": "He's changed the station. He has opinions.",
	"clock": "He thinks the second hand is a mouse. It isn't. I checked.",
	"engineer": "OW. My shoe. Thank you.",
	"blinds": "He's swatted the blind cord. Well, that's let some light in.",
	"twin": "They don't like each other. Which is odd, as they're the same cat.",
	"icebox": "Back up on the icebox. His throne.",
}

# --- mutters when clicked ---------------------------------------------------------------

const MUTTERS := {
	"setup": [
		"Don't mind me. Just mourning a television.",
		"Nobody respects a slide rule anymore.",
		"Fuse sleeps eighteen hours a day. I'm told that's normal. For cats.",
	],
	"loop": [
		"Deletion. He said deletion.",
		"Two cats. I only bought food for one.",
		"I'm not panicking. This is my thinking face.",
		"That other one's very calm, for a paradox.",
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
	],
}

# --- the epilogue -----------------------------------------------------------------------

const EPILOGUE := [
	"Back again! Fuse wandered off through the ring. Toward your century, I'd guess.",
	"And the Futurescope's been picking up other channels ever since. Strange ones.",
]

const SENT := "Off it goes. Mind how it lands."


static func mutter(phase: String, n: int) -> String:
	var pool: Array = MUTTERS.get(phase, MUTTERS.done)
	return pool[n % pool.size()]
