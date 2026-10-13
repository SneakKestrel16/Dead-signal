# ADR-0007: Movement, Physics and Collision Layers

## Status
Proposed

## Date
2026-10-12

## Last Verified
2026-10-12

## Decision Makers
SneakKestrel16 (designer), with `godot-specialist` engine validation. TD-ADR skipped — Lean mode.

## Summary
Every player moves through one shared movement step, and every system that casts a ray or tests a volume needs to agree on what blocks what. The decision: a Jolt `CharacterBody3D` per player with per-player capsule resources, explicit floor settings, ramp colliders for steps, four named collision layers with fixed masks per query purpose, analytic zones and interactables from map data, and keyboard-and-mouse input through named actions.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Physics, Input |
| **Knowledge Risk** | HIGH (Jolt default since 4.6; 4.7 input device IDs; `modules/physics.md` and `modules/input.md` are 4.6 snapshots) |
| **References Consulted** | `docs/engine-reference/godot/modules/physics.md`, `modules/input.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; `prototypes/networking-spike/main.gd` |
| **Post-Cutoff APIs Used** | Jolt as the default 3D engine (4.6); input device checks by event type or `InputEvent.DEVICE_ID_*` (4.7). The 4.7 Jolt changes (`WorldBoundaryShape3D` plane sign, `Area3D` reporting `SoftBody3D`) do not apply: this design uses neither node |
| **Verification Required** | (1) Answered: `3d/physics_engine="Jolt Physics"` (`prototypes/networking-spike/project.godot:14`, run on 4.7.2); the root `project.godot` does not set it yet. (2) `CharacterBody3D` defaults on 4.7.2 for `safe_margin`, `max_slides`, `wall_min_slide_angle` (recalled as 0.001, 6, 15°; training data). (3) Several `move_and_slide` calls in one physics frame replay correctly with gravity and floor snap, starting from a restore by position, velocity and `apply_floor_snap()` (needed by ADR-0002, its item 7; the spike pinned y). (4) `intersect_shape` with `margin = 0` and `exclude` for the stand-up check. (5) `local_to_scene` or code-built shapes are not shared between instances. (6) Capsule snagging on floor seams with Jolt. (7) Same-tick query visibility on Jolt: after a body moves or its shape swaps or is disabled in one TickRunner phase, a later `move_and_slide`, `intersect_shape` or `intersect_ray` in the same physics frame sees the new state. Decisions 2, 6 and 7 (stand-up check, rotated move order, hide-exit placement) assume it. (8) `InputEventMouseMotion.screen_relative` is unscaled by the stretch mode on 4.7.2. (9) `floor_block_on_wall = true` stops a capsule on the 41° ramp of the controller AC |

**API coverage.** In the repo reference: Jolt as the default, `CharacterBody3D.move_and_slide`, `get_gravity`, `PhysicsRayQueryParameters3D` / `intersect_ray`, `Input.get_vector`, device-ID rule. Spike-verified on 4.7.2: Jolt `CharacterBody3D` with `collision_layer` and `move_and_slide` (no gravity). Training data only: the items under Verification Required, `floor_*` properties, `Input.use_accumulated_input`.

**Verification results (2026-10-12, [`prototypes/adr-verification/README.md`](../../prototypes/adr-verification/README.md)).** (1) answered. (2) `safe_margin` 0.001, `max_slides` 6, `wall_min_slide_angle` 15°. (3) see ADR-0002 (4). (4), (5), (6) PASS. (7) **FAIL**: queries and `move_and_slide` see other bodies at their positions after the last physics step; a teleport or move this frame is invisible until the next step, while disabling or shrinking a shape is seen at once (Decisions 6 and 7 amended). (8) NOT RUN (needs a window). (9) the floor limit is `floor_max_angle` plus about 0.5°: at 40.5° a 41° ramp climbs; at 40.0° 40° climbs and 41° blocks, with or without `floor_block_on_wall` (Decision 3 amended).

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Proposed): shared movement step, prediction and replay, 60 Hz. ADR-0003 (Proposed): sight rays on static geometry, doors tested analytically for hits |
| **Enables** | ADR-0008 (hold protocol): interaction targeting; Should-have lighting and objective-candidate ADRs: analytic volumes |
| **Blocks** | First-Person Controller implementation; greybox collision authoring |
| **Ordering Note** | Amends ADR-0002 rule 6: client prediction also collides with doors from replicated state |

## Context

### Problem Statement
`first-person-controller.md` fixes the body (rule 1), gaits and speeds (rules 2–4), no jump, steps and slopes (rule 5), modifiers (rule 6), the view ray (rule 10), targeting (rule 12) and doors (rule 18). Other GDDs add what blocks what: glass blocks movement but not sight (`borrowed-face.md` rule 2), closed doors and barricades block the lunge and line of sight (`monster-abilities.md` rule 7), hidden survivors are inside spots (`survivor-defense.md`). ADR-0003 already chose static-only sight rays and analytic door tests for hits. Without one layer and mask scheme, each system would choose its own and disagree.

### Constraints
- Server and owning client run the same movement step (ADR-0002).
- Greybox only; one developer.
- Map limits: doorways ≥ 0.8 m, steps ≤ 0.35 m, slopes ≤ 40°, no jumps or drops (`research-facility.md`).

### Requirements
- Capsule r 0.30 m, h 1.8 m standing, 1.2 m crouched or Downed, the same in every form; players solid against each other (rule 1).
- Climb 0.35 m steps and 40° ramps; blocked by 0.40 m steps and 41° ramps; no jump (rule 5, AC).
- Standing up waits until there is room (rule 4).
- A door close is rejected while a capsule overlaps its swing area (rule 18).
- The aim ray follows the server's view direction (rule 10).

## Decision

**1. Engine.** The project selects Jolt explicitly in its settings. The physics tick is ADR-0002's 60 Hz. `WorldBoundaryShape3D` and `Area3D` are not used for gameplay.

**2. Body.** Each player is a `CharacterBody3D` in grounded motion mode with two `CapsuleShape3D` resources built with `.new()` at spawn, so no two players share a shape:
- standing: radius 0.30, height 1.8;
- low (crouched or Downed): radius 0.30, height 1.2.

`height` includes the caps. On each swap the `CollisionShape3D` is placed at y = height / 2.

Standing up uses `PhysicsDirectSpaceState3D.intersect_shape` with the standing capsule raised 0.01 m, `margin = 0`, the player's own RID excluded, and mask `world | glass | doors`; other players are tested analytically (Decision 6a). The player stays low until it reports no overlap.

**3. Movement step.** One function, shared by the server and the owning client, run inside `_physics_process`:
- **Horizontal.** Velocity moves toward `input_dir × effective_speed` over `accel_time_s` = 0.05; `effective_speed` comes from the Controller's gait and modifier rules.
- **Vertical.** Velocity comes from `get_gravity()` and is reset to 0 while on the floor.
- **Fixed settings, all from data:** `floor_max_angle = deg_to_rad(40.0)`: the engine accepts slopes up to about 0.5° above `floor_max_angle`, so 40.0 lets 40° climb and blocks 41° (measured: 40.4° climbs, 40.6° blocks; the original 40.5 let 41° climb. Verification results (9)); `floor_snap_length` = 0.4 m (above the 0.35 m step); `floor_stop_on_slope = true`; `floor_constant_speed = true`; `floor_block_on_wall = true`, so a slope above `floor_max_angle` acts as a wall and the 41° block AC holds (`godot-specialist`, 2026-10-12 review; Verification Required item 9); and `safe_margin`, `max_slides` and `wall_min_slide_angle` set explicitly.
- **Read-back.** After `move_and_slide()`, `is_on_floor()` is read for ADR-0002's snapshot. On reconciliation the owning client restores position and velocity, then calls `apply_floor_snap()` when that flag is set (ADR-0002 rule 6); the floor is recomputed, never copied, because `CharacterBody3D` has no floor-state setter. (Amended after the 2026-10-12 architecture review; was "the floor flag and normal are read", which assumed a restore the engine does not offer.)
- **No jump.** No jump action exists.

**4. Steps.** Every step and stair up to 0.35 m gets an invisible ramp collider no steeper than 40°; the visual mesh keeps its steps. Floors use large box colliders rather than many small coplanar pieces, to avoid seam snagging. The camera height is smoothed over the ramp so the visual steps do not jolt the view.

**5. Collision layers and masks.**

| Layer | Contents |
|---|---|
| 1 `world` | Walls, floors, ramp colliders, static props |
| 2 `glass` | Glass partitions and windows |
| 3 `doors` | One `StaticBody3D` blocker per door; its shape is enabled while the door is closed or barricaded and disabled while open |
| 4 `players` | Player capsules |

| Query | Mask |
|---|---|
| Server player movement | `world \| glass \| doors \| players` |
| Client prediction (ADR-0002) | `world \| glass \| doors`, doors driven by replicated door state; other players corrected by the server |
| Sight rays: observation, pings, lunge line of sight (ADR-0003) | `world` only; glass does not block sight; doors and barricades tested analytically |
| Projectile, dash and interaction: taser ray, lunge dash path, interaction blocking | `world \| glass`; doors and barricades tested analytically. Whether a taser dart passes glass is an Open Question; glass blocks it by default |

Shape `disabled` and `collision_layer` changes are made directly from TickRunner phases and network handlers. `set_deferred` is used only inside physics callbacks.

**6. Player against player.** Each tick the server moves players in ascending player-ID order, rotated by one position per tick. The order is deterministic.

Jolt queries and `move_and_slide` see other bodies where they were after the previous physics step, not where an earlier mover put them this tick (Verification results (7)). So within a tick every player moves against the others' start-of-tick positions, and two players closing head-on can overlap by up to one tick of motion (about 0.15 m at sprint, inference) until the next tick's `move_and_slide` separates them. This is accepted; the rotation keeps the outcome deterministic. (Amended 2026-10-12; the original premise was that a later mover sees an earlier one's new position.)

**6a. Placement checks test players analytically.** The stand-up check (Decision 2) and hide-exit placement (Decision 7) cannot rely on the physics space for other players, because a player who moved this tick is not there yet. They query the physics space for `world | glass | doors` only, and test other players' capsules analytically at their current-tick positions from ADR-0003's history (pushed in ADR-0002 phase 3), with the same capsule maths as ADR-0003 §6.

**7. Hidden survivors.** While hidden, a survivor's `collision_layer` and `collision_mask` are 0 and the body sits at the spot's hide point. On exit, the server places it at the spot's exit point if the standing capsule fits there; otherwise it tries the spot's alternate exit points in order, and if none fits the exit waits.

**8. Door closing.** A door close is rejected while any player capsule overlaps the door's swing area, tested analytically (capsule against the swing box from Facility Map data).

**9. Zones.** Lighting volumes, the exit volume, the terminal zone and spawn rooms are analytic boxes from Facility Map data (point-in-box tests). No `Area3D` is used for gameplay zones.

**10. Interactables.** Each interactable registers an interaction point and radius from map data. The server's view ray picks the nearest interactable within `interact_ray_max_m` and within that interactable's own range. An `intersect_ray` on `world | glass` (nobody interacts through glass) plus the analytic door test gives the blocking distance; anything beyond it is not a target. This follows `first-person-controller.md` rule 12 and the range rules in ADR-0008.

**11. Input.** Keyboard and mouse first; gamepad is deferred.
- **Named actions:** `move_forward`, `move_back`, `move_left`, `move_right`, `sprint`, `crouch`, `interact`, `use_item`, `ping`, `callout_wheel`, `flashlight`. There is no jump action.
- **Mouse look.** It comes from `InputEventMouseMotion.screen_relative`, not scaled by delta, with the mouse captured. Not `relative`: that is scaled by the content stretch, and 4.7 new projects default to stretch mode `canvas_items` (`breaking-changes.md`, 4.7 Project row), so sensitivity would change with window size. `screen_relative` is training data (4.3+), NOT SOURCEABLE from `modules/input.md`; Verification Required item 8. The stretch mode stays free for the UI. Yaw and pitch are accumulated and applied at the physics tick for prediction, with pitch clamped to ±85°. The mouse is re-captured when the window regains focus.
- **Device checks.** They use the event type, never `device == 0`.

### Architecture Diagram

```
Player (CharacterBody3D, layer players)
  ├─ CollisionShape3D ← CapsuleShape3D standing (h 1.8) | low (h 1.2), per-player .new()
  └─ movement step (server + owner prediction):
       velocity.xz → input × effective_speed (accel 0.05 s)
       velocity.y  ← gravity, 0 on floor
       move_and_slide()  floor_max_angle 40.0°, snap 0.4, constant speed
