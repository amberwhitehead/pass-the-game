extends RefCounted
## Everything the Engineer and the Officer say in the Workshop, in one place for easy
## rewriting. Hints are worked out from the story's flags.

const Machine := preload("res://minigames/workshop/machine.gd")
const Vision := preload("res://minigames/workshop/vision.gd")

const INTRO := [
	"Oh! A visitor. You must be the one the Officer keeps grumbling about.",
	"Welcome to my workshop. Mind the cat. That's Fuse. He's asleep, which is the safest thing for everyone.",
	"I'm this close to a breakthrough. If only my Futurescope worked...",
]

const TV_BROKEN := [
	"My Futurescope! It shows what's going to happen. Not when, mind you. Just what.",
	"Or it would, if it weren't missing a tube. I gave the spare to... hmm.",
]

const MACHINE_SETUP := [
	"The Chrono-Oscillator. Opens a door to some other when.",
	"It's missing its fuse, which is probably for the best. I never did finish the safety catch.",
]

const AFTER_VISION := [
	"Was... was that Fuse? With a sardine lid on his ear? Wrapped in my knitting?",
	"And he pulled the lever. But the machine doesn't even have a fuse. Ha! A glitch. It must be a...",
]

const OFFICER_ARRIVES := [
	"Well, well, well. An open loop. Rookies. Every single time.",
	"That cat walked out of a portal nobody has opened yet. Until somebody does, this minute can't finish.",
	"So you'll make it happen. Exactly as the box showed you. The lid, the yarn, the dial, the lever. All of it.",
	"Or don't, and stay here forever with two cats and a man in a tie. I'll be at the door. I never get tired of this part.",
]

const AFTER_OFFICER := [
	"Exactly as the Futurescope showed... Right. We can do this. I've had worse Tuesdays.",
	"Fuse needs his lid, his yarn and a lever to pull, and my machine needs power and the right dial setting. Click me if you need a reminder.",
]

const CASCADE := [
	"Oh no. He liked it.",
	"He's going to do it again. And again. We'll be up to our ears in Fuses!",
]

const FINALE := [
	"The portal's gone. The Futurescope shows... a cat in a box. Perfect. Ordinary. Wonderful.",
	"Huh. You look older, Fuse. Same lid, though.",
]

const OFFICER_LEAVES := [
	"Hm. Loop closed, loop broken, and only one cat. Beginner's luck.",
	"Don't let it go to your head. There are other rooms.",
]


## What still differs from the Futurescope footage, as things the Engineer would say.
static func missing(story: Node) -> Array:
	var f: Dictionary = story.flags
	var out := []
	if not f.lid:
		out.append("Wait! On the Futurescope he had a sardine lid on his ear. He doesn't yet.")
	if not f.yarn:
		out.append("Hold on, he wasn't tangled up in yarn yet. In the footage he was wrapped like a parcel.")
	if f.fuse_part != "machine":
		out.append("Stop! The machine's not powered. It was glowing on the Futurescope.")
	if f.dial != Vision.LOOP_DIAL:
		out.append("The dial's wrong! It said something else on the Futurescope. Watch it again if you need to.")
	return out


## The Engineer's reminder of what to do next.
static func hint(story: Node) -> String:
	var f: Dictionary = story.flags
	match f.phase:
		"setup":
			if f.tube == "radio" and not f.radio_open:
				return "The Futurescope needs a tube. My radio's full of them, as it happens."
			if f.tube == "radio":
				return "That middle tube in the radio would fit the Futurescope nicely."
			if f.tube == "held":
				return "Pop that tube into the Futurescope, would you?"
			return "Give the Futurescope's tuning knob a turn."
		"loop":
			var m := missing(story)
			if not f.lid and f.tin == "icebox":
				return "The lid on his ear... it looked like it came off a sardine tin. Try the icebox."
			if not f.lid and f.tin == "held":
				return "Put the sardines down somewhere on the floor. Then they'll need opening. The drawer has a can opener."
			if not f.lid and not f.tin_open:
				return "Open the tin. The can opener's in my workbench drawer."
			if not f.yarn:
				return "Now the yarn. My knitting basket is under the bench, and Fuse is wide awake."
			if f.fuse_part == "can":
				return "The machine needs a fuse. Try the coffee can. I keep everything in coffee cans."
			if f.fuse_part == "held":
				return "Put the fuse in the Chrono-Oscillator."
			if f.dial != Vision.LOOP_DIAL:
				return "The dial on the Futurescope said something different. Watch the footage again and match it."
			if m.is_empty():
				return "Everything matches. Now get Fuse onto that lever. He'll chase a flashlight anywhere."
			return m[0]
		"break":
			if f.box == "wall":
				return "Distract him. What does every cat find irresistible? A box! There's one flattened by the bench."
			if f.box == "held":
				return "Put the box on the floor, near him."
			return "Now pull the fuse out of the machine!"
	return "Thank you, friend. Fuse thanks you too, in his own way. By ignoring you."


static func portal(story: Node) -> String:
	match story.flags.phase:
		"setup":
			return "The portal ring. Brass. Hand-polished. Completely inert, I assure you."
		"loop":
			return "Inert! It was inert. Now look at it. It's practically smug."
		"break":
			return "It won't close while that cat's thinking about another trip."
	return "Quiet as a church."


static func no_use(item: String, id: String) -> String:
	if id == "engineer":
		return "Kind of you, but I'd only lose it."
	if id == "fuse" or id == "twin":
		return "He sniffs it, then looks at you with deep disappointment."
	if id == "floor":
		return "Best keep hold of that."
	return "I don't think that goes there."
