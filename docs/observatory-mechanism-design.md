# Observatory mechanism: integrated design

A detailed design for the Aetheric Sigil Press as one coherent machine rather than a
circle of independent controls on a plinth. Every element has a physical role in a
single flow: **observe → channel → forge → inscribe**.

## 1. Concept: the Aetheric Engine

The instrument is a **brass and stone engine** that converts the void's strange
attractors into solid sigil plates. It has four physical stages arranged along a
clear flow path:

```
   [VOID WINDOW]  →  [TELESCOPE]  →  [VALVES]  →  [PIPES]  →  [MOLD/PRINTER]
        ↑                ↑               ↑            ↑            ↑
   attractor         aim/focus        flow rate    channeling    solidify
   source            resolve          control      delivery      + inscribe
```

The player orbits the machine and operates each stage in order. The machine's
physical layout mirrors the data flow: left-to-right / back-to-front.

## 2. Physical layout (top-down)

```
                        ┌─────────────────────┐
                        │     VOID WINDOW     │  (north wall, 3.4×2.4 glass)
                        │   [attractor field] │
                        └──────────┬──────────┘
                                   │
                        ┌──────────┴──────────┐
                        │   TELESCOPE MOUNT   │  (center-back, on a raised
                        │  (az/el/focus knobs)│   brass pedestal)
                        └──────────┬──────────┘
                                   │ (beam/aether path)
              ┌────────────────────┼────────────────────┐
              │                    │                    │
   ┌──────────┴──────────┐  ┌─────┴─────┐  ┌──────────┴──────────┐
   │     VALVE A         │  │ SIGIL     │  │     VALVE B         │
   │  (wheel + gauge)    │  │ SELECTOR  │  │  (wheel + gauge)    │
   └──────────┬──────────┘  │  (dial)   │  └──────────┬──────────┘
              │             └───────────┘              │
              │                                        │
              └──────────────┬─────────────────────────┘
                             │
                    ┌────────┴────────┐
                    │   MOLD / PRINTER │  (front-center, stone box)
                    │  ┌────────────┐  │
                    │  │  PLATE     │  │  ← solidifies layer by layer
                    │  └────────────┘  │
                    │   [layer ring]   │  ← progress indicator
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │  INSCRIPTION     │  (lever, pulls down to stamp)
                    │     LEVER       │
                    └────────────────┘
   [CRANK] (side) ── drives the printer's layer mechanism
   [RESET] (corner) ── clears the plate
```

### Positions (game coords, table radius 2.4)

| Component | Position (x, y, z) | Role |
|---|---|---|
| Void window | (0, 1.6, -4.0) | Attractor source |
| Telescope mount | (0, 0.3, -1.2) | Aim/focus (on a raised pedestal) |
| Azimuth knob | (1.2, 0.12, -1.8) | Horizontal aim |
| Elevation knob | (0.6, 0.12, -1.8) | Vertical aim |
| Focus ring | (-0.6, 0.12, -1.8) | Sharpness |
| Sigil selector | (-1.2, 0.12, -1.8) | Choose target sigil |
| Valve A | (-2.0, 0.12, 0.0) | Flow rate (left) |
| Valve B | (2.0, 0.12, 0.0) | Flow rate (right) |
| Flow gauge A | (-2.0, 0.12, 0.6) | Pressure (left) |
| Flow gauge B | (2.0, 0.12, 0.6) | Pressure (right) |
| Mold/printer | (0, 0.06, 1.4) | Solidification bed |
| Layer ring | (0, 0.18, 1.4) | Progress indicator |
| Crank | (1.6, 0.12, 1.8) | Drive layers |
| Inscribe lever | (-1.6, 0.12, 1.8) | Stamp sigil |
| Reset button | (0, 0.06, 2.2) | Clear plate |

The controls are **grouped by stage** (telescope group, valve group, forge group)
rather than evenly spaced around a circle. Related controls cluster together.

## 3. Component roles and affordances

