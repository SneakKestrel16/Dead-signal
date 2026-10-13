# Architecture Review Report

Date: 2026-10-12 (second run)
Engine: Godot 4.7.2 (GDScript, Jolt, Forward+)
Mode: full, `workflow: standard`
GDDs Reviewed: 10 system GDDs + `systems-index.md`, `game-concept.md`, `design/levels/research-facility.md`
ADRs Reviewed: 9 (ADR-0001 to ADR-0009, all Proposed)
Prior report: [`architecture-review-2026-10-12.md`](architecture-review-2026-10-12.md). Freshness check: all eight ADRs CHANGED (amendments), ADR-0009 NEW, `first-person-controller.md`, `monster-abilities.md` and `systems-index.md` CHANGED, so a full re-run.

Hashes are of the reviewed content after this review's sync fixes (N2, N3, `architecture.md` drift).

```
Reviewed-Content-Hash: docs/architecture/adr-0001-hosting-session-join-reconnect.md acf172593ac3118d60a8b778e413ad095cd9a603
Reviewed-Content-Hash: docs/architecture/adr-0002-authoritative-sim-tick-input.md 8e65fd72a7e3501b330ff1b5ec4df3df2118f4d9
Reviewed-Content-Hash: docs/architecture/adr-0003-lag-compensation-rewind.md 4338ad63e8d5332fea02670466ba3bcd864873fc
Reviewed-Content-Hash: docs/architecture/adr-0004-replication-scope-information-hiding.md ad743a1c8cc4a9977aa278a581cce95887dec91b
Reviewed-Content-Hash: docs/architecture/adr-0005-event-catalog-state-registry-tick-order.md f667613eac2637a6c2e08691378f4058769d5e0d
Reviewed-Content-Hash: docs/architecture/adr-0006-data-driven-configuration.md 20b5b829dcb3c23298184895ceca4d7ebf29979f
Reviewed-Content-Hash: docs/architecture/adr-0007-movement-physics-collision-layers.md d4974ee92b0566fa73903f339808d74768e522f6
Reviewed-Content-Hash: docs/architecture/adr-0008-hold-to-interact-protocol.md 5d49510b622f0c9ccd42906840e7eb1c853b8ae3
Reviewed-Content-Hash: docs/architecture/adr-0009-lighting-states-and-blackout.md b31c20dae47ecbfe7768022e772d6152ee6cf747
Reviewed-Content-Hash: design/gdd/borrowed-face.md a6e37bc40ff1e93d169121415eb97e772db7f7b0
Reviewed-Content-Hash: design/gdd/downing-and-rescue.md 90055368fb0f9b69396e05a73d4844fd619fd0d9
Reviewed-Content-Hash: design/gdd/first-person-controller.md ece539321117df587b419047f771c0f9478faf3f
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
Reviewed-Content-Hash: design/gdd/monster-abilities.md 0d6469f4b32493b026a93d3470705a17f870b489
Reviewed-Content-Hash: design/gdd/pings-and-callouts.md 4fb044ae16540ac3e880be8ff51289a163688b14
Reviewed-Content-Hash: design/gdd/scare-events.md 86b0e24ffa4156b6425a357c440ca4ec83d24eed
Reviewed-Content-Hash: design/gdd/survivor-defense.md c1599d79cc292de2110218f1241d95960bbbc50b
Reviewed-Content-Hash: design/gdd/survivor-objectives.md 2b0fa195aa64cfa7d1a0e128c2c5519b17b514e2
Reviewed-Content-Hash: design/gdd/systems-index.md ed133b2e2a5b12cdf06f83dde1b12db4e75bb143
Reviewed-Content-Hash: design/levels/research-facility.md 3ffe032c5a8721548b5d097545636c17ba818773
```

---

## Traceability Summary

Total requirements: 138. No new TR-IDs: the GDD changes since the first run are tuning ranges and one state-table row already covered by TR-facility-004 and TR-index-009.

| Status | First run | This run |
|---|---|---|
| ✅ Covered (Accepted ADR) | 0 | 0 |
| 🟡 Covered (Proposed ADR) | 91 | 104 |
| ⚠️ Partial | 28 | 23 |
| ❌ Gap | 16 | 8 |
| — No ADR needed | 3 | 3 |

Rows that moved:

| TR | Was | Now | Why |
|---|---|---|---|
| TR-index-009, TR-scare-007, TR-facility-004, -005, -006, -010 | ❌ | 🟡 | ADR-0009 |
| TR-scare-012 | ❌ | ⚠️ | ADR-0009 covers flicker, beacons and the monitor frame; stingers, screen flash and camera reaction have no ADR |
| TR-scare-009 | ❌ | ⚠️ | ADR-0009 §7 covers flash scale and the 3/s cap per flicker; other hooks wait for `/ux-design` and the UI ADR |
| TR-facility-003, TR-monster-009 | ⚠️ | 🟡 | Lighting and feeds covered by ADR-0009 |
| TR-index-007, TR-controller-004, TR-defense-004, TR-monster-010 | ⚠️ | 🟡 | C2 resolved: ADR-0002 §5 carries the effective modifier in the owner's snapshot |
| TR-defense-007 | ⚠️ | 🟡 | ADR-0003 §6 cites both door and barricade owners (C1) |

