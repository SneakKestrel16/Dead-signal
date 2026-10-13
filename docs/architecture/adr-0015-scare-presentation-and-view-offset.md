# ADR-0015: Scare Presentation and View Offset

## Status
Proposed

## Date
2026-10-12

## Last Verified
2026-10-12

## Decision Makers
Designer (SneakKestrel16), with Claude Code (`/architecture-decision`, autonomous mode, AD-49) and `godot-specialist` engine validation. TD-ADR skipped — Lean mode. `godot-specialist` (2026-10-12) found one blocking issue (integer division in the ramp) and four MEDIUM (tick alignment, frame-rate stepping, physics interpolation on the camera chain, pitch clamp order); all are folded into §1–3 and §5.

## Summary
The camera flinch is the one rotation the game may apply to a player's view, so the server and the flinched client must agree on it to the tick; screen flashes, camera reactions and the reduced-motion and photosensitivity settings had no transport or client design either (TR-scare-006/-009/-012, TR-controller-010, TR-index-008). The Controller owns a per-player flinch record (from, target, start tick, ramp ticks) sent reliably to its owner only, both sides compute the ramp as a pure function of ticks, and a re-baseline is handshaken by a view epoch in the input frame; every other scare effect is client-only presentation in a `ScarePresenter` on a fixed `SCARE_FX` layer, under one flash limiter shared with lighting flicker.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Input (view direction), UI / Rendering (client effects) |
| **Knowledge Risk** | MEDIUM: the view-offset math is plain GDScript on ADR-0002's frame; effects use `CanvasLayer`, `ColorRect` and a `Node3D` camera child, none changed post-cutoff in the reference. No `Compositor` effect is used |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/rendering.md`, `modules/ui.md`, `breaking-changes.md`, `deprecated-apis.md`; ADR-0002, ADR-0004, ADR-0005, ADR-0009, ADR-0013, ADR-0014 |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | (1) a flinch ramp computed on the server and on the owner from the same record gives yaw and pitch equal to 1e-4 rad on every tick, with 0, 50 and 150 ms latency; (2) a re-baseline during a 150 ms round trip produces no visible snap and no tick where the server view direction differs from the client's by more than 0.5°; (3) a full-screen `ColorRect` flash with additive alpha on `SCARE_FX` costs under 0.1 ms on the GPU at 1440p; (4) with `physics/common/physics_interpolation` on, the interpolation-off camera chain under the interpolated body shows no stutter at 144 Hz while walking and during a flinch (amended 2026-10-12 for architecture review 12d, AD-50) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0013 (Proposed): stingers through `AudioDirector`. ADR-0002 (Proposed): input frame, server view direction = yaw/pitch + view offset, pitch clamp. ADR-0004 (Proposed): owner-only projection, `ScareTriggered` payload. ADR-0005 (Proposed): registry views, events, `ClientEventRouter`. ADR-0009 (Proposed): flicker clamp and flash scale. ADR-0014 (Proposed): `UiLayers`, P8 edge indicator |
| **Enables** | Scare Events client stories; Controller flinch story; Accessibility Options reduced-motion and photosensitivity hooks |
| **Blocks** | Scare Events flinch and presentation stories; Controller view-offset story |
| **Ordering Note** | None |

## Context

### Problem Statement
`scare-events.md` rules 13–14 and 27 and `first-person-controller.md` rules 7 and 9 define a server-held yaw/pitch offset that ramps in within 0.3 s, is replaced (not stacked) by a new flinch, freezes on a lunge wind-up, and is reset by the Controller (round end, Downed, Hidden, Seized, reconnect, toggle off) with a re-baseline that shows no snap. The aim ray uses the server's view direction, so the owner must render exactly what the server computes. Rules 24–29 add flash scale, a 3 flashes/s cap, separate scare volumes, the flinch toggle and information parity; TR-scare-012 lists stingers, flashes, camera reaction and an impossible surveillance frame. No ADR said how the offset reaches the client, how a reset avoids a snap while inputs are in flight, or how client effects stay inside the flash cap.

