# ADR-0002: Authoritative Simulation, Tick Rate and Input Handling

## Status
Proposed

## Date
2026-10-12

## Last Verified
2026-10-12

## Decision Makers
SneakKestrel16 (designer), with `godot-specialist` engine validation. TD-ADR skipped — Lean mode.

## Summary
Every GDD rule assumes a server that simulates the round and a client that only sends intent, but nothing fixed the tick rate, the input path, or how the owning client stays responsive. The decision: a 60 Hz server tick driven by one TickRunner, unreliable redundant input frames into an adaptive 1–2 frame queue per player, unreliable per-peer snapshots every tick, and owner-only client prediction with replay-based reconciliation.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Networking, Physics |
| **Knowledge Risk** | HIGH (post-cutoff version; Jolt default since 4.6; `modules/networking.md` and `modules/physics.md` are 4.6 snapshots) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/networking.md`, `modules/physics.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; `prototypes/networking-spike/README.md` and `main.gd` (run on 4.7.2) |
| **Post-Cutoff APIs Used** | Jolt as the default 3D engine (4.6). 3D physics interpolation moved to SceneTree in 4.5 (API unchanged per the reference) |
| **Verification Required** | (1) ENet head-of-line behaviour between reliable and unreliable traffic, and that separate `@rpc` transfer channels avoid it. (2) `Engine.max_physics_steps_per_frame` default and behaviour on a slow host. (3) `Node3D.reset_physics_interpolation()` on 4.7.2. (4) `move_and_slide` called several times in one `_physics_process` with gravity and floor snapping (the spike replayed only flat, y-pinned movement). (5) Jolt result drift between host and client for identical input (no cross-machine determinism guarantee is documented). (6) Packet size of a full 6-player snapshot against ENet fragmentation |

**API coverage.** In the repo reference: ENet, `@rpc` modes, `CharacterBody3D.move_and_slide`, Jolt as default. Exercised by the spike on 4.7.2: setting `Engine.physics_ticks_per_second` at boot, `_physics_process` as the server tick, unreliable RPCs carrying `PackedInt32Array` / `PackedVector2Array` / `PackedByteArray` / `PackedVector3Array` / `PackedFloat32Array`, several `move_and_slide` calls in one physics frame, a server that consumes two inputs in one tick, and a client tick estimate. Training data only: everything under Verification Required.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Proposed): state keyed by player ID; host input through the same queue; `server_relay = false` |
| **Enables** | ADR-0003 (lag compensation and rewind budget), ADR-0004 (replication scope and information hiding), ADR-0005 (event catalog, state registry and tick order), ADR-0007 (movement, physics and collision layers) |
| **Blocks** | First-Person Controller implementation; every Feature system's server logic |
| **Ordering Note** | ADR-0005 defines the order of Feature modules inside the tick phase this ADR reserves for them. ADR-0003 owns the interpolation delay and rewind budget. Acceptance waits on the spike's deferred clock-drift and Wi-Fi tests |

## Context

### Problem Statement
`first-person-controller.md` rule 9 says the client sends intent only, the server owns every position and "the owning client predicts and reconciles", and it leaves the method to a Network Authority ADR. Every other GDD expresses timing in server ticks (±1 tick tolerances). Without one tick loop and one input path, each system would invent its own and the same-tick ordering rules in `architecture.md` could not hold.

### Constraints
- Listen server (ADR-0001): the host's machine runs the simulation and a player.
- 4–6 players; PC first.
- Jolt `CharacterBody3D` capsules (`first-person-controller.md` rule 1).
- One developer: no custom transport, no delta-compression system before it is needed.

### Requirements
- Movement responds within one frame on the owning client (controller Game Feel: client-predicted).
- Client sends intent only: move vector, sprint and crouch, yaw and pitch, interaction start and stop (controller rule 9).
- Server view direction is client yaw/pitch plus the server-held view offset, pitch clamped to ±85° (controller rules 7, 9, 10).
- No intent for `intent_timeout_ms` = 500 releases input and cancels holds (controller edge cases, AC).
- Corrections under 1 m are smoothed over 100 ms; larger ones snap (controller Game Feel).
- A player found inside geometry returns to their last valid position (controller edge cases).
- All clients agree on state within the GDDs' 200–250 ms windows (match-flow, downing-and-rescue, borrowed-face ACs).

## Decision

