# Architecture Review Report

Date: 2026-10-12
Engine: Godot 4.7.2 (GDScript, Jolt, Forward+)
Mode: full, `workflow: standard` (architecture doc + critical ADRs)
GDDs Reviewed: 10 system GDDs + `systems-index.md`, `game-concept.md`, `design/levels/research-facility.md`
ADRs Reviewed: 8 (ADR-0001 to ADR-0008, all Proposed)
Prior report: none (`RECEIPT: NONE`)

Hashes below are of the reviewed content after this review's three approved fixes (C1 state rows, two GDD lines).

```
Reviewed-Content-Hash: docs/architecture/adr-0001-hosting-session-join-reconnect.md 9719416a7beb4836368b6fd2d83e74c70cb37784
Reviewed-Content-Hash: docs/architecture/adr-0002-authoritative-sim-tick-input.md f31a003d49b7ea2524224769886c1784a9757286
Reviewed-Content-Hash: docs/architecture/adr-0003-lag-compensation-rewind.md e52eaa4f755147cfed4daa9e9c387c96615cb153
Reviewed-Content-Hash: docs/architecture/adr-0004-replication-scope-information-hiding.md b6df1931fdae3b824201c5a56f7a94ae00df1429
Reviewed-Content-Hash: docs/architecture/adr-0005-event-catalog-state-registry-tick-order.md 5b765728fddbbd319a3d8556539f437ccdd93e32
Reviewed-Content-Hash: docs/architecture/adr-0006-data-driven-configuration.md 71a0ab3d896decf3b56f165393a02ecbe4610a61
Reviewed-Content-Hash: docs/architecture/adr-0007-movement-physics-collision-layers.md e32e393a1b6ff2efad6ab520036c709a60b56f38
Reviewed-Content-Hash: docs/architecture/adr-0008-hold-to-interact-protocol.md 9481e29214d54eaf8aabf01464702462e53d6032
Reviewed-Content-Hash: design/gdd/borrowed-face.md a6e37bc40ff1e93d169121415eb97e772db7f7b0
Reviewed-Content-Hash: design/gdd/downing-and-rescue.md 90055368fb0f9b69396e05a73d4844fd619fd0d9
Reviewed-Content-Hash: design/gdd/first-person-controller.md e31a5dcd26c1fe805bcf4a1b4d72b10e22c17a68
Reviewed-Content-Hash: design/gdd/game-concept.md 7b73deeda7ef463a82736aecc1f94f95911c9d8d
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-10-11.md bd32d9c0a898e1c48dec72a144a060740b064984
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-10-12.md 1a752edbb9bab50d0beb27aba6ef4632230ff979
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-10-12b.md e2e052f864fe9110ff2ed6e539cdffba42477a10
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-10-12c.md ad083fff09d827bd22127744c7080bc053015f2b
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-10-12d.md a447a4007efd2077ceabc5de72213cb6af7465f9
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-10-12e.md ddcdac67c01163b374b84bdd9d4b0ea96a516e73
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-10-12f.md 449d73d1a03eef072610207204b62346b1679a3f
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-10-12g.md 0bfb29c7287b0e03f22b8f39e8f3dbe975434135
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-10-12h.md 391511f9bf9079a106279c4fac55a5c5426113b0
Reviewed-Content-Hash: design/gdd/lobby-role-assignment.md d3fade6018a4c4a3334ef1f84fecd7c0d4809fde
Reviewed-Content-Hash: design/gdd/match-flow.md 8005fd72d3dba4621f4a9af579ed5e32119aa4a7
Reviewed-Content-Hash: design/gdd/monster-abilities.md 274bec2eca071fda92adf99ee013389b6a3c5111
Reviewed-Content-Hash: design/gdd/pings-and-callouts.md 4fb044ae16540ac3e880be8ff51289a163688b14
Reviewed-Content-Hash: design/gdd/scare-events.md c14f331d1ddf8ecd114f24c558054c35b6d07c6c
Reviewed-Content-Hash: design/gdd/survivor-defense.md c1599d79cc292de2110218f1241d95960bbbc50b
Reviewed-Content-Hash: design/gdd/survivor-objectives.md 2b0fa195aa64cfa7d1a0e128c2c5519b17b514e2
Reviewed-Content-Hash: design/gdd/systems-index.md 2080121e05a1267d2cf82a7e501c68de3dd1391f
Reviewed-Content-Hash: design/levels/research-facility.md 3ffe032c5a8721548b5d097545636c17ba818773
```

Cross-review files are hashed only so the next freshness check does not report them as `NEW`; they are review records, not requirement sources.

---

## Traceability Summary