### Constraints
- State-changing facts never travel unreliably (ADR-0004); snapshots are unreliable.
- Only the Controller applies and resets the offset; Scare Events only writes new flinches (systems-index state rows).
- Every camera effect other than the flinch is client-only and never changes the server view direction (TR-controller-010).
- Accessibility settings never change server timing, cooldowns or recipients (rule 29).

### Requirements
- Server and owner agree on the view direction on every tick.
- Reset without a visible snap.
- One flash cap across scare flashes and light flicker.

## Decision

**1. Flinch record.** The Controller owns, per player, a `FlinchRecord {from: Vector2, target: Vector2, start_tick: int, ramp_ticks: int}` (yaw, pitch in radians). Scare Events requests a flinch by emitting `FlinchRequested {player_id, target}`; the Controller, in its handler, refuses it if the player's flinch toggle is off or a lunge wind-up within `lunge_cue_radius_m` freezes flinches (Monster Abilities registry state), and otherwise writes a new record whose `from` is the offset at the current tick (replace, not stack) and whose `ramp_ticks` is `scare_max_control_loss_s` in ticks. The applied offset at tick t is `from.lerp(target, smoothstep(0.0, 1.0, clampf(float(t - start_tick) / maxi(ramp_ticks, 1), 0.0, 1.0)))`; the float cast matters, since int division would jump the ramp from 0 to 1, and `maxi` guards the freeze record's `ramp_ticks = 0`. `t` is a float so the client can evaluate it at render time between ticks (ADR-0002 §8 renders yaw and pitch at frame rate), while the server uses whole ticks. A freeze writes a record with `from = target = current offset` and `ramp_ticks = 0`. Offsets are small and relative, so a plain `lerp` (not `lerp_angle`) is correct; Vector2 float32 precision is enough for the 1e-4 rad target.

**2. Transport.** Every new record is sent reliably as the `ViewOffsetChanged` event. The owner computes the same function of its estimated server tick (ADR-0002 §7), so the ramp needs one message, not one per tick. `project()` returns the record for the owner and that owner's spectators, and `{}` for everyone else, so a spectated view matches. Each input frame carries the tick estimate the client used when it sampled (`offset_tick`, low 16 bits beside `seq`, expanded on the server to the full tick nearest the current tick) and the id of the record the client rendered with (`record_id`, a byte that increments per record). The server keeps each player's last four records and evaluates that frame's own record, so frames sampled before the owner learned of a replacing flinch keep the old record and the two sides never disagree by a round trip of ramp. It evaluates `offset_at` at the frame's tick, clamped to the record's `start_tick` and the current tick, not at the tick it consumes the frame: the 1–2 tick input queue (ADR-0002 §4) would otherwise put the two sides up to about 1.7° apart at the steepest part of the ramp. A new record reaches the owner one latency late and starts mid-ramp, a small visible pop the design accepts (amended 2026-10-12 for architecture review 12d, AD-50).

**3. Re-baseline.** A reset sends a record with `rebaseline = true` and a new `view_epoch` (0–255, wraps). On receipt the owner, in one `_process` call, adds the held offset into its own yaw and pitch, zeroes its offset, and from then on stamps every input frame with the new epoch (a byte beside the flags, ADR-0002 §3). The server keeps a base offset per epoch for the last four epochs: the view direction is frame yaw/pitch + `base[frame.view_epoch]` + `offset_at(record, offset_tick)`. A reset stores the held offset as the old epoch's base, sets the new epoch's base to zero and writes a zero record, so frames in flight during the handshake keep the same server view direction and nothing snaps; a second reset or a new flinch during a handshake needs no special case. The ±85° pitch clamp applies to the sum (frame pitch + base + offset) on both sides, never to the raw pitch alone, so a 10° flinch cannot carry the view past vertical; the client's fold clamps the same sum, so both sides agree.

**4. Flinch toggle.** The client sends `set_flinch_enabled(bool)` as a reliable RPC on join and on change. Network Authority keeps it in the player's session record (like the display name) and registers it read-only as `PlayerSettingsView` under `player_settings`. Scare Events and the Controller read it; when it turns off, the Controller re-baselines (§3). With it off, Scare Events emits no `FlinchRequested` and the client shows the P8 screen-edge pulse toward the origin instead.