**1. One server clock, in ticks.** The server advances an integer `server_tick` once per `_physics_process`. `Engine.physics_ticks_per_second` is set once at boot from data (`sim_tick_hz` = 60) and never changed during a session. Every rule timer counts ticks; no rule reads the wall clock. Server time in seconds is `server_tick / sim_tick_hz`.

**2. One TickRunner.** A single server-side `TickRunner` node runs each tick in fixed phases:

1. dequeue one input frame per player (rule 4);
2. movement: apply each player's frame through the Controller's movement step;
3. push positions into the snapshot history (used by ADR-0003);
4. Feature modules' `server_tick(tick)`, in the order ADR-0005 defines;
5. flush the event queue;
6. build and send per-peer snapshots (rule 5).

Feature modules must not run rules from their own `_physics_process`.

**3. Intent transport.** Every physics tick the client sends one unreliable RPC to the server holding its last 3 input frames, as packed arrays: `seq` (`PackedInt32Array`), `move` (`PackedVector2Array`), flags (`PackedByteArray`: sprint, crouch), `yaw` and `pitch` (`PackedFloat32Array`). Discrete intents (interaction start and stop, item use, ping, callout) go by a reliable RPC carrying the `seq` of the frame they belong to, so the server applies them on the same tick as that frame.

Traffic uses three transfer channels, so unreliable input or state never waits behind a lost reliable packet:
- input frames;
- snapshots;
- reliable intents and events.

**4. Server input queue (per player ID).**
- **Validation.** All arrays must have equal length and at most 3 entries, and every float must be finite; otherwise the whole packet is dropped. `move` is clamped to length 1 and pitch to ±85°. Already-seen or out-of-order `seq` values are dropped. A `seq` more than `max_seq_ahead` beyond the last consumed is rejected.
- **Consumption.** The queue has an adaptive target depth of 1 or 2 frames. It normally consumes one frame per tick, and two when the backlog exceeds target + 1.
- **Adaptation.** The target rises to 2 when starvation over a `starvation_window_s` = 2 window exceeds `starvation_high`, and falls back to 1 below `starvation_low`.
- **Starvation.** The last frame repeats. After `intent_timeout_ms` = 500 with no frame, input is treated as released and holds are cancelled.
- **Cap.** The queue is hard-capped at `input_queue_cap` frames and drops the oldest. If the host falls behind real time, everyone slows together and rule timers stay consistent, because they count ticks.
- **Host.** The host's own player enqueues directly at depth 0, with no prediction: the server body is its body. This is the same queue, so ADR-0001's no-shortcut rule holds.

The client never sends position, speed or progress.