Total requirements: 138 (136 from the `/create-architecture` baseline + TR-facility-011, -012 from the ADR-0004 and ADR-0007 sync edits)

| Status | Count |
|---|---|
| ✅ Covered (Accepted ADR) | 0 |
| 🟡 Covered (Proposed ADR) | 91 |
| ⚠️ Partial | 28 |
| ❌ Gap | 16 |
| — No ADR needed (coding standard or pure server logic) | 3 |

Counts are after this review's fixes: TR-matchflow-002 moved from ⚠️ to 🟡 once `match-flow.md` stopped falling back to defaults (90 / 29 before).

Full matrix: [`requirements-traceability.md`](requirements-traceability.md). Requirement text: [`tr-registry.yaml`](tr-registry.yaml).

## Coverage Gaps (no ADR exists)

All 16 map to should-have or deferred ADRs already listed in `architecture.md` (Required ADRs). None is in the critical set at `workflow: standard`.

| TR | GDD | Requirement | Suggested ADR | Domain | Engine risk |
|---|---|---|---|---|---|
| TR-index-009 | systems-index | `blackout_able` per lighting volume | `/architecture-decision lighting-states-and-blackout` | Rendering | HIGH (`Light3D` NOT SOURCEABLE) |
| TR-scare-007 | scare-events | Facility scare state machine requests lighting states | same | Rendering | HIGH |
| TR-facility-004 | research-facility | Per-volume lighting state machine and precedence | same | Rendering | HIGH |
| TR-facility-005 | research-facility | 17 switchable light volumes, glass overdraw: profile budget | same | Rendering | HIGH |
| TR-facility-006 | research-facility | Surveillance feeds (SubViewport inference) | same | Rendering | HIGH |
| TR-facility-010 | research-facility | Reduced-flash variants | same | UI | HIGH |
| TR-scare-012 | scare-events | Stingers, flash, beacons, surveillance frame, Compositor | same | Rendering | HIGH |
| TR-scare-008 | scare-events | Stinger cap, ducking, bus scales | `/architecture-decision spatial-audio-pipeline` | Audio | HIGH (`area_mask` default 0 in 4.7) |
| TR-facility-008 | research-facility | Zone ambience, occlusion, room IDs | same | Audio | HIGH |
| TR-borrowedface-005 | borrowed-face | Disguise copies body, outfit, animations, footstep set; per-character appearance data | `/architecture-decision borrowed-face-rendering` | Rendering | MEDIUM |
| TR-objectives-003 | survivor-objectives | Discovery: in view within 8 m, server visibility test | `/architecture-decision objective-selection-and-discovery` | Networking | LOW |
| TR-matchflow-008 | match-flow | Results payload; stats interface on every system | `/architecture-decision stats-and-results-interface` | Data | LOW |
| TR-index-012 | systems-index | HUD, Accessibility, Telemetry hooks (no GDD) | `/ux-design`, then UI ADR | UI | HIGH (dual focus, AccessKit) |
| TR-scare-009 | scare-events | Client accessibility hooks | `/ux-design accessibility` | UI | HIGH |
| TR-pings-007 | pings-and-callouts | Optional proximity voice | deferred | Audio | NOT SOURCEABLE |
| TR-pings-010 | pings-and-callouts | Voice transport | deferred | Audio | NOT SOURCEABLE |

## Cross-ADR Conflicts

Known conflict-prone areas: none recorded (`docs/consistency-failures.md` does not exist).

### C1: door and barricade state owner (State) — RESOLVED in this review
- ADR-0003 §6 and `architecture.md` said "Facility Map's authoritative open, closed and barricaded state"; `first-person-controller.md` rule 18 gives door rules to Survivor Defense; `research-facility.md` said only "the server owns"; the `systems-index.md` state table had no row, and ADR-0005 §5 makes state-table rows the registry keys.
- Impact: Controller prediction (ADR-0007), dash and LOS (ADR-0003), the PVS door cut (ADR-0004) and the door lock (ADR-0008) had no registry key to read.
- Resolution (designer decision 2026-10-12): Facility Map owns door open/closed; Survivor Defense owns barricade state (barricaded, break progress, lockout). Two rows added to the `systems-index.md` state table. Follow-up: ADR-0003 §6 wording ("open, closed and barricaded") should cite both owners.

### C2: owning client never receives modifier state (Integration, LOW)
- ADR-0002 §6 predicts movement modifiers "from the latest replicated registry state"; neither ADR-0002 §5's own-body snapshot nor ADR-0004's projection carries modifiers.
- Impact: every root, slow and lock is mispredicted until the server corrects it.
- Resolution: add the effective lock/root/slow to the owner's snapshot entry (amend ADR-0002 §5).