**5. Client effects.** A client `ScarePresenter` receives `ScareTriggered` from the `ClientEventRouter` and plays the effect list carried by the scare's authored entry (`ScareCatalog`, data): stinger (through `AudioDirector`, ADR-0013), screen flash, camera reaction, edge pulse. The flash is a full-screen `ColorRect` on `UiLayers.SCARE_FX` (3, between `HUD` and `CAPTIONS` = 4, so captions stay readable over a flash; ADR-0014 §4 amended) with `mouse_filter = MOUSE_FILTER_IGNORE` and a `CanvasItemMaterial` with `blend_mode = BLEND_MODE_ADD`; a root-viewport `CanvasLayer` draws after tonemapping, so flash luminance is measured on the final output. Its peak alpha is multiplied by the flash scale, and at scale 0 it becomes a 0.4 s non-flashing dim, drawn by a second black `ColorRect` on `SCARE_FX` with the default mix blend, since an additive rect can only brighten. The camera reaction is a small positional and rotational shake on a `CameraFx` `Node3D` between the head and the `Camera3D`, scaled to 0 when the player's camera-impact shake setting is off; it never touches the yaw and pitch the input sampler reads. The head, `CameraFx` and `Camera3D` set `physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF` while the project setting `physics/common/physics_interpolation` stays on for the body (ADR-0002 §8; Verification 4), because they are written every rendered frame and interpolation would smear and delay both the shake and the frame-rate yaw (property name NOT SOURCEABLE in the reference). No effect hides the screen centre for more than 0.1 s (rule 15).

**6. One flash limiter.** A client `FlashLimiter` admits a luminance flash only if fewer than `max_flashes_per_s` (ADR-0009, 3) were admitted in the last second, counting screen flashes and the flicker precompute together; ADR-0009's flicker clamp calls it while precomputing. A refused screen flash plays as the non-flashing dim. Settings scale intensity only; direction, origin and timing are unchanged (rule 28).

**7. Impossible surveillance frame.** A single-client hallucination of this kind carries an authored frame id; the client draws that texture inside the feed `SubViewport` (ADR-0009 §8), as a `TextureRect` in the viewport, for the authored duration; a root `CanvasLayer` would not line up with the in-world monitor. Nothing is sent to any other client (rule 20).

### Architecture Diagram

```
Server                                         Owner client
ScareEvents ─ FlinchRequested ─▶ Controller     ClientEventRouter
  (toggle off: no request)       │ FlinchRecord   ├─ ViewOffsetChanged ─▶ view offset = f(record, est. tick)
                                 │                │      rebaseline: fold offset into yaw/pitch, new epoch
                                 ▼                │
   view dir = frame yaw/pitch + f(record, tick)   └─ ScareTriggered ─▶ ScarePresenter
   (old-epoch frames: + held offset)                    ├─ AudioDirector (stinger)
                                                        ├─ SCARE_FX flash ─▶ FlashLimiter ◀─ flicker precompute
                                                        ├─ CameraFx shake (client only)
                                                        └─ P8 edge pulse (toggle off)
```

### Key Interfaces

```gdscript
class_name FlinchRecord extends RefCounted
var from: Vector2
var target: Vector2
var start_tick: int
var ramp_ticks: int
var view_epoch: int
var rebaseline: bool
static func offset_at(r: FlinchRecord, tick: float) -> Vector2   # pure; shared by server (whole ticks) and client (render-time ticks)

class_name PlayerSettingsView extends RefCounted
func flinch_enabled(player_id: int) -> bool   # false for unknown ids; returns on every branch

class_name FlashLimiter extends RefCounted
func try_flash(now_s: float) -> bool          # true if under max_flashes_per_s in the last second
```