Registry text revised (IDs unchanged, registry version 3): TR-controller-009 (accel ≤ 0.09 s), TR-index-004 (stale row count dropped), TR-scare-007 (Scare Events requests no lighting state).

Full matrix: [`requirements-traceability.md`](requirements-traceability.md).

## Coverage Gaps (no ADR exists)

None is in the critical set at `workflow: standard`.

| TR | GDD | Requirement | Suggested ADR | Domain | Engine risk |
|---|---|---|---|---|---|
| TR-borrowedface-005 | borrowed-face | Disguise copies body, outfit, animations, footstep set | `/architecture-decision borrowed-face-rendering` | Rendering | MEDIUM |
| TR-scare-008 | scare-events | Stinger cap, ducking, bus scales | `/architecture-decision spatial-audio-pipeline` | Audio | HIGH (`area_mask` default 0 in 4.7) |
| TR-facility-008 | research-facility | Zone ambience, occlusion, room IDs | same | Audio | HIGH |
| TR-objectives-003 | survivor-objectives | Discovery: in view within 8 m | `/architecture-decision objective-selection-and-discovery` | Networking | LOW |
| TR-matchflow-008 | match-flow | Results payload; stats interface | `/architecture-decision stats-and-results-interface` | Data | LOW |
| TR-index-012 | systems-index | HUD, Accessibility, Telemetry hooks (no GDD) | `/ux-design`, then UI ADR | UI | HIGH |
| TR-pings-007, TR-pings-010 | pings-and-callouts | Proximity voice and its transport | deferred | Audio | NOT SOURCEABLE |

## Cross-ADR Conflicts

Known conflict-prone areas: none recorded (`docs/consistency-failures.md` does not exist).

First-run C2 to C5 are resolved by the amendments in 68930a7 and 0435214. No 🔴 conflicts.

### N1: ADR-0009 knobs have no section (Integration, LOW) — OPEN
- ADR-0006 §1 fixes the section list; ADR-0009 adds `light_fade_s`, `max_flashes_per_s`, `max_shadowed_omni`, `max_shadowed_spot` and `feed_resolution` with no owning section.
- The two shadow caps and `feed_resolution` are client render settings; whether they belong in the host-client digest (ADR-0006 §7) is undecided.
- Resolution: amend ADR-0006 §1 (e.g. a `FacilityKnobs` section, `max_flashes_per_s` in `ScareKnobs`) or rule client render settings out of knobs.

### N2: Facility Map missing as `AbilityUsed` consumer (Integration, LOW) — RESOLVED in this review
- ADR-0009 §2 subscribes Facility Map to `AbilityUsed` (Blackout); the `systems-index.md` event row did not list it. Consumer added.

### N3: Scare Events "requests" lighting (Pattern, LOW) — RESOLVED in this review
- `scare-events.md` rule 22 and `architecture.md` said Scare Events requests lighting states; ADR-0009 §7 says it requests nothing, because both systems react to the same events. Rule 22, the `architecture.md` module row and TR-scare-007 reworded.

## ADR Dependency Order

From `.claude/scripts/adr-dep-graph.sh`: 9 ADRs, 21 edges, no `CYCLE`, no `NO_DEPS_SECTION`.

1. Foundation: ADR-0001 hosting, session, join, reconnect
2. ADR-0002 authoritative sim, tick, input (0001)
3. ADR-0003 lag compensation (0002); ADR-0004 replication scope (0001, 0002)
4. ADR-0005 events, registry, tick order (0002, 0004); ADR-0007 movement, physics, layers (0002, 0003)
5. ADR-0006 knobs (0001, 0002, 0005); ADR-0008 hold protocol (0002, 0004, 0005, 0007)
6. ADR-0009 lighting and Blackout (0002, 0004, 0005, 0006, 0007, 0008)

⚠️ Every dependency is Proposed. Remaining acceptance blockers (results in `prototypes/adr-verification/README.md`):
- ADR-0001, 0002, 0003: real-network tests (WAN, NAT, upload, clock drift); ADR-0002 item 5 and ADR-0006 item 4 cross-machine NOT RUN.
- ADR-0004: item 1 now passes on one machine.
- ADR-0008: item 3 waits on `HoldService`.
- ADR-0009: the greybox rendering spike (Verification 1–10).

## GDD Revision Flags

None. No HIGH engine finding contradicts a GDD assumption. The first run's two flags were fixed then; N2 and N3 above were wording syncs, not design changes.

## Engine Compatibility Issues

