# Observatory design: proper graphics, models and physics

Design for upgrading the Observatory's Aetheric Foundry from its functional
placeholder (procedural meshes, no art) to a finished, tactile instrument.
Companion to `docs/INTERCONNECTION.md` and `godot/scenes/escape/README.md`.

## 1. Goal

Make the Observatory minigame feel like a real brass/alchemical instrument: every
control is a physical object you grab and turn, the aether visibly flows through
pipes and condenses, and the sigil plate solidifies layer by layer. Keep the
gameplay loop (observe → flow → forge → inscribe) but make it beautiful and
physically satisfying, matching the quality of the Newton and Turing tables.

## 2. Art direction

- **Materials**: brass (0.7 metallic, 0.3 rough), copper, dark walnut, enamel
  (Metric A's purple accent #c47ae5), glass (translucent aether-blue), stone base.
- **Palette**: reuse the shared 16x16 cell palette in `blends/palette/`. Append
  new cells (brass, copper, aether glass, enamel purple, stone) — never reorder.
- **Style**: low-poly blocky, ~2–4k triangles per major prop, consistent with
  the Newton/Turing platforms. One mesh, one material, flat-shaded cells.
- **Lighting**: warm key light + cool aether emission; the attractor and flow glow.

## 3. Prop: `observatory_platform.py` (new Blender generator)

Follow `blends/props/newton_platform.py` conventions: game scale, nodes listed in
docstring, layout constants mirror `observatory.gd`. Output
`godot/assets/props/observatory_platform.glb` with import script
`post_import.gd`.

### Exported nodes (names the game relies on)

| Node | Role |
|---|---|
| `Platform` | Base, deck, stone plinth |
| `TelescopeMount` | Brass azimuth ring + elevation fork + focus tube (pivot = mount base) |
| `AzimuthKnob` | Turntable knob, pivot = its center, Y axis |
| `ElevationKnob` | Fork tilt knob, pivot = fork, X axis |
| `FocusRing` | Focus collar on the tube, pivot = tube axis, Z axis |
| `SigilSelector` | Dial on the deck, pivot = center, Y axis, 5 detents |
| `ValveA`, `ValveB` | Wheel valves, pivot = stem, Z axis, 0..1 turn |
| `Crank` | Layer crank handle, pivot = axle, X axis, full turn advances a layer |
| `InscribeLever` | Lever arm, pivot = base, rotates 0..90° to inscribe |
| `TelescopeLens` | Glass lens at tube end (material: glass) |
| `VoidWindow` | Plane/mesh where the attractor renders |
| `AetherPipe_A`, `AetherPipe_B` | Pipes from valves to the mold |
| `Mold` | The plate mold (where solidification happens) |
| `FlowGauge` | Needle gauge showing laminar/turbulent |
| `InscriptionPlate` | The finished sigil plate (hidden until inscribed) |

### Layout constants (mirror observatory.gd)

TABLE_R, APRON_R, control angles, knob radii. Keep in sync with the script.

## 4. Models and materials

- **Telescope mount**: brass cylinders for azimuth ring, fork arms, tube. Glass
  lens (translucent, slight blue tint). A small sight ring.
- **Knobs**: brass cylinders with knurled edge (box-primitive ridges). Each has a
  pointer mark (painted line) so rotation is readable.
- **Valves**: wheel with spokes (classic valve wheel), stem, flange. Turn 0..1.
- **Crank**: handle on an axle, counterweight; turn full revolution.
- **Lever**: brass arm with wooden grip; pulls down to inscribe.
- **Pipes**: copper cylinders with flanges, curved (box segments).
- **Mold**: stone/metal box with a recess for the plate; glass lid.
- **Void window**: dark frame with a glass pane; attractor renders behind it.
- **Flow gauge**: brass bezel, white face, needle.

## 5. Physics and interaction

### Grab/turn model (Newton-style, improved)

- Orbit camera around the table (A/D or right stick). When the camera is within
  `FOCUS_ARC` of a control, it highlights (silhouette outline) and the HUD names
  it.
- Interact (E/R1) grabs; while grabbed, A/D (or right stick X) turns the
  control; interact releases. A held control ramps speed 0.12→1.0 over
  `RAMP_TIME` for fine→coarse.
- **Detents**: SigilSelector has 5 detents (snaps to integer). Valves have
  continuous 0..1. Crank accumulates rotation; a full 2π turn advances a layer.
- **Haptics/feedback**: subtle sound on grab/turn/detent; shrug if no-op.
- **Gamepad**: right stick X turns while grabbed; handled via Input axis.

### Crank physics

- Track accumulated angle (radians). When `accumulated >= 2π`, advance layer and
  reset accumulator. Direction-sensitive (only clockwise advances; counter-
  clockwise rewinds? Optional: allow rewind to redo a layer).
- Visual: crank rotates with the accumulated angle; handle follows.

### Valve physics

- 0..1 turn (0 = closed, 1 = open). Flow rate = valve openness × base rate.
- Turbulence when flow too high or mismatched; laminar when within tolerance of
  target. Gauge needle shows flow; color green (laminar) / red (turbulent).

### Telescope aim

- Azimuth: -π..π (horizontal). Elevation: -1.2..1.2 (vertical). Focus: 0..1.
- Resolution metric: angular distance to target (az,el) + focus threshold. When
  within tolerance, attractor sharpens and becomes inscribable.

## 6. Particle field (strange attractor)

### Rendering

- **Approach**: Godot `GPUParticles3D` or a custom `MultiMeshInstance3D` point
  cloud. For the "Fluoddity" feel, animate points along the attractor path with a
  trail (decaying texture).
- **Trail field**: a SubViewport with a shader that deposits points and decays
  (like Fluoddity's trail field). Resolution 256×256 or 512×512.
- **Bloom**: subtle emission on points; use Godot's glow (Environment.glow).
- **5 attractor shapes**: spiral, rosette, trefoil knot, double helix, void ring.
  Each maps to a sigil. Points colored by cohort (purple→blue gradient).

### Performance

- Cap at ~2000–4000 points. Trail texture 256². Target 60fps on Web.
- Use `MultiMeshInstance3D` with `PRIMITIVE_POINTS`-equivalent via small
  sphere meshes (radius 0.02) for WebGL compatibility (no point-size issues).

### Focus effect

- When unresolved: points are dim, scattered (additive noise), slightly blurred.
- When resolved: points snap to sharp attractor shape, brighten, trail
  condenses. Shader lerps blur/noise based on resolution factor.

## 7. Aether flow (valves → pipes → mold)

### Flow visualization

- Particles (small blue spheres) spawn at valves proportional to openness and
  travel along pipe paths (Curve3D) to the mold.
- **Laminar**: smooth, steady stream, few particles, straight trails.
- **Turbulent**: chaotic, many particles, swirling, red-tinted.
- Use `GPUParticles3D` with a path (Curve3D) and velocity; or animate sprite
  billboards along the curve.

### Pipe model

- Copper cylinders with flanges; transparent sections (glass) to show flow.
- Junctions where two pipes merge into the mold.

### Mold solidification

- The mold contains a plate. As layers solidify, the plate gains opacity/color.
- Each layer: if clean, the layer's region fills with brass/gold; if turbulent,
  that region stays void (dark) or cracked.
- Visual: a shader on the plate mesh lerps from transparent (empty) to solid
  (brass with sigil etching) per layer. Use a 2D layer mask texture updated from
  code.

## 8. Sigil inscription

- When the plate is complete and all layers clean, the inscription lever becomes
  active (highlighted).
- Pulling the lever: animation (lever rotates down), a "stamp" effect (flash,
  particle burst), and the sigil etches into the plate (emissive lines appear).
- The finished plate is shown (InscriptionPlate node) with the sigil's symbol.
- Then the plate is "collected" (fades, card granted) and the mold resets.

## 9. Sound

- Knob turn: soft ratchet clicks (reuse Kenney interface sounds).
- Valve: hiss/flow sound scaled by openness.
- Crank: mechanical ratchet per turn.
- Inscription: stamp + chime.
- Attractor resolution: rising tone when focusing.
- Turbulence: low rumble.

## 10. Implementation phases

### Phase 1 — Models (Blender)
1. Create `blends/props/observatory_platform.py`.
2. Append palette cells (brass, copper, glass, enamel purple, stone, aether blue).
3. Build all nodes per §3. Export GLB.
4. Review renders (turntable).

### Phase 2 — Integration (Godot)
1. Import GLB with `post_import.gd`.
2. Replace procedural meshes in `observatory.gd` with the model's nodes (find by
   name, like Newton does with `roller_0..3`).
3. Wire control angles from the model's actual positions (or keep constants and
   align the model to them).

