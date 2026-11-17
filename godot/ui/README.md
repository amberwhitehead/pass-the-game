# Refraction Hall interface

The hall uses the visual language of an old exhibition: ivory type, dark enamel,
aged brass, and restrained chamber colors. Headings use bundled Libre Baskerville
(SIL Open Font License); instructions and small technical labels use DejaVu Sans.
Both font licenses live beside their font files in `assets/fonts/`.

Use `game_style.gd` for palette, fonts, panels, labels and the shared Control theme.
Keep small labels sans-serif; reserve serif headings for names and destinations.
Gold marks interaction and hierarchy. Room-specific colors retain their puzzle
meaning. Focus states must remain visible for keyboard users.

Reusable components:

- `conversation_sheet.gd`: speaker, typewriter copy and device-aware advance hint.
- `puzzle_hud.gd`: chamber title, concise instructions, values and action footer.
- `interaction_plaque.gd`: contextual interaction with a separate key badge.
- `world_sign.gd`: physical door/exhibit plaques and compact equipment tags.

World signs use reusable meshes/materials, not render-to-texture UI viewports.
Equipment tags resize only when their text changes and appear at close range.
Their text depth-tests against walls. Avoid restoring broad always-visible labels
across the hall. NPC models/animation are separate from their name presentation.

Keep modal action buttons visible; scroll long rules inside the panel. Screen
panels should block gameplay only when modal, and Sound settings must not advance
conversations or trigger touch actions underneath. Test headlessly with Dummy
audio and visually in the background Web build using `?muted=1`.