ADRs with Engine Compatibility section: 9 / 9, all Godot 4.7.2. Deprecated API references: none (ADR-0009 uses `get_world_3d()`). Stale version references: none in ADRs; `modules/*.md` remain 4.6 snapshots. ADR-0009's sourced claims (D3D12 default, glow before tonemapping, Compositor) match `modules/rendering.md`; `Light3D`, Forward+ cluster and shadow limits and `SubViewport` cost are NOT SOURCEABLE and listed as Verification 1–10.

### Engine Specialist Findings (`godot-specialist`)

No HIGH findings. The five amended assumptions are confirmed by measurement: `apply_floor_snap()` restore (ADR-0002 item 7), `screen_relative` unscaled (ADR-0007 item 8), Jolt last-step query visibility handled by ADR-0007 §6/6a (item 7), `Dictionary[StringName, Array]` (ADR-0005 item 6), spawn then `set_visibility_for` in one frame (ADR-0004 items 1–2).

| ADR | Severity | Finding | Fix | Source |
|---|---|---|---|---|
| 0009 | MEDIUM | Shader Baker cited as a mid-round hitch fix; the reference says only that it shortens startup | Rely on the load-time pre-warm; drop the claim | `modules/rendering.md`; rest NOT SOURCEABLE |
| 0009 | MEDIUM | A one-frame light toggle only compiles pipelines for geometry a camera draws | Pre-warm with a camera sweep per volume behind the loading screen; measure in Verification 9 | NOT SOURCEABLE |
| 0009 | MEDIUM | Clipping light range to the volume leaves corners dark and pushes toward more lights and cluster caps | Weigh `light_cull_mask` per volume (20 layers, shared with the feed `cull_mask`) in Verification 6 | NOT SOURCEABLE |
| 0009 | MEDIUM | Positional shadow atlas is per viewport; the feed `SubViewport` uses its own default | Set the feed's `positional_shadow_atlas_size` (0 = no shadows); fold into Verification 7 and 10 | NOT SOURCEABLE |
| 0009 | MEDIUM | Feed camera reuses the main `WorldEnvironment` (glow, SSAO, SSR, fog run twice) | Give the feed `Camera3D` its own cheap `Environment` | NOT SOURCEABLE |
| 0009 | MEDIUM | Flicker parity holds only if the 3/s clamp is applied in the per-tick precompute, not per rendered frame | Clamp in the precompute; apply only flash scale at render time | ADR-0009 §7 (logic) |
| 0009 | MEDIUM | Shadow cap counted per visibility set; the renderer culls per view, and the feed is a second view | Count `max_shadowed_omni` / `_spot` per rendered view | NOT SOURCEABLE |
| 0009 | LOW | Toggling `visible` on shadowed lights churns shadow atlas slots; runtime `shadow_enabled` changes can compile | Flicker with `light_energy` only | NOT SOURCEABLE |
| 0009 | LOW | Seeded `RandomNumberGenerator` is deterministic per build; a stateless hash of `(seed, step)` removes call-order risk | Optional; Verification 5 still runs | `prototypes/adr-verification/README.md` 0002-5 |
| 0009 | LOW | Parameter `seed` shadows global `seed()` (GDScript warning) | Rename `flicker_seed` | NOT SOURCEABLE |
| 0009 | LOW | `UPDATE_DISABLED` keeps the last frame, which flashes on reopen; knob named `max_shadowed_lights` in Risks vs `_omni`/`_spot` in Decision 6 | Clear the feed texture on off; one knob name | ADR text |
| 0009 | LOW | `_process` for light energy is correct: interpolation smooths transforms only | None | `breaking-changes.md` 4.5 row |
| 0002, 0004, 0005, 0007 | LOW | Body text still says "training data / until it passes" for items now passed (0002 rule 6 step 1, 0004 §7, 0005 §2, 0007 mouse look) | Point those lines at the Verification results | ADR text vs prototype README |

## Architecture Document Coverage

Every system in `systems-index.md` appears in `architecture.md` v2; no orphaned architecture. The first run's staleness list is cleared. Two drifts found and fixed in this review: the Data Flow tick order lacked the `FacilityMap` step (ADR-0005 §4 step 4a), and the Scare Events row said it consumes "Facility Map lighting requests" (N3).

---

## Verdict: CONCERNS

- No requirement rests on an Accepted ADR: 104 🟡 rows cap the verdict at CONCERNS. Route out: `/architecture-decision accept ADR-NNNN` once each ADR's verification items pass.
- No blocking cross-ADR conflict; N1 is an amendment.
- Remaining ❌ gaps belong to should-have or deferred ADRs at `workflow: standard`.

### Required ADRs (most foundational first)

1. Borrowed Face rendering and replication (Core; MEDIUM)
2. Spatial audio and cue pipeline (HIGH)
3. Objective candidate selection and discovery (LOW)
4. Stats and results interface (LOW; results are MVP)
5. UI and input-focus framework, after `/ux-design` (HIGH)

Amendments before acceptance: N1 (ADR-0006 knob sections), the ADR-0009 specialist MEDIUM items, and the stale "unverified" wording in ADR-0002/0004/0005/0007.