### Phase 3 — Physics polish
1. Crank accumulated-angle + layer advance with visual rotation.
2. Valve flow + turbulence + gauge needle.
3. Telescope aim resolution + focus effect on attractor.
4. Inscription lever animation + stamp effect.

### Phase 4 — Particle field & flow
1. Attractor point cloud (MultiMesh) with 5 shapes.
2. Trail field SubViewport + decay shader.
3. Flow particles along pipes (GPUParticles3D + Curve3D).
4. Mold solidification shader (layer mask).

### Phase 5 — Polish & tests
1. Sound pass.
2. Save/resume (already wired; verify with new visuals).
3. Update `observatory_test.gd` to drive the new controls.
4. Real-testing exploration: boundary values, invalid inscriptions, reload
   mid-forge, turbulence setbacks.
5. Web build + playtest.

## 11. Risks / open questions

- **WebGL point rendering**: use small sphere meshes, not GL_POINTS, for
  compatibility.
- **Trail field performance**: 256² texture + 4k points; profile on Web.
- **Blender pipeline**: appending palette cells; coordinate with the append-only
  rule. If a cell is wrong, add a new one rather than edit.
- **Import script**: must set `post_import.gd` on the GLB or face animations
  (none here) / padding issues.
- **Scope**: Phase 1–3 are the core; Phase 4 (trail field) is the wow factor
  and may slip. Ship Phase 1–3 + basic flow particles first if time runs short.

## 12. Success criteria

- Every control is a physical, grabbable, readable object (no floating UI).
- The attractor visibly resolves when tuned correctly.
- Flow is visibly laminar/turbulent and affects solidification.
- Layers solidify visibly; a clean plate can be inscribed.
- All five sigils collectible; game wins; card + board piece + trophy appear.
- 60fps on Web at 1280×720.
- Full test suite still green.
