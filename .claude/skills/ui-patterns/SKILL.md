---
name: ui-patterns
description: Pass The Game's UI and input rules (controller layout, drawn button glyphs, crosshair prompts, targeting outline, shrug feedback, choice highlighting). Use before any UI, HUD, prompt, input, controller, menu or minigame-controls work in this repo.
---

Read `docs/UI_PATTERNS.md` in full and follow it. Key points:

- Every screen fully playable by controller (any pad slot, device -1) and mouse/keyboard.
  ✕/R1 = act, R2/□ = second action (R2 read per event with hysteresis), ○ = back / leave a
  minigame / shrug in the hall, △ = menu, L1 = jump.
- Show controller buttons with `ui/pad_glyph.gd` for the plugged-in pad; otherwise Click /
  Right-click. No "E" prompts.
- Small prompt under the crosshair naming the thing; two actions stacked with aligned badges.
  No floating labels; put text on the object or in the prompt. World info on in-world objects,
  not HUD panels.
- Target what the crosshair is on; white silhouette outline on the target.
- Never silent: shrug (`call_group("player_feedback", "shrug")`) plus sound/hint when nothing happens.
- Quiet highlight on options, bold white on the current choice.
- Tests drive pads as device 2 and don't assume a pad is plugged in.

When a pattern changes, update `docs/UI_PATTERNS.md` (and this summary) in the same commit.
