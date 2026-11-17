# Continuous hub-to-table transition

The normal hub launch renders two worlds concurrently. The root viewport keeps
the original hub camera active. The hidden card scene renders continuously into
its own SubViewport. A physical aperture in the hub samples that live texture;
the launcher does not replace the hub with an opaque overlay at entry.
The viewport is independent of its presentation: a TextureRect displays it when
the table becomes visible. A SubViewportContainer would disable its child renderer
when hidden, silently violating the live-preview requirement.

## Camera mapping

Let `S` be the hub camera's global transform, `P` the stationary portal frame in
the hub, and `G` the corresponding gate in the card world. The destination camera
is updated each frame as:

```text
D = G × inverse(P) × S
```

The source camera travels 2.05 m toward a gate placed 2.4 m ahead of its initial
pose. `G` is placed 0.35 m ahead of the final gameplay camera. Therefore the
mapped destination reaches the exact gameplay pose at the end of the dolly.
The same mapping carries lateral motion and roll into the destination world.

Both cameras share FOV, aspect policy, clipping and projection offsets during
the crossing. FOV and offsets converge to the table's original settings. When
the source locks horizontal FOV but the table locks vertical FOV (or vice versa),
the target angle is converted using the current viewport aspect ratio before
interpolation. The final aspect-policy change preserves the projection.

The trajectory uses quintic smoothstep, with zero velocity and acceleration at
its endpoints. Crossing the aperture does not restart this trajectory.

## Rendering and transfer

1. **Warmup:** the hidden destination renders at least two frames. The hub stays
   visible. Production uses `RenderingServer.frame_post_draw`, without CPU image
   readback; headless checks substitute process frames.
2. **Opening:** the brass frame unfolds and grows in the actual hub world. The
   hub camera begins its dolly after the initial opening beat. The surface samples
   the destination with `SCREEN_UV`, retaining normalized screen coordinates.
3. **Handoff:** project the four inner aperture corners into the source viewport.
   Every viewport corner, expanded by eight pixels, must lie inside that polygon.
   Reject behind-camera geometry and near-plane intersections. Only then reveal
   the fullscreen destination and hide the aperture, without altering its camera.
4. **Settling:** continue the same camera trajectory to its endpoint, reveal the
   hand/HUD, then release the gameplay lock and show the rules dialog.

The surface is unshaded and fog-disabled. It uses the transparent pass with
alpha 1, disabled depth testing and maximum material priority, so hub crystals,
labels and close geometry cannot draw over the aperture. Compatibility rendering
applies a cubic sRGB approximation to ALBEDO and a different approximation on
output; a naive texture roundtrip therefore crushes dark colors. The portal shader
inverts that cubic using five bounded Newton iterations, targeting the renderer's
output conversion. This correction runs only when `OUTPUT_IS_SRGB` is true.
Actual GL render checks compare the live portal against the direct destination at
the same camera pose, with changing glow/animation disabled for that measurement.
The corrected table pixels match exactly on the tested macOS GL renderer.

Coverage, rather than elapsed time, authorizes the transfer. The aperture derives
its minimum final size from the camera projection to support changing aspect
ratios. A resize before handoff is therefore evaluated against the new viewport.

## Ownership and cancellation

`MiniGames` reserves a launch before asynchronous loading. It snapshots the caller
camera, room-owned HUD visibility, pause state and touch-control enabled state
before mutation. The card controller holds `_entering` and `_busy` while the
external handoff runs; the match rules do not advance.

The transition owns the temporary aperture and its always-available close button.
Its processing continues while the hub tree is paused. Escape/close can finish the
game during warmup, opening, handoff or settling. Cleanup disconnects the render
callback, removes the portal, and restores the caller state idempotently. After a
successful entrance only the source camera is restored; the room stays paused and
its HUD hidden until the match exits. There is no suspended tween coroutine.

The standalone card scene retains a local entrance because it has no source hub.
Normal Challenge 3 and Little Brother interactions use the continuous handoff.
