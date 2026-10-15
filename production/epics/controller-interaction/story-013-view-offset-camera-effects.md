# Story 013: Flinch view offset and client-only camera effects

> **Epic**: First-Person Controller & Interaction
> **Status**: In Progress
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]


## Context

The scare flinch is the one sanctioned server-side view change; every other camera effect is a client-side visual offset that never moves the aim ray.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-006`, `TR-controller-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015: Scare presentation and view offset (primary, Proposed); ADR-0002: Authoritative simulation, tick and input §8
**ADR Decision Summary**: Flinch record and view-offset epoch held on the server and added to client yaw/pitch, ramped in within 0.3 s; offsets replace, not sum; re-baseline (no snap) on reset events; camera shake, jitter and jolt are client-only `Node3D` camera-child effects.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: ADR-0015: plain GDScript on ADR-0002's frame; `CanvasLayer`, `ColorRect` and a `Node3D` camera child, none changed post-cutoff.

**Control Manifest Rules (this layer)**:
- Required: (Proposed) view offset rules per ADR-0015 — re-check the control manifest once it is Accepted

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (Look and view ray: flinch criteria), scoped to this story:*

- [ ] The downing camera impact and shake and the survivor-defense jitter and jolt leave the server view direction and aim ray unchanged.
- [ ] A flinch for a toggled-on player makes the server view direction equal client yaw/pitch plus the offset within 0.3 s and keeps it; for a toggled-off player the view direction never changes; no flinch starts during a lunge wind-up.
- [ ] A second flinch replaces the offset (ramp from current to new target, at most `flinch_max_angle_deg`), and a wind-up cancelling a running flinch freezes the offset.
- [ ] On round end, Downed, Hidden, Seized, reconnect or toggle-off, the offset re-baselines to 0 with no change in view direction on that tick; after a reconnect server and client agree on the first tick.

---

## Implementation Notes

*Derived from ADR-0015 (Proposed) and ADR-0002 §8:*

- Add the offset to `ViewState.server_dir` (Story 006).
- Do not start until ADR-0015 is Accepted; its interfaces may change.

---

## Out of Scope

- Scare event selection (Scare Events epic)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/first-person-controller/view_offset_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006; ADR-0015 Accepted
- Unlocks: Scare Events epic


## Progress Notes (2026-10-15)

Server side merged in `bc5b9b0`: `src/core/controller/view_offset.gd`, `src/foundation/network/flinch_record.gd`, `ViewState` applying the frame's own record, `record_id`/`offset_tick` on input frames, `ViewOffsetChanged` carrying the record. Mutations caught then: integer division in offset_at, newest record instead of the frame's, toggle check removed, offset stacking.

Finished on branch `wt-ci13b` (commits `e7e497d`, `8e3dafd`, `35bd52f`, `b319106`):

- **AD-210 resolved as "implement as written".** Input frames carry `view_epoch` (a byte; `InputFrame`, `InputQueue`, packet key `view_epoch`). A reset ends the epoch with the held offset as its base, starts the next epoch and sends a zero record with `rebaseline = true` and `fold` = the held offset. A frame stamped with an old epoch gets its own record up to that epoch's reset tick and the held offset after it, so the server never zeroes an offset outside the handshake. A frame with an unknown epoch reads as the current one. The record-id-only rebaseline is gone.
- **Reconnect.** The server restarts the player on epoch 0 and record 0, the stamps a fresh client sends, and sends that record as a re-baseline carrying the held offset. The flinch toggle survives the reconnect. Previously `_players.erase()` dropped it.
- **Client fold and stamping (`LocalInput`).** `on_view_offset(tick, payload)` is the `ClientEventRouter` handler. It folds a re-baseline whose record id it has not adopted into yaw and pitch, with pitch clamped on the sum. `view_yaw(est)`/`view_pitch(est)` are for the camera. `sample(offset_tick)` stamps `record_id`, `view_epoch` and `offset_tick`. `ClientEventRouter` needed no change: subscribing is enough. `FlinchRecord.from_dict` validates the payload.
- **Spectators.** `ServerMovement` already projects a spectator's event batch as the watched survivor, so `ViewOffsetChanged` reaches spectators. `ViewOffset.resend(survivor)` covers a switch mid-hold, and the round composer's watch hook (`RoundComposer._watch`) calls it. The resend is idempotent for the owner, because the same record id is never folded twice.
- **Flinch toggle.** The client sends `NetAuthority.flinch_packet(on)` reliably on join and on change. The server keeps the value in the session (off for unknown players, per ADR-0015 §4) and raises `flinch_enabled_changed`. `PlayerSettingsView.is_flinch_enabled()` is registered under `StateKeys.CAMERA_FLINCH_TOGGLE`. The composer seeds `ViewOffset` from NetAuthority at round start and forwards changes.
- **`CameraFx`** (`src/core/controller/camera_fx.gd`): shake, jitter and jolt on a `Node3D` between the head and the `Camera3D`, with interpolation off. `enabled` is the camera-impact shake setting. It never touches the sampled yaw and pitch.
- **`ScarePresenter`** and **`FlashLimiter`** (`src/feature/scare_events/`): an additive flash on layer 3 (SCARE_FX), scaled by `flash_scale`; a 0.4 s dim at scale 0 or over `facility.max_flashes_per_s`; the camera reaction through `CameraFx`.