**5. Snapshots.** Every tick the server sends each peer one unreliable snapshot stamped with `server_tick`. It carries every player visible to that peer (position, yaw, gait; filtering is ADR-0004's). For the receiving player's own body it also carries the last consumed `seq`, the authoritative position and velocity, and the on-floor flag and floor normal. State-changing facts never travel in snapshots; they are reliable events (`architecture.md`, Data Flow).

**6. Owner-only prediction and reconciliation.** The owning client runs the same movement step as the server on its own `CharacterBody3D`, and keeps every frame the server has not yet acknowledged.

On each snapshot the client:
1. restores the server's position, velocity and floor state at the acknowledged `seq`;
2. replays the unacknowledged frames inside `_physics_process`;
3. corrects only if the replayed position differs from the predicted one by more than `correction_deadzone_m` = 0.001.

How a correction shows:
- Under `correction_smooth_max_m` = 1.0, it is hidden by an offset on a non-interpolated visual child that decays over `correction_smooth_s` = 0.1.
- At or above that, the body snaps and `reset_physics_interpolation()` is called.

Scope of prediction:
- Predicted movement collides only with static geometry. Doors and other players are corrected by the server.
- Movement modifiers (root, slow, lock) are predicted from the latest replicated registry state, so the first tick of a new modifier may be corrected.
- Only the owner's own movement is predicted. Hold bars are UI prediction only and the server confirms them (controller rule 13).

**7. Client tick estimate.** The client estimates the current server tick from the stamped snapshots with a smoothed offset, filtered toward the lowest observed round trip, so bursty arrival from a slow host does not jerk it. There is no separate clock-sync protocol.

**8. Rendering above 60 fps.** The local body uses physics interpolation. Camera yaw and pitch render at frame rate from local input, not from physics.

**9. Invalid positions.** The "last valid position" is the player's position at the end of the most recent tick in which the capsule overlapped no static geometry. A player found inside geometry is restored to it, and the owner receives it through the snap path.

### Architecture Diagram

```
CLIENT (owner)                                 SERVER (TickRunner, 60 Hz)
 sample input ─▶ frame{seq,move,flags,yaw,pitch}
   │  predict: movement step on own body        1 dequeue (adaptive 1–2, cap)
   │  keep unacked frames                       2 movement step per player
   └─▶ ch.input  unreliable, last 3 frames ───▶ 3 snapshot history
       ch.event  reliable discrete intents ───▶ 4 Feature server_tick (ADR-0005)
                                                5 flush events
 reconcile ◀── ch.state unreliable snapshot ◀── 6 per-peer snapshot (ADR-0004)
   restore acked state, replay, deadzone,
   smooth < 1 m / snap ≥ 1 m
```

### Key Interfaces

```gdscript
class_name InputFrame extends RefCounted
var seq: int
var move: Vector2          # length ≤ 1 after server clamp
var sprint: bool
var crouch: bool
var yaw: float
var pitch: float           # clamped to ±85° by the server
var view_tick: float       # added by ADR-0003: server tick the client was rendering remote players at
var ack_snapshot_tick: int # added by ADR-0003: newest snapshot received; server measures RTT from it

class_name TickRunner extends Node
signal tick_started(tick: int)
func current_tick() -> int
func register_feature(module: Object, phase_order: int) -> void   # order set by ADR-0005

# Controller movement step, used by the server and the owning client alike.
# Runs inside _physics_process; move_and_slide uses the physics delta.
func apply_move(body: CharacterBody3D, frame: InputFrame, modifiers: MovementModifiers) -> void

class_name InputQueue extends RefCounted
func push(frames: Array[InputFrame]) -> void
func next(tick: int) -> InputFrame   # repeats last on starvation; released after intent_timeout_ms
```

### Implementation Guidelines
- Rule logic **must** run from `TickRunner` phases. A Feature module **must never** run rules in its own `_physics_process`.
- Rule timers **must** count server ticks. They **must never** read `Time` or the wall clock.
- `Engine.physics_ticks_per_second` **must** be set once at boot from data.
- Input RPC handlers **must** validate array lengths, the 3-frame limit and finiteness before reading any element.
- Clients **must never** send position, velocity, speed or progress.
- Snapshots **must never** carry a state-changing fact. Those **must** travel as reliable events.
- Input, state and events **must** use separate transfer channels.
- The movement step **must** be one function shared by server and client. Client-only movement code is forbidden.
- Every snap **must** call `reset_physics_interpolation()`.
- `sim_tick_hz`, `intent_timeout_ms`, queue depths and cap, starvation thresholds and window, `max_seq_ahead`, `correction_deadzone_m`, `correction_smooth_max_m` and `correction_smooth_s` **must** come from data.

## Alternatives Considered

### Alternative 1: Client-authoritative movement with server plausibility checks
- **Description**: Clients move themselves and send positions; the server rejects implausible ones.
- **Pros**: No reconciliation code; zero correction artefacts.
- **Cons**: Speed and teleport cheats slip under any tolerance; position becomes a client claim, against controller rule 9.
- **Rejection Reason**: Contradicts the server-authority rule every GDD depends on.

### Alternative 2: Deterministic lockstep
- **Description**: All machines simulate the same inputs in lockstep.
- **Pros**: Tiny bandwidth.
- **Cons**: One late peer stalls everyone; needs bit-exact cross-machine determinism, which Jolt does not document.
- **Rejection Reason**: Unverifiable determinism and a poor fit for real-time horror with 4–6 home connections.

### Alternative 3: 30 Hz simulation
- **Description**: Simulate and send at 30 Hz.
- **Pros**: Half the bandwidth (spike: about 44 kbps per client).
- **Cons**: Spike snaps grew to about 0.29 m and corrections rose at 150 ms RTT; a 0.3 s lunge dash gets 9 hit checks instead of 18.
- **Rejection Reason**: Designer decision 2026-10-12: 60 Hz. The snapshot rate may drop to 30 Hz later if real-network tests show upload pressure; the simulation stays at 60.

### Alternative 4: `MultiplayerSynchronizer` for owner movement
- **Description**: Replicate positions with the built-in synchronizer.
- **Pros**: No custom snapshot code.
- **Cons**: No input prediction or replay; the owner would feel the full round trip.
- **Rejection Reason**: Fails the one-frame movement response. The synchronizer stays available for per-peer entity visibility (ADR-0004).

## Consequences

### Positive
- Movement feels local at any supported latency (spike H1: 99%+ of states matched).
- One tick loop makes same-tick ordering rules enforceable.
- Bandwidth fits a home upload with margin (spike: about 87 kbps per client, about 0.52 Mbps total at 60 Hz with minimal state).
- A slow host slows the game evenly instead of desynchronising rule timers.

### Negative
- Custom snapshot and reconciliation code to own and test.
- The host plays with zero input latency; remote players carry a 1–2 frame buffer.
- Collisions with doors and other players are not predicted, so the owner sees small corrections there.
- A host that cannot hold 60 Hz slows everyone.

## Risks
- **Floor and step replay untested.** The spike pinned y with no gravity. Mitigation: an integration test replaying frames over the 0.35 m step and 40° ramp from the controller ACs before Acceptance.
- **Jolt drift between machines.** Mitigation: the correction deadzone; log correction rates.
- **Snapshot size growth.** Real state (life state, form, items) adds to the spike's minimal payload. Mitigation: measure once Feature state exists; delta compression or a 30 Hz snapshot rate are the fallbacks.
- **Clock drift over a 9-minute round.** Untested (spike deferred list). Mitigation: the adaptive buffer and queue cap; rerun on two machines.
- **ENet channel behaviour unverified.** Mitigation: a loss-injection test showing input still flows while a reliable packet is lost.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| first-person-controller.md | Rule 9: client sends intent only; server owns positions; owning client predicts and reconciles; method deferred to this ADR | Decisions 3–6 |
| first-person-controller.md | Rules 7, 10: server view direction = yaw/pitch + view offset, pitch clamped ±85° | Decision 4 clamps pitch; the frame carries yaw and pitch; the Controller adds the offset in the movement phase |
| first-person-controller.md | Edge case and AC: no intent for 500 ms releases input and cancels holds (±1 tick) | Decision 4 |
| first-person-controller.md | Game Feel: move input to local motion within 1 frame; corrections under 1 m smoothed over 100 ms, larger snap | Decision 6 |
| first-person-controller.md | Edge case and AC: a player inside geometry returns to the last valid position | Decision 9 |
| first-person-controller.md | AC: a modified client sending a position, excessive speed or progress changes nothing | Decisions 3–4: no such fields exist; the server computes them |
| match-flow.md | Rule 4: round clock runs on the server only | Decision 1 |
| downing-and-rescue.md, borrowed-face.md, survivor-objectives.md | Timers with ±1 tick tolerances | Decision 1: every rule timer counts ticks |
| systems-index.md | Server is authoritative for attacks, stuns, cooldowns, objectives, downing, rescue and results | Decision 2: all rules run in TickRunner phases on the server |

## Performance Implications
- **CPU**: Spike: about 0.055 ms per tick for 6 capsules plus about 0.1 ms to send, under 2% of a 16.6 ms frame. Client replay costs up to (RTT / 16.7 ms) extra movement steps per snapshot for one body.
- **Memory**: Per player: up to `input_queue_cap` frames on the server and unacknowledged frames on the client (about 15 at 250 ms RTT).
- **Load Time**: None.
- **Network**: About 87 kbps host upload per client at 60 Hz with minimal state (spike), plus real state to be measured; client upload about 40 kbps.

## Migration Plan
No production code exists. The spike is reference only and is rewritten to production standards (`.claude/rules/prototype-code.md`).

## Validation Criteria
- Controller ACs for intent timeout, invalid client input and inside-geometry restore pass.
- An integration test with 5 clients at a simulated 150 ms RTT, 30 ms jitter and 2% loss shows: owner correction rate at or below the spike's (53 of 5022 states); snaps under 0.35 m p95; input flowing while a reliable packet is lost.
- A replay test over the controller's step and ramp geometry shows no snap on a clean link.
- A malformed input RPC (mismatched lengths, more than 3 frames, NaN) changes nothing and is logged.
- The host and a remote client complete the same scripted route with identical server-side positions.

## Related
- ADR-0001 — hosting, session and identity (depends on)
- ADR-0003 — rewind budget and interpolation delay (not yet written)
- ADR-0004 — replication scope (not yet written)
- ADR-0005 — tick order of Feature modules (not yet written)
- `docs/architecture/architecture.md` — Data Flow, Required ADR 2
- `design/gdd/first-person-controller.md`, `design/gdd/match-flow.md`
- `prototypes/networking-spike/README.md` (H1, H2)
