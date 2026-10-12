# ADR-0003: Lag Compensation and Rewind Budget

## Status
Proposed

## Date
2026-10-12

## Last Verified
2026-10-12

## Decision Makers
SneakKestrel16 (designer), with `godot-specialist` engine validation. TD-ADR skipped — Lean mode.

## Summary
The lunge and the taser must hit what the attacker saw. The networking spike showed the rewind needed for that is about RTT + interpolation delay + one tick, well above the 150 ms cap `monster-abilities.md` assumed. The decision: remote players render 50 ms behind, the server rewinds target positions to the tick the attacker was viewing, capped at 180 ms so the lunge dodge window still holds, and all hit tests run analytically against a rewound history.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Networking, Physics |
| **Knowledge Risk** | HIGH (post-cutoff version; Jolt default since 4.6; `modules/physics.md` and `modules/networking.md` are 4.6 snapshots) |
| **References Consulted** | `docs/engine-reference/godot/modules/physics.md`, `modules/networking.md`, `breaking-changes.md`, `deprecated-apis.md`; `prototypes/networking-spike/README.md` (H3) and `main.gd` (`_interp_hist`) |
| **Post-Cutoff APIs Used** | None introduced after 4.3. Queries run against the Jolt 3D space (default since 4.6) |
| **Verification Required** | (1) `PhysicsRayQueryParameters3D` defaults on 4.7.2 with Jolt (`hit_from_inside`, `hit_back_faces`, `collide_with_areas`; training data only). (2) A 180 ms cap and 16-tick ring against measured rewind on a real network (the spike measured with a 150 ms cap and 100 ms interpolation). (3) Remote-player smoothness at 50 ms interpolation under 2% loss and 30 ms jitter (3 snapshots of buffer). (4) The pursuit simulation rerun at a 0.43 s strafe start (see Risks) |

**API coverage.** In the repo reference: `PhysicsDirectSpaceState3D.intersect_ray`, `PhysicsRayQueryParameters3D.create`, `collision_mask`, `CharacterBody3D`. Spike-verified on 4.7.2: an interpolated position history and rewind probe (`_interp_hist`, 150 ms cap). Training data only: ray query defaults, and that `direct_space_state` is safe to query inside `_physics_process`.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Proposed): 60 Hz TickRunner, `InputFrame`, snapshot history phase, per-peer snapshots |
| **Enables** | ADR-0007 (movement, physics and collision layers): collision layers for static geometry |
| **Blocks** | Monster Abilities Predatory Lunge hit validation; Survivor Defense taser hit-scan |
| **Ordering Note** | Acceptance waits on the spike's real-network tests and on the pursuit simulation rerun at 0.43 s. This ADR amends ADR-0002's `InputFrame` (adds `view_tick` and `ack_snapshot_tick`) |

## Context

### Problem Statement
`monster-abilities.md` rule 7 rewinds survivor positions by the attacker's latency up to `max_rewind_ms` = 150 and derives its dodge window from that number. The networking spike (H3) measured the rewind needed to reproduce what the attacker saw: 103, 160, 210 and 260 ms at 0, 50, 100 and 150 ms RTT with a 100 ms interpolation delay. That matches **full RTT + interpolation + about one tick**: the snapshot travels to the attacker, then the attack travels back. (The spike README's prose says "one-way latency"; its measured numbers say full RTT, and this ADR follows the data.) With the 150 ms cap, the capped error was 0.08 m p95 at 50 ms RTT, 0.35 m at 100 and 0.60 m at 150, against a 1.2 m hit radius.