### Stage 1: Void Window + Telescope
- **Void window**: a brass-framed glass pane on the north wall. The attractor
  renders on it as a glowing particle field. When unresolved, it's a dim,
  scattered cloud. When resolved, it sharpens into a bright sigil shape.
- **Telescope mount**: a brass pedestal with an azimuth ring, elevation fork,
  and focus tube with a glass lens. The mount physically rotates/tilts to
  reflect the aim. The lens glows when resolved.
- **Azimuth knob**: large brass cylinder (coarse adjustment). Turns the mount
  left/right. Pointer mark shows current angle.
- **Elevation knob**: medium brass cylinder. Tilts the mount up/down.
- **Focus ring**: a collar with grip ridges around the tube. Turning it
  sharpens the view; a glow dot appears when resolved.
- **Sigil selector**: an enamel dial with 5 detent notches and a pointer.
  Each detent corresponds to a sigil. Uncollected sigils are dimmed;
  collected ones glow.

### Stage 2: Valves + Flow Gauges
- **Valve A/B**: classic wheel valves with spokes. Turning them (clockwise
  closes, counter-clockwise opens) controls aether flow rate. The wheel
  physically rotates. A red/green indicator on the hub shows flow state.
- **Flow gauge A/B**: brass bezel with a white face and needle. Green zone
  (laminar/clean), red zone (turbulent). The needle position shows current
  flow. Instant feedback.
- **Pipes**: copper cylinders with flanges connecting each valve to the mold.
  Aether particles flow through them (visible when valves are open). The
  pipes curve organically from valve to mold.

### Stage 3: Mold / Printer
- **Mold**: a stone box with a brass recess. The plate sits inside. The mold
  has a glass lid (translucent) so the solidification is visible.
- **Plate**: a brass plate that starts transparent/empty. As layers solidify,
  it gains opacity and color (brass → gold). When complete and clean, the
  sigil is etched into it (emissive lines).
- **Layer ring**: a ring around the mold's rim with 4 segments. Each segment
  lights up (gold) when its layer is solidified. Void layers stay dark/cracked.
- **Progress indicator**: a small counter showing "LAYER X/4".

### Stage 4: Crank + Inscribe Lever
- **Crank**: a brass axle with an arm and wooden ball handle. Turning it
  clockwise one full revolution solidifies the current layer. A ratchet click
  per layer. The crank has a direction arrow on its base. When all layers are
  done, the crank locks (greyed) and shrugs on interact.
- **Inscribe lever**: a brass arm with a wooden grip, pivoted at the base.
  Pulling it down (animated) stamps the sigil into the plate. Only enabled
  when the plate is complete and all layers are clean. Otherwise greyed +
  shrug. On success: stamp flash, particle burst, chime.
- **Reset button**: a red enamel button in the corner. Clears the plate and
  resets to layer 0.

## 4. The flow (data + physical)

```
1. OBSERVE: Aim telescope at void window → attractor resolves into sigil ghost.
            Sigil selector picks which sigil to seek.
            Focus ring sharpens the view.

2. CHANNEL: Open valves → aether flows through pipes to mold.
            Flow gauges show laminar (clean) vs turbulent.
            Valves must be within tolerance of the sigil's target flow.

3. FORGE:   Turn crank → solidify current layer.
            Layer is clean if flow was in tolerance during the turn.
            Layer ring lights up for clean layers.
            Repeat for 4 layers.

4. INSCRIBE: When all 4 layers clean → pull lever → sigil stamps into plate.
             Plate collected → bonus card granted, board piece appears.
             Mold resets for next sigil.
```

## 5. Visual identity per component