Tests:
- `tests/unit/first-person-controller/view_offset_test.gd` (22): the reconnect first-tick agreement, old-epoch frames during a re-baseline, a second reset mid-handshake, and owner and server agreeing every tick with records 3 ticks late.
- `camera_fx_test.gd` (5).
- `tests/unit/scare-events/scare_presenter_test.gd` (5).
- `tests/unit/network/player_settings_test.gd` (4).
- A wiring check in `round_composer_test.gd`.

Full suite: 1176 cases, 1175 passed, no leak lines. The one failure was `prediction_reconcile_test` five-client: `host()` returned `ERR_CANT_CREATE` at bind, because its fixed sequential ports clashed with a parallel agent's run. Alone it passes 9/9.

Mutations caught:
1. An old epoch not clamped to its reset tick.
2. No old-epoch base.
3. Reconnect done as an ordinary re-baseline.
4. No client fold.
5. `record_id` not stamped.
6. Folding an already-adopted record.
7. The composer not forwarding the toggle.
8. The limiter window boundary.
9. The shake setting ignored.
10. A flash at scale 0.

Deviations (inference marked):
- `offset_tick` is still a full int32, not 16 bits.
- The ADR's key `player_settings` and getter `flinch_enabled()` became the existing `camera_flinch_toggle` row and `is_flinch_enabled()`, because views name getters `get_`/`is_`/`has_`.
- The ADR's `set_flinch_enabled` RPC is a byte-matched reliable packet, the project's pattern for client requests (lobby Ready, flashlight). Like those, it also reaches ServerMovement's input queue, which drops it.
- Inference: the dim is as dark as the flash peak; nothing sources its depth.
- Inference: a reconnecting client builds a fresh `LocalInput`. A client that keeps its `LocalInput` still folds rather than snaps, but its first frames after a reconnect that follows an epoch change read with no offset for one round trip.
- Effect sizes for shake, jitter and jolt are the caller's data. The GDDs give durations only, so no knob was added.
- `ScareTriggered` projects only `scope`. `ScarePresenter.on_scare()` looks up a `scare` id that Scare Events must add, together with `ScareCatalog`. Until then it plays nothing.
- The stinger and the P8 edge pulse are not built: they need AudioDirector and UiLayers.

Client scene wiring (`round_client.gd` belongs to another agent; this is what it needs):
- **Node chain.** Body → head `Node3D` → `CameraFx` → `Camera3D`. The head and the `Camera3D` set `physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF`.
- **Every rendered frame.** Set `head.rotation = Vector3(li.view_pitch(est), li.view_yaw(est), 0)`, where `est = predictor.estimator.estimated_server_tick(predictor.local_tick() + frame_fraction)`.
- **Every physics tick.** Call `predictor.predict(li.sample(int(est)))`. Pass 0 while `estimator.has_estimate()` is false.
- **Router subscriptions.** `router.subscribe(&"ViewOffsetChanged", li.on_view_offset)`. Then `var sp := ScarePresenter.new(FlashLimiter.new(knobs.facility.max_flashes_per_s), camera_fx, catalog)`, `add_child(sp)` and `router.subscribe(&"ScareTriggered", sp.on_scare)`.
- **Settings.** `sp.flash_scale` and `camera_fx.enabled` come from the accessibility settings.
- **Toggle.** After the join is accepted, and on every change, call `multiplayer.send_bytes(NetAuthority.flinch_packet(on), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE)`. The host's own player calls `net.set_flinch_enabled(id, on)` instead.
- **Spectator camera.** Use the watched survivor's snapshot yaw plus `FlinchRecord.offset_at(FlinchRecord.from_dict(payload), est)` from the same `ViewOffsetChanged` subscription, with no fold. The snapshot carries no pitch today.
- **Downing and Survivor Defense presenters.** They call `camera_fx.jolt()`, `camera_fx.shake()` and `camera_fx.jitter()` with their own data.

Remaining:
- Screenshot evidence is deferred until the client scene lands (run-and-observe: a flinch, a reset, a flash and a dim, the shake).
- ADR-0015 Verification 1-4.
- The story stays In Progress.
