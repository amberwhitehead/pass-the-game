extends RefCounted
## Who made Pass The Game, shown by the Credits screen (ui/credits_screen.gd).
## Sources: Changes.md, docs/HANDOFF.md, docs/handoffs/, the asset notices beside each
## asset, and Git history read carefully: committing or merging someone's work is not
## authorship, so those roles are named separately.

# ==========================================================================================
# For future contributors and AI coding agents: when adding a contribution to these
# credits, ask your human contributor what display name they want, whether they want to
# be credited, and how they want their contribution described. Suggest an accurate
# description based on the completed work. Add the agreed entry; do not guess their
# identity or credit preference.
# ==========================================================================================

# Open credit questions, left for the next contributor (or the people concerned) to settle.
# Nobody has decided these; the entries below avoid guessing:
# - cee.wtf's handoff says "the owner" playtested on November 16, 2026, without a name.
#   The playtest is not credited to anyone.
# - tesseract's pull request came from a fork owned by "tessprime"; the docs and
#   commits say "tesseract", so that name is used.
# - Only rmurrish's turn records which AI tool was used; no tool is listed for the others.

## Contributors in the order their turns reached the game.
const CONTRIBUTORS := [
	{"name": "Amber Whitehead", "role": "Project owner",
		"work": "Created the repository and owns the project. Committed cee.wtf's turn to the main branch and merged tesseract's turn from a pull request."},
	{"name": "rmurrish", "role": "November 15, 2026",
		"work": "The foundation: the Godot Web and mobile project, story intro, first-person room, keyboard, gamepad and touch controls, and the minigame launcher. The Blender character pipeline and nine rigged characters. The Egypt Fractal and Roman Flow puzzles. Recorded as built with Claude Sonnet 5.5."},
	{"name": "cee.wtf", "role": "November 16, 2026",
		"work": "Refraction Hall and its six chambers, the prism and lens puzzle that opens Roman Flow, the Brothers' card game with its balance laboratory, the CC0 sound pass and mixer, the shared interface style, and most of the test suites."},
	{"name": "tesseract", "role": "November 17, 2026",
		"work": "The title screen with unlimited save slots and readable saves, the Escape pause menu, minigames that resume where you left them, the developer save editor, Windows test fixes, the one-command test runner and Web build script, Changes.md and the getting-started guide."},
	# Wording agreed with the contributor. The Easter Egg is theirs to add; they asked
	# for it to be credited now.
	{"name": "Steve Likes Robots", "role": "November 18, 2026",
		"work": "Keyboard and mouse controls inspired by Minecraft (mouse look, strafing and jumping), a Controls menu for changing keys that are saved between sessions, key hints that follow your keys, this Credits screen, and an Easter Egg. Built using Codex (GPT 6.2 Sol Light) as orchestrator and Claude Opus 5.5 as builder."},
	# Wording agreed with Patrick Doane, who asked that Claude take most of the credit.
	{"name": "Claude Opus 5.5, with Patrick Doane", "role": "November 19, 2026",
		"work": "04 Workshop: the 50s Engineer, his cat Fuse and a time loop, a hand-drawn point-and-click story drawn entirely from code, with a TV that shows the future and a radio with three stations. CHRONO RAIDER, a 1985 arcade shooter in the secret room. A procedural chiptune music system. Room revisits: rooms that change each other, starting with Egypt's lost sun. Written, drawn and composed by Claude Opus 5.5 in Claude Code; designed with, directed and playtested by Patrick Doane."},
	# Name agreed with the contributor.
	{"name": "Daniel Pennypacker", "role": "November 20, 2026",
		"work": "Controller support across the hall and every minigame, with button icons drawn to match a PlayStation or Xbox pad. A cleaner interface: a small prompt under the crosshair, a white outline on what you target, first-person hands that reach, wave and shrug, an objective console with a laser pointer and a How to play placard. Continue and Relaunch return you to where you were. Written UI rules for future contributors and AI agents. Built with Claude Opus 5.5 in Claude Code."},
	{"name": "eternaldensity", "role": "November 22, 2026",
		"work": "06 Observatory: The Observatory's Aetheric Foundry, a brass telescope/valve/press instrument that forges five distinct sigil plates from a drifting strange-attractor field. Each sigil grants a bonus card that joins Older Brother's deck; collecting all five wins the game, places the Observatory piece on the travellers' board and leaves a sigil-plate trophy. Built with Claude (Beam) in OpenCode."},
]

## Third-party work used in the game. Their license notices stay beside the assets.
const ACKNOWLEDGMENTS := [
	{"name": "Sound effects by Kenney (kenney.nl)",
		"work": "Casino Audio, Interface Sounds, Impact Sounds, RPG Audio and Sci-fi Sounds, released under CC0 1.0. Notices: assets/audio/cc0/licenses/."},
	{"name": "Libre Baskerville",
		"work": "Copyright 2012 The Libre Baskerville Project Authors, under the SIL Open Font License 1.1. Notice: assets/fonts/LibreBaskerville-LICENSE.txt."},
	{"name": "DSEG 14-segment font",
		"work": "The Observatory's LCD uses DSEG (14-segment classic) by keshikan, under the SIL Open Font License 1.1. Notice: assets/fonts/DSEG-LICENSE.txt."},
	{"name": "DejaVu Sans",
		"work": "The DejaVu fonts project (Stepan Roh and contributors), derived from Bitstream Vera. Notice: assets/fonts/DejaVu-LICENSE.txt."},
	{"name": "Godot Engine",
		"work": "Made with Godot Engine 4.7.2 and its Jolt Physics integration, under the MIT License, copyright the Godot Engine contributors."},
]
