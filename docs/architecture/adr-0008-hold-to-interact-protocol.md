# ADR-0008: Hold-to-Interact Protocol

## Status
Proposed

## Date
2026-10-12

## Last Verified
2026-10-12

## Decision Makers
Designer (user), with Claude Code (`/architecture-decision`)

## Summary
Every interaction in Dead Signal (objectives, rescue, barricades, hiding, searching, backup switches, doors) follows one server-validated hold pattern (`first-person-controller.md` rules 11–18). One Controller-owned `HoldService` runs every hold from a hold bit and target carried in `InputFrame`, as one step in ADR-0005's tick order. Owners register `Interactable` objects and receive direct `on_start`, `on_complete` and `on_cancel` calls.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Core (GDScript), Physics (queries), Networking (input transport) |
| **Knowledge Risk** | HIGH: 4.5 `@abstract`; 4.7 typed-return overrides need an explicit `return` (the reference states it for typed returns; whether a `void` override is affected is unverified until Verification item 1 runs) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `current-best-practices.md`, `modules/physics.md`, `modules/networking.md`; ADR-0002, ADR-0004, ADR-0005, ADR-0007 |
| **Post-Cutoff APIs Used** | `@abstract` (4.5) on `Interactable`; Jolt `intersect_ray` (default since 4.6) for the line-of-sight check |
| **Verification Required** | A headless script per item, before acceptance: (1) does an `Interactable` subclass whose `void` `on_cancel` override has no `return` compile (unverified: the reference is silent on `void`)? And does one whose `eligible` override misses a branch's `return` fail to compile? (2) a line-of-sight `intersect_ray` on `PhysicsLayers.PROJECTILE` from an eye inside a player capsule, with that player's RID excluded, reports the wall beyond and not the capsule, with `hit_from_inside = false` and `collide_with_areas = false` (neither setting is in the engine reference); (3) two actors started on one `lock_key` on the same tick in a scripted queue order; the first in rotated order holds the lock |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Proposed): `InputFrame`, TickRunner phases, input starvation release. ADR-0004 (Proposed): per-peer body handles for body targets. ADR-0005 (Proposed): tick order, EventBus, owner-emits rule. ADR-0007 (Proposed): `MapQueries.interactable_on_ray`, masks, rotated player order |
| **Enables** | ADR "Objective candidate selection and discovery" (should-have); UI/input-focus ADR (prompt and bar) |
| **Blocks** | Every epic with an interaction: Survivor Objectives, Downing (rescue), Survivor Defense (hide, barricade, search, break, doors), Monster Abilities (backup switch) |
| **Ordering Note** | Amends ADR-0002: Start and Stop move from the reliable intent channel into `InputFrame` (two fields). Amends ADR-0005's tick order: a `Holds` step between `Downing` and `SurvivorObjectives`. Amends ADR-0007's `MapQueries.interactable_on_ray` to return a net id |

## Context

### Problem Statement
Seven systems own interactions with different durations, cancel rules, locks and fake rules. The Controller GDD (rule 11) requires one pattern so rules cannot drift between owners. The server must time every hold; a client "done" message is ignored (rule 15). The design must fix how Start and Stop reach the server, where holds run in the tick, who wins a contested lock, and how owners learn of completion and cancellation.

### Constraints
- Server authority: the client sends intent only (ADR-0002).
- Deterministic tick order; owners emit their own events (ADR-0005).
- Shapeshifter fake holds must look and sound identical to real ones to observers, and never take a lock (Survivor Objectives rule 25).
- Body targets (rescue a Downed survivor) must not reveal identity across form changes (ADR-0004 handles).
- Every gameplay value comes from data.

### Requirements
- Target: nearest interactable on the view ray within `interact_ray_max_m` and its own `range_m`; world and glass block (rule 12, ADR-0007 §10).
- Start: eligibility, strict range (capsule centre to interaction point), line of sight (eye to point), lock (rule 13). Client bar within 100 ms.
- While Holding, per tick: input held, range ≤ `range_m` + `hold_range_tolerance_m`, line of sight, eligibility, owner interrupts. Looking away does not cancel. Walk allowed, sprint not; `roots_actor` roots; crouch ignored (rule 14).
- Completion on the server at `duration_s` (rule 15). One hold per actor (rule 16). Disconnect and the 500 ms intent timeout cancel.
- Doors are instant (`duration_s` 0). Barricade, Remove barricade and Break on a door share one lock (`survivor-defense.md` 28a).
- Same-tick: a hit is resolved before an interaction completes (`downing-and-rescue.md` edge cases).