Masks:  server move  = world|glass|doors|players
        prediction   = world|glass|doors (replicated door state)
        sight rays   = world            (+ analytic doors, ADR-0003)
        taser/dash   = world|glass      (+ analytic doors)
Zones, interactables, door swing areas: analytic shapes from Facility Map data
```

### Key Interfaces

```gdscript
class_name PhysicsLayers
const WORLD := 1 << 0
const GLASS := 1 << 1
const DOORS := 1 << 2
const PLAYERS := 1 << 3
const MOVE_SERVER := WORLD | GLASS | DOORS | PLAYERS
const MOVE_PREDICT := WORLD | GLASS | DOORS
const SIGHT := WORLD
const PROJECTILE := WORLD | GLASS

class_name PlayerBody extends CharacterBody3D
func set_low(low: bool) -> bool          # returns false while standing up is blocked
func set_hidden(hidden: bool, spot: HidingSpotData) -> bool

class_name MapQueries extends RefCounted
func volume_at(point: Vector3) -> StringName
func in_zone(zone_id: StringName, point: Vector3) -> bool
func interactable_on_ray(origin: Vector3, dir: Vector3) -> int   # net id, -1 if none (amended by ADR-0008; was StringName)
func capsule_overlaps_swing(door_id: StringName, capsule_center: Vector3, height: float, radius: float) -> bool
```

### Implementation Guidelines
- Every physics query **must** use a mask from `PhysicsLayers`. Inline layer numbers are forbidden.
- Each player **must** own its capsule resources. Shapes **must never** be shared between players.
- The movement step **must** be the single shared function from ADR-0002. Its floor and slide settings **must** come from data.
- Steps **must** be climbed through ramp colliders. Custom step-up code is forbidden.
- Gameplay zones **must** be analytic from map data. `Area3D` **must never** be used for gameplay zones.
- Input **must** go through the named actions. Device checks **must** use event type or `DEVICE_ID_*`.
- `set_deferred` **must** be used only inside physics callbacks.
- `WorldBoundaryShape3D` **must not** be used.

## Alternatives Considered

### Alternative 1: Hand-written kinematic controller
- **Description**: Shape casts with `PhysicsServer3D.body_test_motion` and custom step-up.
- **Pros**: Full control over steps and sliding.
- **Cons**: Much more code; replay must match exactly.
- **Rejection Reason**: `move_and_slide` plus ramp colliders meets every rule with less code.

### Alternative 2: `RigidBody3D` players
- **Description**: Physics-driven bodies.
- **Pros**: Natural pushing.
- **Cons**: Forces fight prediction and reconciliation.
- **Rejection Reason**: Incompatible with ADR-0002.

### Alternative 3: Custom step-up
- **Description**: Test up, forward and down before each move.
- **Pros**: Works on any geometry.
- **Cons**: More code; prediction mismatch risk.
- **Rejection Reason**: Designer decision 2026-10-12: ramp colliders.

### Alternative 4: Interactables on a physics layer
- **Description**: A collider per interactable, found by one ray.
- **Pros**: Engine-native.
- **Cons**: More physics objects; area or body flags per interactable.
- **Rejection Reason**: Designer decision 2026-10-12: analytic from map data, same style as ADR-0003.

## Consequences

### Positive
- One mask table settles what blocks what for every system.
- Glass behaves as the GDDs need: blocks bodies, not sight.
- Gameplay zones and targeting are pure functions, easy to unit-test.
- No custom step code.

### Negative
- Every step in the greybox needs a ramp collider; feet and camera follow the ramp, not the stairs.
- Low player IDs still win contests on even ticks of the rotation.
- Players moving in the same tick do not see each other's new positions; brief overlaps of up to one tick of motion are possible (Decision 6).
- Door blockers are toggled from state, so a door that changes this tick may block one tick late on the client.

## Risks
- **Replay with gravity untested.** Mitigation: Verification Required item 3 in the spike before acceptance.
- **Same-tick query visibility (confirmed).** Jolt applies moves only at the next step. Mitigation: placement checks test players analytically (Decision 6a); player-player overlap within a tick is accepted (Decision 6). Disabling or shrinking a shape is visible at once, so door opening and crouching are not affected.
- **Seam snagging on Jolt.** Mitigation: large box floor colliders; a walk-every-room test in the greybox.
- **Missing ramp collider.** A step without one blocks a player. Mitigation: a build-time check that every authored step has a ramp no steeper than 40°.
- **Unhide with nowhere to stand.** Mitigation: alternate exit points per spot, authored in the Facility Map.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| first-person-controller.md | Rule 1: capsule r 0.30, h 1.8 / 1.2, same in every form; players solid against each other | Decisions 2, 6 |
| first-person-controller.md | Rule 4: standing up waits until there is room | Decision 2: `intersect_shape` stand-up check |
| first-person-controller.md | Rule 5 and AC: 0.35 m steps and 40° ramps climb; 0.40 m steps and 41° ramps block; no jump | Decisions 3–4, 11 |
| first-person-controller.md | Rule 10: aim ray from the eye along the server view direction | Decisions 5, 10 |
| first-person-controller.md | Rule 12: nearest interactable on the view ray within its own range; world geometry blocks | Decision 10 |
| first-person-controller.md | Rule 18: door close rejected while a capsule overlaps the swing area | Decision 8 |
| borrowed-face.md | Rule 2: walls, closed doors and closed hiding spots block line of sight; glass does not | Decision 5: sight mask `world`; doors analytic |
| monster-abilities.md | Rule 6: the dash is blocked by walls, closed or barricaded doors and invalid survivors' bodies | Decision 5: dash mask plus analytic doors; bodies per ADR-0003 |
| survivor-defense.md | Hidden survivors are inside spots and untargetable | Decision 7 |
| research-facility.md | Geometry limits; zones and volumes | Decisions 4, 9 |

## Performance Implications
- **CPU**: 6 `move_and_slide` calls per tick on the server (spike: about 0.055 ms for 6 capsules without gravity); prediction replays up to about 15 steps per snapshot for one body.
- **Memory**: Two capsule resources per player.
- **Load Time**: None.
- **Network**: None.

## Migration Plan
No production code exists. Amends ADR-0002 rule 6 (prediction includes doors). Updates `first-person-controller.md` rule 5, `research-facility.md` geometry limits and `survivor-defense.md` Open Questions.

## Validation Criteria
- Controller ACs for capsule size, step and ramp limits, stand-up under a low ceiling, and speeds pass.
- A ray from one side of glass to a survivor on the other reports line of sight; a body cannot walk through the glass; a taser shot through it is blocked (default).
- Two players walking into each other head-on resolve the same way on repeated runs with the same seed and tick.
- A survivor leaving a hiding spot with the exit point occupied uses an alternate exit or waits; it never overlaps.
- A door close with a capsule in the swing area is rejected on every client.
- Every Verification Required item passes on 4.7.2.

## Related
- ADR-0002 — movement step and prediction (depends on; amended)
- ADR-0003 — sight rays, analytic doors (depends on)
- ADR-0008 — hold protocol
- `design/gdd/first-person-controller.md`, `design/gdd/borrowed-face.md`, `design/gdd/monster-abilities.md`, `design/gdd/survivor-defense.md`, `design/levels/research-facility.md`