### C3: ray masks (Pattern, LOW)
- ADR-0003 §6 says world rays use "static geometry only"; ADR-0007 §5 later split `SIGHT` = world and `PROJECTILE` = world|glass, and door blockers are `StaticBody3D` too.
- Resolution: amendment note in ADR-0003 naming `PhysicsLayers.SIGHT` / `PROJECTILE`.

### C4: who times hiding and barricades (Pattern, LOW)
- ADR-0005 §4 lists "hiding; barricades" in Defense's phase; ADR-0008 §1 says only `HoldService` times holds.
- Resolution: reword ADR-0005 §4: Defense's phase runs non-hold timers only (rebarricade lockout, hide cue, stun and immunity).

### C5: `@abstract` placement (Engine syntax, MEDIUM)
- ADR-0005 and `architecture.md` write `@abstract class_name ServerEvent extends RefCounted` on one line; ADR-0008 and `current-best-practices.md` put `@abstract` on its own line. The one-line form is NOT SOURCEABLE from `docs/engine-reference/godot/`.
- Resolution: own-line form everywhere.

No performance-budget or initialisation-order conflicts; no 🔴 blocking conflicts.

## ADR Dependency Order

From `.claude/scripts/adr-dep-graph.sh`: 8 ADRs, 15 edges, no `CYCLE`, no `NO_DEPS_SECTION`.

1. Foundation: ADR-0001 hosting, session, join, reconnect
2. ADR-0002 authoritative sim, tick, input (requires 0001)
3. ADR-0003 lag compensation (0002); ADR-0004 replication scope (0001, 0002)
4. ADR-0005 events, registry, tick order (0002, 0004); ADR-0007 movement, physics, layers (0002, 0003)
5. ADR-0006 knobs (0001, 0002, 0005); ADR-0008 hold protocol (0002, 0004, 0005, 0007)

⚠️ Every dependency is Proposed; no ADR can be safely implemented until its parents are Accepted. Acceptance blockers:
- ADR-0001, 0002, 0003: the spike's deferred real-network tests; ADR-0003 also the pursuit-simulation rerun at 0.43 s.
- ADR-0004: spawner-leak spike case; authored visibility table (`research-facility.md`).
- ADR-0005, 0006, 0008: their headless verification scripts.
- ADR-0007: replay with gravity and floor snap.

## GDD Revision Flags

| GDD | Assumption | Reality | Action |
|---|---|---|---|
| `match-flow.md` Formulas | A config breaking `infiltration_end_s < evac_start_s` "is rejected at load and defaults are used" | ADR-0006 §4: refuse to host, no fallback (Proposed) | Fixed in this review |
| `monster-abilities.md` Formulas | `min(server_tick − view_tick, max_rewind_ms)`: ticks mixed with ms, no RTT bound | ADR-0003 §3 | Fixed in this review |

No GDD assumes behaviour contradicted by the engine reference.

## Engine Compatibility Issues

