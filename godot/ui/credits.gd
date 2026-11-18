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
]

## Third-party work used in the game. Their license notices stay beside the assets.
const ACKNOWLEDGMENTS := [
	{"name": "Sound effects by Kenney (kenney.nl)",
		"work": "Casino Audio, Interface Sounds, Impact Sounds, RPG Audio and Sci-fi Sounds, released under CC0 1.0. Notices: assets/audio/cc0/licenses/."},
	{"name": "Libre Baskerville",
		"work": "Copyright 2012 The Libre Baskerville Project Authors, under the SIL Open Font License 1.1. Notice: assets/fonts/LibreBaskerville-LICENSE.txt."},
	{"name": "DejaVu Sans",
		"work": "The DejaVu fonts project (Stepan Roh and contributors), derived from Bitstream Vera. Notice: assets/fonts/DejaVu-LICENSE.txt."},
	{"name": "Godot Engine",
		"work": "Made with Godot Engine 4.7.2 and its Jolt Physics integration, under the MIT License, copyright the Godot Engine contributors."},
]
