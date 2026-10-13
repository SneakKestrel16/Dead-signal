# ADR-0012: Objective Selection and Discovery (Server Sight Test)

## Status
Proposed

## Date
2026-10-12

## Last Verified
2026-10-12

## Decision Makers
Designer (SneakKestrel16), with Claude Code (`/architecture-decision`, autonomous mode, AD-40) and `godot-specialist` engine validation. TD-ADR skipped — Lean mode.

## Summary
Drive rooms and fuse spawns stay hidden from survivor clients until any survivor has had one "in view within 8 m" (`survivor-objectives.md` rule 7), and no ADR defined that test or how a discovery reaches clients. The server runs one shared `SightTest` (range, horizontal cone, multi-point line of sight on the `SIGHT` mask plus analytic doors, the same model Borrowed Face observation uses) in the Survivor Objectives tick step; on first success the point is marked discovered for the round and its hidden entity is granted to every survivor peer. Active points are chosen at round start by a seeded pick among every placement that satisfies rule 6, enumerated once at map load (amended 2026-10-12 for architecture review 12c, AD-48).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Physics (queries), Networking (visibility) |
| **Knowledge Risk** | HIGH: Jolt is the default 3D engine since 4.6; `modules/physics.md` and `modules/networking.md` are 4.6 snapshots |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/physics.md`, `modules/networking.md`, `breaking-changes.md`, `deprecated-apis.md`; ADR-0003, ADR-0004, ADR-0005, ADR-0007, ADR-0008 |
| **Post-Cutoff APIs Used** | None; `intersect_ray` is pre-cutoff, run on the Jolt backend (default since 4.6) (amended 2026-10-12 for architecture review 12c, AD-45) |
| **Verification Required** | (1) worst case on the greybox (every point undiscovered, 4 survivors standing within 8 m of 3 points each, all cones passing) costs under 0.2 ms per tick on the server; (2) a granted `MultiplayerSynchronizer` visibility for an already-spawned hidden point reaches a survivor peer within one network poll (ADR-0004 Verification 2 covered grant right after spawn, not a later grant), and a re-grant on reconnect does not spawn the node twice |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Proposed): server-held view direction from consumed input frames. ADR-0004 (Proposed): undiscovered points are hidden spawned entities granted per peer; `ObjectiveProgressChanged` projection omits undiscovered points. ADR-0005 (Proposed): tick step, events. ADR-0006 (Proposed): knobs. ADR-0007 (Proposed): `PhysicsLayers.SIGHT`, analytic doors |
| **Enables** | Survivor Objectives discovery stories; Borrowed Face observation reuses `SightTest`; ADR-0013 audio occlusion reuses `SightTest.line_clear` |
| **Blocks** | Survivor Objectives discovery story |
| **Ordering Note** | None |

## Context

### Problem Statement
Rule 7 makes the route readable without handing it out: fuse boxes and the terminal are always marked, but a drive room or fuse spawn is marked for all survivors only after one of them has seen it within `discover_range_m` = 8. Rule 5 and the GDD AC require that a survivor client receives no data at all for an undiscovered point, so a modified client cannot read the route. "In view" was not defined, and the cost and timing of the check were open (TR-objectives-003).

### Constraints
- Server-side only; the client's camera or claim never decides discovery (TR-index-001).
- Undiscovered points are hidden spawned entities granted per peer (ADR-0004 §7).
- Sight uses `PhysicsLayers.SIGHT` (`world`) plus analytic door and barricade tests; glass does not block sight (ADR-0003 §6, ADR-0007).
- Queries run only inside TickRunner's physics phases (ADR-0008 Implementation Guidelines).

### Requirements
- Discovery happens on the tick a survivor first meets the test, and is permanent for the round.
- The same notion of "in view" as Borrowed Face observation, so players learn one rule.
- Bounded per-tick cost.

## Decision

**1. One sight test.** `SightTest.sees(eye, yaw, target_points, range_m, fov_deg) -> bool` is a pure helper: true when any target point is within `range_m` of the eye, inside the horizontal cone of `fov_deg` centred on `yaw` (angle measured in the horizontal plane, no vertical limit), and an `intersect_ray` on `PhysicsLayers.SIGHT` from the eye to that point hits nothing and crosses no closed door or barricade box (analytic, from authoritative state). Borrowed Face observation (`observe_range`, `observe_fov_deg`, body points) uses the same helper. The ray-plus-doors part is exposed alone as `SightTest.line_clear(space, from, to, doors)`, with no range or cone, for ADR-0013 occlusion (amended 2026-10-12 for architecture review 12c, AD-45).

**2. "In view" for discovery.** A survivor sees a point when `SightTest.sees` passes with `discover_range_m` (8) and `discover_fov_deg` (90, matching `observe_fov_deg`; new knob, proposed) against the point's authored sample points (1–3 per drive room or fuse spawn, in Facility Map data). The eye is the server body's eye position; the yaw is from the survivor's last consumed input frame.

**3. Who can discover.** Survivors who are in the round and not Eliminated, Escaped or hidden in a hiding spot (hide-peek view is an open UX gap). Healthy, Wounded, Seized and Downed survivors can discover. The shapeshifter never discovers, in any form; it already knows every active point (rule 5).

**4. When.** In the `SurvivorObjectives` tick step (ADR-0005 §4, step 6), each tick, for each undiscovered active point, for each eligible survivor: distance first, cone second, rays last; stop at the first survivor that sees it. Discovered points are skipped forever.

**5. On discovery.** Survivor Objectives marks the point discovered (its own state), calls `set_visibility_for(peer, true)` on the point's hidden entity for every survivor peer and their spectators, and emits `ObjectiveProgressChanged`, whose survivor projection now includes the point. A survivor who reconnects or joins spectating later gets every discovered point through ADR-0004 §9's re-grant.

**6. Candidate selection (amended 2026-10-12 for architecture review 12c, AD-48).** At map load Survivor Objectives enumerates every combination of active points (1 terminal, 2 fuse boxes, 2 drive rooms, 2 fuse spawns from the Facility Map candidate sets) that satisfies rule 6, and fails the load if there are none. At round start it draws one combination with `rng.randi_range(0, count - 1)` from a `RandomNumberGenerator` injected by the composition root and seeded from the round seed, which the server logs; tests pass a fixed seed. With 3 × 3 × 15 × 21 = 2 835 raw combinations the enumeration is trivially small. Uniform over valid combinations is how this ADR reads rule 5's "uniformly at random" (inference; a designer reading per-type uniformity would change only the draw). The chosen points are spawned as hidden entities (ADR-0004 §7) before the first snapshot.

### Architecture Diagram

```
SurvivorObjectives.server_tick (step 6)
  for point in active_points where not discovered:
    for survivor in eligible_survivors:
      d ≤ discover_range_m ? → cone(yaw, discover_fov_deg) ? → SightTest rays (SIGHT + analytic doors)
        → discovered[point] = true
          → grant hidden entity to all survivor peers (+ spectators)
          → emit EvObjectiveProgressChanged (projection now includes point)