ADRs with Engine Compatibility section: 8 / 8, all Godot 4.7.2. Deprecated API references: none (ADR-0007's `WorldBoundaryShape3D`, `Area3D`, `device == 0` are prohibitions). Stale version references: none in ADRs; `modules/networking.md`, `physics.md`, `input.md` are 4.6 snapshots.

### Engine Specialist Findings (`godot-specialist`)

| ADR | Severity | Finding | Source |
|---|---|---|---|
| 0005 | HIGH | `Dictionary[StringName, Array[Callable]]` nests typed collections, which GDScript rejects; use `Dictionary[StringName, Array]` and cast on read | NOT SOURCEABLE (typed-collection nesting not in `current-best-practices.md`) |
| 0002, 0007 | HIGH | Reconciliation "restores the floor flag and normal", but `CharacterBody3D` has no documented floor-state setter; the first replayed step can lose floor snap. Define the restore (e.g. `apply_floor_snap()` after setting position) | NOT SOURCEABLE (`modules/physics.md`) |
| 0004 | HIGH | Spawner-leak case stays blocking; add `set_visibility_for` called after `spawn()` in the same frame | NOT SOURCEABLE (`modules/networking.md`) |
| 0004 | MEDIUM | First RPC to a node sends its path; a node named by player or peer ID leaks it. Per-peer RPCs must target fixed-name nodes; puppets carry no RPC | NOT SOURCEABLE |
| 0007 | MEDIUM | `InputEventMouseMotion.relative` scales with the 4.7 default stretch mode `canvas_items`; use `screen_relative` or pin stretch mode | `breaking-changes.md` (4.7 Project row); `screen_relative` NOT SOURCEABLE |
| 0007 | MEDIUM | Rotated move order, stand-up check and hide-exit placement assume same-frame Jolt query visibility of shape and position changes; add a verification item | NOT SOURCEABLE |
| 0002 | MEDIUM | Camera node and correction-offset child need `physics_interpolation_mode` OFF | `breaking-changes.md` (4.5 Physics row); OFF behaviour NOT SOURCEABLE |
| 0005 | MEDIUM | Cycle premise likely wrong: named-method `Callable` probably holds an object ID; the real cycle is module → registry → view → module state. Re-aim verification item 4 | NOT SOURCEABLE |
| 0005, 0008 | MEDIUM | Require every override to restate the parent's return type; the `void` case stays ADR-0008 verification item 1 | `breaking-changes.md` (4.7 GDScript row) |
| 0005 | MEDIUM | C5 above confirmed | NOT SOURCEABLE |
| 0006 | MEDIUM | A typo'd key in a `.tres` is likely dropped on load and caught only by the unset check; "typos fail at parse time" holds for code-side names only | NOT SOURCEABLE (inference) |
| 0007 | LOW | Add `floor_block_on_wall` to the data-driven floor settings (41° block AC depends on it) | NOT SOURCEABLE |
| 0007 | LOW | Verification item 1 answered: `3d/physics_engine="Jolt Physics"` | `prototypes/networking-spike/project.godot:14` |
| 0003 | LOW | C3 above confirmed as wording drift | ADR-0007 §5 |
| 0001 | LOW | Set `auth_callback` and `server_relay = false` before assigning `multiplayer_peer` | `modules/networking.md` example order |
| 0002 | LOW | ENet channel count on `create_server`/`create_client` not fixed; add to the loss-injection test | NOT SOURCEABLE |
| 0002, 0008 | LOW | `intent_timeout_ms` must convert through `Knobs.ticks()` (ADR-0006 §6) | ADR-0002 §1 |
| 0008 | LOW | Verification item 2 redundant: `PROJECTILE` excludes players; test door and glass LOS blocking instead | ADR-0007 §5 |

## Architecture Document Coverage

Every system in `systems-index.md` appears in `architecture.md`'s layer map; no orphaned architecture. `architecture.md` is stale since the ADRs:

- Document Status "ADRs Referenced: none"; ADR Audit "0/41 covered".
- Client frame interpolates remote players 100 ms behind; ADR-0003 chose 50 ms.
- `NetAuthority.submit_intent` / `rewound_positions` superseded by ADR-0002 `InputFrame` and ADR-0003 `RewindHistory` / `LagCompensation`.
- `Interactable extends Resource` with `can_start`, `on_cancel(actor, cause)`; ADR-0008 is `RefCounted` with `eligible`, `on_cancel(actor, progress_s, reason)`.
- Facility Map row lists "`Area3D` zones HIGH"; ADR-0007 §9 forbids `Area3D` for gameplay zones.
- Module table: Controller "owns doors" and Facility Map "owns door state" (superseded by C1).
- Open Questions on rewind budget, monster identity leak and spectator scope still open; resolved by ADR-0003 and ADR-0004.
- Layer map places the Controller in Core; `systems-index.md` and `architecture.md`'s own decision 2 call it Foundation.
- `systems-index.md` row 1 (Network Authority) still "Not Started — (architecture/ADR, after `/setup-engine`)".

---

## Verdict: CONCERNS

- No requirement rests on an Accepted ADR: 91 🟡 rows cap the verdict at CONCERNS. Route out: `/architecture-decision accept ADR-NNNN` once each ADR's verification items pass.
- No blocking cross-ADR conflict; C1 resolved; C2–C5 are amendments.
- Not FAIL despite ❌ gaps in Core-layer systems (Facility Map lighting, Borrowed Face rendering): at `workflow: standard` those belong to should-have ADRs, which `architecture.md` schedules before the relevant system is built. Counting them as critical now would make this FAIL.

### Required ADRs (most foundational first)

1. Lighting states and Blackout (Facility Map, Core; HIGH)
2. Borrowed Face rendering and replication (Core; MEDIUM)
3. Spatial audio and cue pipeline (HIGH)
4. Objective candidate selection and discovery (LOW)
5. Stats and results interface (LOW; results are MVP)
6. UI and input-focus framework, after `/ux-design` (HIGH)

Amendments before acceptance: C2–C5 and the HIGH specialist findings (ADR-0005 typed nesting, ADR-0002/0007 floor restore, ADR-0004 spawner and RPC-path cases).