| Component | Shape | Material | Affordance |
|---|---|---|---|
| Void window | Rectangular frame + glass | Brass frame, glass pane | "Look through me" |
| Telescope mount | Pedestal + ring + fork + tube + lens | Brass, glass lens | "Aim me" |
| Azimuth knob | Large knurled cylinder | Brass | "Turn me (coarse)" |
| Elevation knob | Medium knurled cylinder | Brass | "Turn me (vertical)" |
| Focus ring | Collar with grip ridges | Brass + glass dot | "Turn to focus" |
| Sigil selector | Enamel dial with detents | Enamel teal + brass pointer | "Pick a sigil" |
| Valve A/B | Wheel with spokes + hub | Brass + copper accent | "Turn to open/close flow" |
| Flow gauge | Bezel + white face + needle | Brass + enamel | "Read pressure" |
| Mold | Stone box with brass recess | Stone + brass | "Place plate here" |
| Plate | Brass plate with etch | Brass + glow | "Collect me" |
| Layer ring | 4 segments around mold | Brass + glow | "Progress" |
| Crank | Axle + arm + ball handle | Brass + wood | "Turn to forge" |
| Inscribe lever | Arm + grip + base | Brass + wood | "Pull to stamp" |
| Reset button | Small red button | Enamel red | "Clear" |

## 6. Color coding

- **Brass** (#d1a93a): structural, mechanical, permanent.
- **Copper** (#b87333 or enamel_teal as proxy): flow, aether, energy.
- **Stone** (#b89a6c): base, plinth, mold body.
- **Wood** (#7a5230): grips, handles, organic touch points.
- **Enamel cream** (#eae2c8): glass, lenses, gauge faces.
- **Enamel teal** (#2c8c8e): sigil selector, accents, aether.
- **Enamel red** (#c23a2b): reset, danger, closed state.
- **Glow cyan/amber**: active, emissive, resolved, collected.
- **Grey**: disabled/locked state.

## 7. Feedback and state communication

- **No floating labels**: all text is on the object or in the HUD caption.
- **Prompt caption** under the crosshair names the focused control and action.
- **White silhouette outline** on the focused control.
- **Shrug** (palms-up hands) when an action can't do anything.
- **Sound**: ratchet (crank), hiss (valve), clunk (limit), chime (success),
  rising tone (focus), rumble (turbulence).
- **Disabled state**: greyed material + shrug on interact.
- **Progress**: layer ring segments light up; HUD shows "LAYER X/4".

## 8. Grouping and spatial logic

Controls are grouped by function, not evenly spaced:
- **Telescope group** (north-back): azimuth, elevation, focus, sigil selector.
  These are all about observation and are clustered around the telescope.
- **Valve group** (east and west): valve A, valve B, flow gauges. These are
  about channeling and are placed where the pipes begin.
- **Forge group** (south-front): mold, plate, layer ring, crank, lever, reset.
  These are about solidification and inscription, clustered where the player
  stands to watch the plate form.

The player orbits the table and naturally encounters groups in flow order:
telescope → valves → forge.

## 9. Implementation plan

### Phase A: Layout (Blender + code)
1. Update `observatory_platform.py` to place controls in the new grouped layout.
2. Update `observatory.gd` control angles to match the new positions.
3. Move attractor to center (already done) or keep in void window.
4. Add pipes (already added) connecting valves to mold.

### Phase B: Visual identity (Blender)
1. Ensure each control has a distinct, recognizable shape.
2. Apply appropriate materials (already using palette cells).
3. Add knurling, spokes, grip ridges, detents, pointers, arrows.
4. Add layer ring segments around the mold.

### Phase C: Interaction (GDScript)
1. Fix rotation axes (done).
2. Add disabled-state greying (done).
3. Add sound cues for all interactions.
4. Add on-screen prompt naming the focused control.

### Phase D: Flow visualization (GDScript + shaders)
1. Aether particles flowing through pipes.
2. Mold solidification with layer-mask shader (done).
3. Attractor sharpening on focus (done).

### Phase E: Polish
1. Stamp animation + burst (done).
2. Web performance profiling (done).
3. Full test suite green (done).

## 10. Success criteria
- Every control is a recognizable, distinct mechanism part.
- The physical layout mirrors the data flow (observe → channel → forge → inscribe).
- Controls are grouped by function, not evenly spaced.
- Materials are appropriate and varied (brass, stone, wood, copper, glass, enamel).
- The attractor is centered and clearly visible.
- Pipes connect valves to mold, forming a continuous flow path.
- All interactions have clear affordances and feedback.
- 60fps on Web at 1280×720.
- Full test suite green.