### Constraints
- The dodge window (`monster-abilities.md`, Formulas): a survivor who starts strafing `0.25 s + max_rewind_ms` after the lunge cue must not be hit. Under the governing steering-pursuit model the latest safe strafe start is about 0.49 s. `first-person-controller.md` notes that figure ignores acceleration; with `accel_time_s` = 0.05 the effective latest start is about 0.465 s (inference from the GDD's own figures).
- 60 Hz simulation and snapshots (ADR-0002).
- Doors toggle instantly and block lunges and line of sight (`survivor-defense.md`, `first-person-controller.md` rule 18).

### Requirements
- The lunge hit check uses rewound survivor positions; eligibility, hiding, grace and stun use current state (`monster-abilities.md` rule 7).
- At most one survivor is hit per lunge, the closest on the first qualifying tick (rule 8).
- The taser shot hits the first body on its path, passes through Seized and Downed survivors, and is blocked by geometry (`survivor-defense.md` rule 8).
- Clamped rewinds are logged as disputes (rule 7, Match Telemetry).

## Decision

**1. Interpolation delay.** Clients render remote players `interp_delay_ms` = 50 (3 snapshots at 60 Hz) behind their estimated server tick. On a missing snapshot they extrapolate for up to `max_extrapolation_ms` = 50, then hold the last position.

**2. The client reports what it was viewing.** Each `InputFrame` (ADR-0002) gains:
- `view_tick: float` — the server tick at which the client was rendering remote players when it sampled the frame;
- `ack_snapshot_tick: int` — the newest snapshot tick it had received.

**3. Rewind amount.** For a hit test on server tick `T` by attacker `A`:

```
view_lag   = T - view_tick                          # from A's latest received frame
rtt_bound  = (T - ack_snapshot_tick) + interp_ticks + 2 + slack_ticks   # server-measured
rewind     = clamp(view_lag, 0, min(cap_ticks, rtt_bound))
```

`cap_ticks` is `max_rewind_ms` = 180 ms (10.8 ticks). A non-finite `view_tick`, or one ahead of `T`, is rejected and the rewind is 0. The `rtt_bound` stops a client from claiming more latency than the server measures. Each tick of the 0.3 s dash uses the latest frame received from the attacker. When the clamp reduces the rewind, the server logs a dispute (attacker, tick, requested and applied rewind).

**4. History.** In ADR-0002's snapshot-history phase the server pushes, per player and per tick: position, capsule height and radius, and the chest point. It keeps `history_ticks` = 16 (267 ms). A rewound position at a fractional tick is interpolated between the two bracketing ticks. If no bracket exists, the result is an explicit "out of history" and current positions are used and logged.

**5. What is rewound.** Only target positions. The attacker's own position, every eligibility rule (Healthy, hidden, grace, Seized), stun state and door and barricade state are current.

**6. Analytic hit tests.** No physics body is moved for a test.
- **Targets.** Distance and cone checks against rewound capsules are computed in GDScript. The capsule segment half-length is `height / 2 - radius`.
- **Walls.** Line of sight to static walls uses `intersect_ray` with a `collision_mask` limited to static geometry; player bodies, doors and areas are excluded. Rays start at the eye or chest point, never inside a collider.
- **Doors and barricades.** They are tested analytically as boxes built from the Facility Map's authoritative open, closed and barricaded state. This avoids any same-tick lag between a door toggle and the physics space.
- **Lunge.** Each tick of Active, the GDD's rule 7 test runs against rewound capsules, analytic door boxes and the wall ray; the closest qualifying survivor is hit.
- **Taser.** The shot ray is tested against each rewound capsule (skipping Seized and Downed survivors), the analytic door boxes and the wall ray. The nearest hit along the ray wins. `stun_aim_tolerance_deg` widens the target test for aim imprecision only.

**7. Dodge budget.** `survivor_reaction_s` = 0.25 s + 0.18 s = 0.43 s. Full compensation reaches about 113 ms RTT (180 − 50 − 17). Above that, hits are checked against slightly newer positions than the attacker saw, and the dispute log records it.

### Architecture Diagram

```
CLIENT A (attacker)                     SERVER tick T (TickRunner)
 render remotes at view_tick =          phase 3: push history[player][T] = {pos, h, r, chest}
   est_server_tick - 50 ms              phase 4: Monster Abilities / Survivor Defense
 InputFrame{..., view_tick,                rewind = clamp(T - view_tick, 0,
            ack_snapshot_tick} ───────▶            min(180 ms, rtt_bound))
                                           targets = history.at(T - rewind)   (interpolated)
                                           test: analytic capsules + analytic door boxes
                                                 + intersect_ray(static walls only)
                                           eligibility, stun, doors: CURRENT state
                                           clamp applied? → dispute log
```

### Key Interfaces

```gdscript
# Added to ADR-0002's InputFrame
var view_tick: float          # server tick the client was rendering remote players at
var ack_snapshot_tick: int    # newest snapshot tick received

class_name RewindHistory extends RefCounted
func push(tick: int, player_id: int, pos: Vector3, height: float, radius: float, chest: Vector3) -> void
func sample(player_id: int, tick: float) -> Dictionary   # {ok: bool, pos, height, radius, chest}; ok = false when out of history

class_name LagCompensation extends RefCounted
func rewind_ticks(attacker_id: int, tick: int) -> float    # clamped; logs disputes
func capsule_hits_segment(...)                             # analytic helpers, pure functions
func ray_first_hit(origin: Vector3, dir: Vector3, max_dist: float, targets: Array, skip: Callable) -> Dictionary
```

### Implementation Guidelines
- Every server hit test **must** go through `LagCompensation`. Lunge and taser **must** share it.
- Hit tests **must never** move a physics body or use `intersect_shape` to test players. Players are tested analytically against rewound history.
- Eligibility, stun, hiding, grace and door state **must** be read at the current tick, never rewound.
- `view_tick` **must** be rejected when non-finite or ahead of the server tick. The rewind **must** be clamped by the server-measured RTT bound.
- World rays **must** use a mask of static geometry only. Doors and barricades **must** be tested from authoritative state.
- `interp_delay_ms`, `max_extrapolation_ms`, `max_rewind_ms`, `history_ticks` and `slack_ticks` **must** come from data.

## Alternatives Considered

### Alternative 1: 100 ms interpolation, 240 ms cap
- **Description**: Keep the spike's interpolation and raise the cap to the dodge ceiling.
- **Pros**: Smoother remote players.
- **Cons**: Full compensation only to about 130 ms RTT; dodge margin about zero, negative once acceleration is counted.
- **Rejection Reason**: Breaks the dodge window.

### Alternative 2: Keep the 150 ms cap
- **Description**: No GDD change.
- **Pros**: About 65 ms dodge margin.
- **Cons**: Full compensation only to about 83 ms RTT; spike error up to 0.60 m p95 at 150 ms RTT.
- **Rejection Reason**: High-ping monsters miss what they saw too often.

### Alternative 3: 50 ms interpolation, 210 ms cap
- **Description**: Full compensation to about 143 ms RTT.
- **Pros**: Fewer disputes at high ping.
- **Cons**: About 5 ms dodge margin once acceleration is counted.
- **Rejection Reason**: Designer decision 2026-10-12: 180 ms for a ~35 ms margin.

### Alternative 4: 260 ms cap with a lunge retune
- **Description**: Full compensation at 100 ms interpolation; lengthen the wind-up or cut turn rates to restore the dodge.
- **Pros**: No interpolation change.
- **Cons**: Reopens Monster Abilities tuning and every derived ceiling.
- **Rejection Reason**: Larger design change than the problem needs.

### Alternative 5: Taser without rewind (tolerance only)
- **Description**: Test the taser against current positions with a 10° tolerance.
- **Pros**: Simpler.
- **Cons**: Two lag models for two weapons; high-ping survivors miss what they aimed at.
- **Rejection Reason**: Designer decision 2026-10-12: one rewind path for every hit test.

## Consequences

### Positive
- Lunges and taser shots resolve against what the attacker saw, up to about 113 ms RTT.
- Survivors see the monster 50 ms sooner than with 100 ms interpolation, which helps their reaction budget.
- One analytic hit-test path, independent of physics-space timing.
- Disputes are logged with requested and applied rewind for tuning.

### Negative
- Only 3 snapshots of buffer: lossy links show more extrapolation and holds.
- Above about 113 ms RTT, attackers see some near-hits rejected.
- The dodge budget moves from 0.40 s to 0.43 s, so the GDD's worked ceilings must be recomputed.
- Analytic capsule and box tests are custom maths to own and test.

## Risks
- **Dodge margin (inference).** About 35 ms against a latest safe start of about 0.465 s with acceleration. Mitigation: rerun the pursuit simulation at 0.43 s with `accel_time_s` before Acceptance; recompute the safe-range ceilings in `monster-abilities.md`.
- **Remote stutter at 50 ms interpolation.** Mitigation: if the real-network test shows visible holds, move to 66 ms (4 snapshots); the cap then stays 180 and full compensation drops to about 97 ms RTT.
- **Clock drift.** `view_tick` relies on the client's tick estimate (ADR-0002). Mitigation: the server-measured `rtt_bound` caps any error.
- **Ray defaults on Jolt.** Mitigation: a test that fires a ray grazing a wall corner and one starting at a capsule's chest.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| monster-abilities.md | Rule 7: hit check on rewound positions, capped; eligibility and stun current; disputes logged | Decisions 3–6 |
| monster-abilities.md | Rule 8: at most one survivor, closest on the first qualifying tick | Decision 6 (lunge) |
| monster-abilities.md | Formulas, dodge window: survives a strafe at `0.25 s + max_rewind_ms` | Decision 7: cap 180 ms gives 0.43 s, inside the ~0.465 s latest safe start |
| monster-abilities.md | Open Question: rewind cap acceptable for the hosting model | Resolved by this ADR (180 ms with 50 ms interpolation, listen server per ADR-0001) |
| survivor-defense.md | Rule 8: first body on the path, pass through Seized and Downed, blocked by geometry, aim tolerance | Decision 6 (taser) |
| first-person-controller.md | Rule 18: doors toggle instantly and block | Decision 6: doors tested from authoritative state |
| first-person-controller.md | Monster Abilities dodge AC | Strafe start updated to 0.43 s alongside this ADR |

## Performance Implications
- **CPU**: A dash is about 18 ticks × (up to 5 capsule tests + 1 wall ray); a taser shot is one ray plus up to 5 capsule tests. Negligible against the 2 ms server-tick budget.
- **Memory**: 6 players × 16 ticks × about 40 bytes.
- **Load Time**: None.
- **Network**: About 8 bytes added to each input frame.

## Migration Plan
No production code exists. GDD values updated alongside this ADR: `monster-abilities.md` (`max_rewind_ms` 180, dodge budget 0.43 s, rule 7, ACs), `first-person-controller.md` (dodge AC 0.43 s), `survivor-defense.md` (rule 8 rewind). ADR-0002's `InputFrame` gains two fields.

## Validation Criteria
- Monster Abilities ACs: at 80 ms RTT, hit checks use positions at the attacker's view tick; at 300 ms RTT they are rewound 180 ms; a survivor who became hidden or entered grace after the rewound time is not hit.
- Controller dodge AC at 0.43 s passes over 20 seeds, rerun with `accel_time_s` 0.05.
- At 50, 100 and 150 ms simulated RTT, the full-rewind error is 0.00 m up to the cap and the capped error at 150 ms RTT is reported.
- A frame with a non-finite or future `view_tick` produces rewind 0 and a log entry.
- A taser shot through a Downed survivor stuns the monster behind; a shot at a closed door stops at the door.

## Related
- ADR-0002 — TickRunner, `InputFrame` (amended by this ADR)
- `docs/architecture/architecture.md` — Required ADR 3, Open Questions
- `design/gdd/monster-abilities.md`, `design/gdd/survivor-defense.md`, `design/gdd/first-person-controller.md`
- `prototypes/networking-spike/README.md` (H3)