### Implementation Guidelines
- Only the Controller **must** write a `FlinchRecord`; Scare Events **must** request through `FlinchRequested`.
- Server and client **must** compute the offset with the one `FlinchRecord.offset_at`.
- `ViewOffsetChanged` **must** be reliable and projected to the owner and that owner's spectators only.
- A reset **must** use the epoch handshake; the server **must never** zero an offset without one.
- The server **must** evaluate the frame's own `record_id` record at the frame's `offset_tick`, never the newest record or the consume tick.
- The ±85° pitch clamp **must** apply to frame pitch + base + offset.
- The head, `CameraFx` and `Camera3D` **must** have physics interpolation off.
- Client camera effects **must** live under `CameraFx` and **must never** change the yaw and pitch the sampler sends.
- Every luminance flash, screen or light, **must** pass `FlashLimiter`.
- Scare effect lists **must** come from `ScareCatalog` data; the flinch cap and ramp **must** come from `ScareKnobs`.

## Alternatives Considered

### Alternative 1: Offset in every snapshot
- **Description**: The owner's snapshot carries the applied offset each tick.
- **Pros**: No client math.
- **Cons**: Snapshots are unreliable and arrive late, so the owner's view lags or jitters behind its own mouse; violates "state-changing facts never travel unreliably".
- **Rejection Reason**: The view is the most latency-sensitive thing a player sees.

### Alternative 2: Reset by zeroing on the server at once
- **Description**: On reset the server zeroes the offset and tells the client to add it into yaw.
- **Pros**: No epoch.
- **Cons**: Frames already in flight still carry the old yaw, so the server view jumps by the offset for one round trip; the aim ray is wrong exactly when the player reacts.
- **Rejection Reason**: Fails Verification 2.

### Alternative 3: Post-processing flashes through a `Compositor` effect
- **Description**: A compositor pass brightens the frame.
- **Pros**: Physically nicer flash.
- **Cons**: More engine risk; needs a shader per effect; a `ColorRect` meets the design.
- **Rejection Reason**: Not needed; revisit if art direction asks for it.

## Consequences

### Positive
- The flinch costs one reliable message and stays tick-exact.
- One flash cap for every source.

### Negative
- Four more bytes per input frame (`view_epoch`, `offset_tick`, `record_id`).
- `FlinchRequested` and `ViewOffsetChanged` are two new events in the catalog.

## Risks
- **Tick estimate error makes the owner's ramp lead or lag.** Mitigation: the ramp is 0.3 s and smooth; Verification 1 measures the error.
- **Epoch wrap.** Mitigation: resets are rare (seconds apart); the server keeps four epochs and an 8-bit epoch cannot wrap within one round trip.
- **Verification comparisons across the ±π seam.** Mitigation: compare yaw with `angle_difference()`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| scare-events.md | TR-scare-006, rules 13–14: server-held offset, 0.3 s ramp, 10° cap, replace not stack, lunge freeze, toggle | §1–4 |
| scare-events.md | TR-scare-009, rules 24–29: flash scale, 3/s cap, flinch toggle, parity, hooks never change server timing | §4–6 |
| scare-events.md | TR-scare-012: stingers, flash, camera reaction, impossible surveillance frame | §5, §7 (beacons and strobe stay ADR-0009) |
| first-person-controller.md | TR-controller-010, rules 7 and 9: other camera effects are client-only; re-baseline with no snap | §3, §5 |
| systems-index.md | TR-index-008: Scare Events writes, Controller applies and resets; toggle client-set, server-held | §1, §4 |

## Performance Implications
- **CPU**: One pure function per tick per flinched player; negligible.
- **Memory**: One record per player.
- **Load Time**: `ScareCatalog` loaded with the map.
- **Network**: One reliable message per flinch or reset; four bytes per input frame.

## Migration Plan
No code exists yet.

## Validation Criteria
- Unit test: `offset_at` at start, mid-ramp (strictly between from and target) and after the ramp, and with `ramp_ticks = 0`; a replacing flinch starts from the current offset.
- Integration: with 150 ms simulated latency, a flinch, a replacing flinch while the first ramps, and then a reset keep server and client view direction within 0.5° on every tick.
- Four flash sources fired in one second produce three flashes and one dim.

## Related
- ADR-0002 (input frame, view direction), ADR-0004 (projection), ADR-0005 (events, views), ADR-0009 (flicker clamp, feed), ADR-0013 (stingers), ADR-0014 (layers, P8)
- `design/gdd/scare-events.md` rules 13–29; `design/gdd/first-person-controller.md` rules 7, 9; `design/accessibility-requirements.md` Reduced motion, Photosensitivity