```

### Key Interfaces

```gdscript
class_name SightTest extends RefCounted   # pure; shared with Borrowed Face observation
static func sees(space: PhysicsDirectSpaceState3D, eye: Vector3, yaw: float,
		targets: PackedVector3Array, range_m: float, fov_deg: float,
		doors: DoorBoxes) -> bool   # player bodies are not on SIGHT, so no exclude list; returns bool on every branch
static func line_clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3,
		doors: DoorBoxes) -> bool   # one SIGHT ray + analytic door and barricade boxes; used by sees() and ADR-0013

# Survivor Objectives (own state)
func is_discovered(point_id: int) -> bool
static func valid_placements(c: ObjectiveCandidates) -> Array[PackedInt32Array]   # map load; rule 6 filter
func pick_active(rng: RandomNumberGenerator) -> PackedInt32Array               # round start; one draw
```

### Implementation Guidelines
- Discovery **must** be decided only on the server, from server body positions and consumed input yaw. A client message **must never** cause discovery.
- Discovery and Borrowed Face observation **must** use the one `SightTest` helper.
- The test **must** order checks distance, then cone, then rays, and stop at the first success.
- `discover_range_m` and `discover_fov_deg` **must** come from `ObjectivesKnobs`; sample points **must** come from Facility Map data.
- An undiscovered point's entity **must** stay ungranted on every survivor peer until discovery.
- `SightTest` **must** run only inside TickRunner physics phases.
- Active points **must** be drawn only from the load-time list of rule-6-valid placements, with the injected, seeded `RandomNumberGenerator`; the global `randi()` / `randf()` **must never** be used for selection.
- Both ray ends **must** lie outside every `SIGHT` collider: authored sample points sit at least 5 cm off any surface, because `hit_back_faces` defaults to true on 4.7.2 (ADR-0003 Verification results (1)) and a point on or inside a wall blocks its own ray. The eye starts inside no collider: the body capsule keeps it out of world geometry, and if a test shows otherwise the query sets `hit_from_inside = true` (`godot-specialist`, 2026-10-12) (amended 2026-10-12 for architecture review 12c, AD-45).

## Alternatives Considered

### Alternative 1: Proximity only (within 8 m, no sight)
- **Description**: Discover on distance alone.
- **Pros**: Cheapest.
- **Cons**: Discovers rooms through walls, against "in view".
- **Rejection Reason**: Contradicts rule 7.

### Alternative 2: Client reports what its camera sees
- **Description**: The client's frustum test reports discovery.
- **Pros**: Matches the player's real field of view and FOV setting.
- **Cons**: A client claim; a cheat discovers everything.
- **Rejection Reason**: Server authority (TR-index-001).

### Alternative 3: Volume-based discovery (entering the room)
- **Description**: Discover when a survivor enters the point's lighting volume.
- **Pros**: No rays.
- **Cons**: Seeing a drive room through a doorway or glass would not count.
- **Rejection Reason**: Narrower than "in view within 8 m".

## Consequences

### Positive
- One sight rule for observation and discovery.
- No undiscovered data on survivor clients.

### Negative
- A new knob (`discover_fov_deg`) the GDD did not have; added to `survivor-objectives.md` Tuning Knobs as proposed.

## Risks
- **Ray cost with many points in range.** Mitigation: distance and cone pre-filters; Verification 1.
- **Late visibility grant delay.** Mitigation: Verification 2; fallback is spawning hidden points lazily at discovery (ADR-0004 spawn-then-grant path, already verified).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| survivor-objectives.md | TR-objectives-003, rule 7: a drive room or fuse spawn is marked for all survivors once any survivor has had it in view within 8 m | §1–5 |
| survivor-objectives.md | AC: not before, and a survivor client receives no data for an undiscovered point | §5 grant only on discovery; ADR-0004 §7 |
| survivor-objectives.md | TR-objectives-002, rules 5–6: active points picked at round start from authored candidates under placement constraints; fixed-seed AC over 20 rounds | §6 |
| borrowed-face.md | Observation cone and multi-point line of sight (TR-borrowedface-003) | §1 shared `SightTest` |

## Performance Implications
- **CPU**: Distance checks for undiscovered points × eligible survivors each tick; rays only after both pre-filters (Verification 1, under 0.2 ms worst case).
- **Memory**: One bool per active point.
- **Load Time**: None.
- **Network**: One visibility grant per survivor peer per discovery, plus the event.

## Migration Plan
No code exists yet.

## Validation Criteria
- A survivor at 7.9 m facing a drive room with a clear view discovers it on that tick; at 8.1 m, behind a wall, or facing away, does not.
- A drive room seen through glass at 6 m is discovered; through a closed door, not.
- A packet capture on a survivor client before discovery contains no data for the point.
- A hidden survivor and the shapeshifter never discover.

## Related
- ADR-0003 (analytic doors, sight rays), ADR-0004 (hidden entities, projection), ADR-0005 (tick step), ADR-0007 (`SIGHT` mask), ADR-0008 (queries in physics phases)
- `design/gdd/survivor-objectives.md` rules 5, 7; `design/gdd/borrowed-face.md` rule 2