## Decision

**1. One service.** `HoldService` is part of the Controller (Core layer), constructed by the composition root and injected into owners through `setup()` like the other services (ADR-0005 §6). It is the only code that times holds.

**2. Interactables.** An owner builds one `Interactable` per interaction (a `RefCounted` subclass, values from data) and calls `holds.register(i)`. Map interactables are registered at round start in map order and get net ids `0..N-1`, identical on every peer. Dynamic interactables (a Dropped drive) get the next free id and reach clients through the owner's replicated entity (ADR-0004). An interactable attached to a body (rescue a Downed survivor) is addressed by the body's per-peer handle, never by net id.

Fields: `net_id`, `point`, `range_m`, `duration_s` (0 = instant), `roots_actor`, `lock_key` (`&""` = no lock; Barricade, Remove barricade and Break on one door share `door_<id>`), `fakeable`. Methods: `eligible(actor)`, `start_progress_s()` (the owner's stored progress: 0 for reset rules), `on_start(actor)`, `on_complete(actor)`, `on_cancel(actor, progress_s, reason)`. Cancel rules (reset, keep, keep and decay) live in the owner's `on_cancel`; decay runs in the owner's own `server_tick`.

**3. Transport (amends ADR-0002 §3).** `InputFrame` gains `interact: bool` (in the flags byte) and `interact_target: int`, plus a `target_is_body` flag. The target is read only on the frame where `interact` rises; while held, later targets are ignored, so looking away does not cancel. `interact` falling is Stop. Starvation repeats the last frame; after `intent_timeout_ms` input is released and the hold cancels (ADR-0002 §4). Item use, pings and callouts stay on the reliable intent channel.

**4. Tick step (amends ADR-0005 §4).** `Holds` runs between `Downing` and `SurvivorObjectives`, followed by a flush. By then the same tick's hits, shocks, stuns, downs and hides are set, so an interrupt always beats a completion on the same tick. In the `Holds` step, for each player in ADR-0007 §6's rotated player-ID order:
1. **Stop or cancel**: `interact` released, or a check fails → `on_cancel(actor, progress, reason)`.
2. **Checks while Holding**: range ≤ `range_m` + `hold_range_tolerance_m` (capsule centre to point), line of sight (eye to point, `intersect_ray` on `PROJECTILE`, own RID excluded, plus the analytic door test), `eligible(actor)`.
3. **Start** on a rising edge: resolve the target (net id or handle), then eligibility, strict `range_m`, line of sight, and lock. An actor already holding cancels the old hold first (rule 16). Accepted → `on_start(actor)`, elapsed = `start_progress_s()`. Instant interactables complete at once and take no lock.
4. **Advance**: elapsed += one tick; at `duration_s` → release lock, `on_complete(actor)`.

The rotated order decides a contested lock: the first actor processed takes it, the rest are rejected.

**5. Owner interrupts.** An owner that must cancel a hold for its own reason (Downing on `SurvivorHit` against a rescuer; Defense on `PlayerShocked`) calls `holds.cancel(actor, reason)` from its handler. Completion and cancellation reach the owner as direct calls; the owner then emits its own catalog event (ADR-0005 owner-emits rule). `HoldService` emits no events. Using an item or hiding cancels through the same call.

**6. Fake holds.** A shapeshifter Start on a `fakeable` interactable is accepted as a fake: same animation and quiet loop, no lock, no progress, no owner calls, never completes. A real survivor Start on the same interactable cancels the fake (Survivor Objectives rule 25). On a non-fakeable interactable, the shapeshifter's Start is rejected by `eligible`.

**7. Movement while Holding.** The Controller's movement step reads the actor's hold state: sprint off, speed 0 if `roots_actor`, crouch input ignored. A new hold's restrictions apply from the next tick's movement phase.

**8. Client side.** The owner's client shows its predicted bar on the rising edge if its local target query found a valid target. Its own snapshot carries `hold_net_id` (or −1) and `hold_elapsed_ticks`. If the snapshot acknowledging the press `seq` shows no hold, the bar cancels; otherwise the bar follows the server's elapsed time. Observers see a `holding` pose bit on the body in snapshots, set identically for real and fake holds. Object progress bars come from the owner's events, never from the hold.

### Architecture Diagram

```
CLIENT (owner)                                   SERVER tick T
 press interact ─▶ InputFrame{interact=1,        1 dequeue frames
                   interact_target, is_body}     2 movement (hold limits from T-1)
 predicted bar ◀─ local target query             4 MatchFlow.begin → Defense → BorrowedFace
                                                   → MonsterAbilities → Downing
                                                   → Holds ─────────────────────────┐
 snapshot: own hold_net_id, elapsed ◀──────        for actor in rotated order:      │
 bar confirmed / cancelled                           stop/cancel → on_cancel        │
                                                     checks (range+tol, LOS, elig)  │
 observers: body.holding pose bit                    start (strict, lock) → on_start│
                                                     advance → on_complete ─────────┘
                                                   → Objectives → Pings → Scare → MatchFlow.resolve
 Owner modules: register(Interactable); cancel(actor) from handlers; emit own events
```

### Key Interfaces

```gdscript
# Added to ADR-0002's InputFrame
var interact: bool            # flags byte
var interact_target: int      # net id, or body handle when target_is_body
var target_is_body: bool      # flags byte

@abstract
class_name Interactable extends RefCounted
var net_id: int
var point: Vector3
var range_m: float
var duration_s: float         # 0 = instant
var roots_actor: bool
var lock_key: StringName      # &"" = no lock
var fakeable: bool
@abstract func eligible(actor: int) -> bool
@abstract func start_progress_s() -> float
func on_start(actor: int) -> void: pass
@abstract func on_complete(actor: int) -> void
@abstract func on_cancel(actor: int, progress_s: float, reason: StringName) -> void

class_name HoldService extends RefCounted
func setup(tick_runner: TickRunner, map: MapQueries, bodies: BodyIndex, knobs: Knobs) -> void
func register(i: Interactable) -> int          # returns net_id
func unregister(net_id: int) -> void            # cancels any hold on it
func cancel(actor: int, reason: StringName) -> void
func hold_of(actor: int) -> Dictionary          # {net_id, elapsed_ticks, fake, roots}; {} when idle
func server_tick(tick: int) -> void             # the Holds step

# ADR-0007 amendment
func interactable_on_ray(origin: Vector3, dir: Vector3) -> int   # net id, -1 if none
```

### Implementation Guidelines
- Only `HoldService` **must** time holds. Owners **must never** count hold progress themselves; they keep only stored progress between holds.
- A client completion or progress message **must** be ignored; none exists in the protocol.
- The target **must** be read only on the rising edge of `interact`.
- Start range **must** be strict `range_m`; continuation **must** use `range_m` + `hold_range_tolerance_m`.
- Line-of-sight and target rays **must** use `PhysicsLayers.PROJECTILE` plus the analytic door test, and exclude the actor's own RID.
- Contested locks **must** be decided by the rotated player order of ADR-0007 §6.
- Fake holds **must never** take a lock, change progress or call the owner.
- Owners **must** emit their own catalog events from `on_complete` and `on_cancel`. `HoldService` **must never** emit events.
- `hold_range_tolerance_m`, `interact_ray_max_m` and every `duration_s` and `range_m` **must** come from data.
- Body targets **must** be resolved through the requesting peer's handle table (ADR-0004).
- `HoldService.server_tick` **must** run only inside TickRunner's `_physics_process` phases, because it queries `direct_space_state`. Querying outside the physics step is not covered by the engine reference.
- The flags byte **must** be packed whole per frame. Writing a `PackedByteArray` property by index no longer fires its setter (4.7, `breaking-changes.md`).
- `@abstract` **must** sit on its own line above `class_name`, as in `current-best-practices.md`.

## Alternatives Considered

### Alternative 1: Each owner runs its own hold logic
- **Description**: Objectives, Downing and Defense each time their own holds.
- **Pros**: No shared service; each owner fully local.
- **Cons**: Seven copies of range, sight, lock and cancel rules.
- **Rejection Reason**: Rule 11 requires one pattern; copies drift.

### Alternative 2: Client-timed holds checked on completion
- **Description**: The client times the hold and sends Done; the server validates.
- **Pros**: Zero server work while holding.
- **Cons**: Trusts the client; mid-hold interrupts cannot be enforced.
- **Rejection Reason**: Rule 15: a client "done" message is ignored.

### Alternative 3: Reliable Start and Stop RPCs
- **Description**: Keep ADR-0002 §3's reliable discrete intents for interaction.
- **Pros**: A tap is never lost.
- **Cons**: Not tick-aligned without extra `seq` matching; a lost or delayed Stop keeps a hold running; held state duplicates what the frame already carries.
- **Rejection Reason**: The frame's last-3 redundancy already covers loss, and "input still held" becomes a frame-bit check.

### Alternative 4: Hold events on the EventBus
- **Description**: `HoldService` emits HoldCompleted and HoldCancelled; owners subscribe.
- **Pros**: No direct calls between modules.
- **Cons**: Internal events need `project()` that hides them, and they are not in the catalog.
- **Rejection Reason**: Direct calls keep the catalog to the 15 designed events.

## Consequences

### Positive
- One place enforces range, sight, lock, cancel and fake rules for every interaction.
- Interrupts beat completions on the same tick by construction.
- No new catalog events; owners keep emitting their own.
- The bar's confirmation reuses the snapshot ack; no reject message.

### Negative
- A tap shorter than one frame lost in three consecutive input packets is lost (doors). Accepted: the player presses again.
- Owners depend on a Core service API (`cancel`) rather than only events.
- `InputFrame` grows by about 3 bytes per frame.

## Risks
- **Lock bias.** Rotated order spreads contested-lock wins evenly over time, not by who pressed first in real time. Mitigation: contests within one tick (16.7 ms) are rare; review in playtest.
- **Body-target leaks.** A stale handle could address the wrong body after a form change. Mitigation: handles are fresh on re-entry and retired on form change during linger (ADR-0004); a retired handle is rejected.
- **Prediction drift at the range edge.** Mitigated by `hold_range_tolerance_m` = 0.25 (rule 14).
- **Owner callbacks re-entering.** An `on_complete` that registers or unregisters interactables while the service iterates. Mitigation: register and unregister apply after the step.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| first-person-controller.md | Rules 11–18: definition fields, target, Start, While Holding, completion, one hold per actor, fake holds, doors | §1–8 |
| survivor-objectives.md | Rule 25: fake never takes the lock; a real Start cancels the fake; rule 27 bars from server state | §6, §8 |
| downing-and-rescue.md | Rescue roots the actor; hit before rescue completion on the same tick; bleed-out paused during the hold | §4 order; `roots_actor`; Downing pauses bleed-out from `on_start`/`on_cancel` |
| survivor-defense.md | 28a: interactable table; door shared lock; instant door toggle; swing check | `lock_key`; `duration_s` 0; swing check in `eligible` |
| monster-abilities.md | Rule 19: backup switch hold, no lock, no fake, reset on cancel | Interactable fields |
| borrowed-face.md | Disguised shapeshifter's interactions look like a survivor's | §6 fake holds, §8 pose bit identical |

## Performance Implications
- **CPU**: One ray per holding or starting actor per tick, at most 5 per tick.
- **Memory**: One `Interactable` per interaction point; tens.
- **Load Time**: Negligible.
- **Network**: About 3 bytes per input frame; 4 bytes in the owner's own snapshot.

## Migration Plan
No production code exists. ADR-0002 §3's interaction intents move into `InputFrame`; ADR-0005 §4 gains the `Holds` step; ADR-0007's `interactable_on_ray` returns a net id. Those ADRs get amendment notes alongside this one.

## Validation Criteria
- Unit tests with fake map, bodies and interactables: strict Start range, tolerant continuation, sight loss cancels, look-away does not, contested lock goes to the first in rotated order, a fake never calls the owner and is cancelled by a real Start, an instant interaction completes on its Start tick, a `SurvivorHit` cancel on the completion tick wins.
- A 500 ms input gap cancels a hold.
- Two-client test: the predicted bar appears within 100 ms and cancels within one round trip on rejection.

## Related
- ADR-0002, ADR-0004, ADR-0005, ADR-0007 (amended by this ADR)
- `design/gdd/first-person-controller.md`, `survivor-objectives.md`, `downing-and-rescue.md`, `survivor-defense.md`, `monster-abilities.md`, `borrowed-face.md`
