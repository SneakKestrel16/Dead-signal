# Architecture Review Report

Date: 2026-10-12 (third run)
Engine: Godot 4.7.2 (GDScript, Jolt, Forward+)
Mode: full, `workflow: standard`, `automation: autonomous` (write approvals taken as [A], logged here)
GDDs Reviewed: 10 system GDDs + `systems-index.md`, `game-concept.md`, `design/levels/research-facility.md` (24 files in `design/gdd/`, 11 of them cross-review reports)
ADRs Reviewed: 13 (ADR-0001 to ADR-0013, all Proposed)
Prior report: [`architecture-review-2026-10-12b.md`](architecture-review-2026-10-12b.md). Freshness check: ADR-0002, 0004, 0005, 0006, 0007, 0009 CHANGED (amendments), ADR-0010 to 0013 NEW, `scare-events.md`, `survivor-objectives.md`, `systems-index.md` CHANGED, so a full re-run.

```
Reviewed-Content-Hash: docs/architecture/adr-0001-hosting-session-join-reconnect.md acf172593ac3118d60a8b778e413ad095cd9a603
Reviewed-Content-Hash: docs/architecture/adr-0002-authoritative-sim-tick-input.md bd5c066ae85af9aa0fc2f8c40dbe471b983094ca
Reviewed-Content-Hash: docs/architecture/adr-0003-lag-compensation-rewind.md 4338ad63e8d5332fea02670466ba3bcd864873fc
Reviewed-Content-Hash: docs/architecture/adr-0004-replication-scope-information-hiding.md 7e692431781e821d18d3eefd142b3aa02ace1f10
Reviewed-Content-Hash: docs/architecture/adr-0005-event-catalog-state-registry-tick-order.md f242f31aefa9e2bbd2f74848ddfe66ac31312ded
Reviewed-Content-Hash: docs/architecture/adr-0006-data-driven-configuration.md 60fe0b43e19137bddb5bc9b2fcffa817e2bdb8f4
Reviewed-Content-Hash: docs/architecture/adr-0007-movement-physics-collision-layers.md 487a83ce194eb5f31f306a216497379d3d9effdc
Reviewed-Content-Hash: docs/architecture/adr-0008-hold-to-interact-protocol.md 5d49510b622f0c9ccd42906840e7eb1c853b8ae3
Reviewed-Content-Hash: docs/architecture/adr-0009-lighting-states-and-blackout.md acbb04670727490bd652398a419bad9e360c87fc
Reviewed-Content-Hash: docs/architecture/adr-0010-borrowed-face-rendering.md 0c2ad07d5d0e91a068017123735be49d05e29388
Reviewed-Content-Hash: docs/architecture/adr-0011-round-stats-and-results-payload.md d035e561e3f022779bfd4789378c5b5a1c36519f
Reviewed-Content-Hash: docs/architecture/adr-0012-objective-discovery.md 2089c7753ca53b4d90ffd76bf30bb202528f3edc
Reviewed-Content-Hash: docs/architecture/adr-0013-spatial-audio-pipeline.md c34f556976cb410e279e605514ae59cd167a5904
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
Reviewed-Content-Hash: design/gdd/lobby-role-assignment.md 6c4d3679e177d8fe8c9e624c20e935af38886958
Reviewed-Content-Hash: design/gdd/match-flow.md c842f7c0741439c0a5fb0cd511457eac9a0cc0c9
Reviewed-Content-Hash: design/gdd/monster-abilities.md 0d6469f4b32493b026a93d3470705a17f870b489
Reviewed-Content-Hash: design/gdd/pings-and-callouts.md 4fb044ae16540ac3e880be8ff51289a163688b14
Reviewed-Content-Hash: design/gdd/scare-events.md 92893e75198057b0ddc61a503fe363c803bac569
Reviewed-Content-Hash: design/gdd/survivor-defense.md c1599d79cc292de2110218f1241d95960bbbc50b
Reviewed-Content-Hash: design/gdd/survivor-objectives.md dfaa6cef738a33fd5c678b594b5abc1bfd0f3610
Reviewed-Content-Hash: design/gdd/systems-index.md 52b49442fbc8deac871cfde33bfe4c8c1d6f5477
Reviewed-Content-Hash: design/levels/research-facility.md a50a3fe81d5c8e2447aabb470a2e13e2f65586cb
```

---

## Traceability Summary

Total requirements: 138. No new TR-IDs and no GDD requirement reworded: the GDD edits since the last run are the `discover_fov_deg` knob (TR-objectives-003), a link update in `scare-events.md` and the HUD row status in `systems-index.md`. Registry version 3 to 4 (no entries changed). The new `design/ux/*.md` and `design/accessibility-requirements.md` are not GDDs and were not extracted; the UI ADR (below) is where they get traced.

| Status | 12b | This run |
|---|---|---|
| ✅ Covered (Accepted ADR) | 0 | 0 |
| 🟡 Covered (Proposed ADR) | 104 | 114 |
| ⚠️ Partial | 23 | 19 |
| ❌ Gap | 8 | 2 |
| — No ADR needed | 3 | 3 |

Rows that moved:

| TR | Was | Now | Why |
|---|---|---|---|
| TR-borrowedface-005 | ❌ | 🟡 | ADR-0010 |
| TR-scare-008, TR-facility-008 | ❌ | 🟡 | ADR-0013 |
| TR-objectives-003 | ❌ | 🟡 | ADR-0012 |
| TR-matchflow-008 | ❌ | 🟡 | ADR-0011 |
| TR-borrowedface-006, TR-borrowedface-011 | ⚠️ | 🟡 | ADR-0010 (warp, swap) and ADR-0013 (distortion audio) |
| TR-controller-011, TR-monster-011 | ⚠️ | 🟡 | ADR-0013 catalog and ranges, ADR-0010 footstep set |
| TR-downing-007 | ⚠️ | 🟡 | ADR-0011 `stats.downing` |
| TR-index-012 | ❌ | ⚠️ | ADR-0011 covers only the stat-hook half; HUD and Accessibility contract has no UI ADR |
| TR-pings-004 | ⚠️ | ⚠️ | audio half now ADR-0013; feed line and arrow still need the UI ADR |

Unchanged on purpose: TR-objectives-002 (ADR-0012 covers discovery, not seeded candidate selection), TR-scare-009 and TR-scare-012 (stingers and volumes now in ADR-0013; screen flash, camera reaction and flinch-toggle transport still have no ADR), TR-defense-011.

Full matrix: [`requirements-traceability.md`](requirements-traceability.md) (updated).

## Coverage Gaps (no ADR exists)

None in the critical set at `workflow: standard`.

| TR | GDD | Requirement | Suggested ADR | Domain | Engine risk |
|---|---|---|---|---|---|
| TR-pings-007, TR-pings-010 | pings-and-callouts | Proximity voice and transport | deferred (ADR-0013 reserves the `ProximityVoice` bus) | Audio | NOT SOURCEABLE |

Largest open partials: UI and input-focus framework (TR-index-012, TR-pings-005, TR-pings-004 feed; HIGH), seeded objective candidate selection (TR-objectives-002; LOW), scare screen flash and camera reaction (TR-scare-009/-012).

## Cross-ADR Conflicts

Known conflict-prone areas: none recorded (`docs/consistency-failures.md` does not exist; nothing appended). No 🔴 conflicts. N1 (ADR-0006 knob sections) is RESOLVED: ADR-0006 §1 now defines `FacilityKnobs` and puts the render caps in the digest.

New, all open and amendment-sized:

### N4: ADR-0011 stats keys are not rows of the systems-index state table (Integration, LOW)
- ADR-0005 §5: "the registry's keys are the rows of the `systems-index.md` state table." ADR-0011 registers six `stats.*` keys and says the owner table lives "in `systems-index.md`"; the index has no such rows.
- Resolution: add the six rows to the index state table, or amend ADR-0005 §5 to allow keys declared by an ADR.

### N5: ADR-0013 knobs have no GDD owner or Safe Range (Integration, LOW)
- ADR-0006 §1: every knob is one `@export_range` whose range is the owning GDD's Safe Range. `duck_db`, `duck_attack_s`, `duck_release_s`, `sfx_pool_size`, `occlusion_lowpass_hz`, `occlusion_db`, `occlusion_recheck_s` appear in no GDD (`scare-events.md` has only `stinger_max_db_rel`).
- Resolution: add them to `scare-events.md` / `research-facility.md` Tuning Knobs as proposed, as was done for `discover_fov_deg`; decide whether the client-only mixing knobs belong in the host-client digest.

### N6: Body flashlights, ADR-0010 §8 vs ADR-0009 and survivor-defense (Pattern, MEDIUM)
- ADR-0010 §8 makes body flashlights shadowless and says they "count toward the ADR-0009 per-view light budget." ADR-0009 caps only shadowed omni/spot lights and never mentions flashlights in the budget.
- A shadowless spot light lights surfaces behind walls and furniture. `survivor-defense.md` rule 3 says the cone is seen by all clients, so bleed through geometry is visible to everyone, and the local player's own flashlight, the main horror tool, loses shadows (ADR-0010 §9 leaves the local light unstated).
- Resolution: state the flashlight shadow policy in ADR-0009 (count one shadowed spot per survivor in view, or accept bleed and say so), then fix ADR-0010 §8 to match.

### N7: Footstep identity chain is not closed (Integration, LOW)
- ADR-0004 §6 sends "sound or voice set"; ADR-0010 §2 stores `footstep_set` per `Appearance`; ADR-0013 §2 maps sound ids to streams. Nothing says how a set name plus gait resolves to a catalog id.
- ADR-0013 §7 scales the footstep send radius in B3, so a footstep's `max_distance` no longer equals the radius it was sent with, against ADR-0013's own guideline. Harmless (the client plays nothing it was not sent) but the guideline needs an exception.
- Resolution: one line in ADR-0013 §2 (`<set>.<gait>` key) and a carve-out in the guideline.

### N8: Occlusion ignores doors and runs outside the physics step (Integration, MEDIUM)
- ADR-0013 §8 casts one `SIGHT` ray; ADR-0003/0007/0012 treat doors and barricades as analytic boxes that are not on `SIGHT`, so a closed door never occludes. The ray is also cast on event arrival, outside `_physics_process`, which ADR-0008 says the engine reference does not cover.
- Resolution: reuse `SightTest`'s ray-plus-doors path with no cone, and queue the cast to `AudioDirector._physics_process`.

## ADR Dependency Order

From `.claude/scripts/adr-dep-graph.sh`: 13 ADRs, 38 edges, no `CYCLE`, no `NO_DEPS_SECTION`.

1. Foundation: ADR-0001 hosting, session, join, reconnect
2. ADR-0002 authoritative sim, tick, input (0001)
3. ADR-0003 lag compensation (0002); ADR-0004 replication scope (0001, 0002)
4. ADR-0005 events, registry, tick order (0002, 0004); ADR-0007 movement, physics, layers (0002, 0003)
5. ADR-0006 knobs (0001, 0002, 0005); ADR-0008 hold protocol (0002, 0004, 0005, 0007); ADR-0011 stats and results (0004, 0005)
6. ADR-0009 lighting and Blackout (0002, 0004, 0005, 0006, 0007, 0008); ADR-0012 objective discovery (0002, 0004, 0005, 0006, 0007)
7. ADR-0010 Borrowed Face rendering (0002, 0004, 0006, 0007, 0009); ADR-0013 spatial audio (0004, 0005, 0006, 0007, 0009)

⚠️ Every dependency is Proposed, so nothing downstream may be implemented as Accepted. Acceptance blockers: ADR-0001/0002/0003 real-network tests; ADR-0008 item 3 (`HoldService`); ADR-0009 greybox rendering spike; ADR-0010 Verification 1 to 7; ADR-0011 Verification 1; ADR-0012 Verification 1 to 2; ADR-0013 Verification 1 to 4.

## GDD Revision Flags

None. No HIGH engine finding contradicts a GDD assumption. `borrowed-face.md` copies the name label while `lobby-role-assignment.md` rule 11 shows none; the GDD already marks that "currently vacuous", so it is consistent. N5 and N6 are knob and flashlight-policy additions, not design contradictions. Systems index unchanged.

## Engine Compatibility Issues

ADRs with Engine Compatibility section: 13 / 13, all Godot 4.7.2. Deprecated API references: none (ADR-0010 correctly avoids `playback_active`; ADR-0009 uses `get_world_3d()`). Stale version references: none; `modules/*.md` remain 4.6 snapshots. Engine claims in ADR-0010 to 0013 are mostly NOT SOURCEABLE and carried as Verification Required items.

### Engine Specialist Findings (`godot-specialist`, second opinion on ADR-0010 to 0013)

| ADR | Severity | Finding | Fix | Source |
|---|---|---|---|---|
| 0010 | HIGH | §5 "seek to the same normalised clip time": `AnimationNodeStateMachinePlayback` and `AnimationTree` have no seek; only `AnimationPlayer` does. Read side exists (`get_current_play_position()`, `get_current_length()`); write side needs an `AnimationNodeTimeSeek` per gait state, in seconds. BlendSpace1D walk/sprint clips differ in length, so "normalised" needs a sync rule | Require a TimeSeek node in each gait state and convert to seconds of the dominant clip; rewrite Verification 6 around it | NOT SOURCEABLE |
| 0010 | HIGH | A freshly added `AnimationTree` may not process before that frame renders: one frame of rest pose is a visible tell | Call `AnimationMixer.advance(0.0)` after `start(state, false)` and the seek; add to Verification 6 | NOT SOURCEABLE |
| 0010 | MEDIUM | §6 `material_overlay` is a second draw; displacing `VERTEX` in it moves only the overlay copy, which is depth-tested against the base mesh (ghost shell, not a warp) | Warp in the overlay fragment pass, or use `material_override` / warp-variant materials; pick one | NOT SOURCEABLE |
| 0010 | MEDIUM | Pre-warm renders plain forms only; overlay, reduced-motion tint, `SHADOWS_ONLY` and lit-flashlight variants are first seen mid-round. "Instancing alone compiles no pipelines" is unsourced | Add those variants to the pre-warm pass; evaluate Shader Baker; mark the claim NOT SOURCEABLE | `current-best-practices.md` Rendering (4.5) |
| 0010 | LOW | `LookAtModifier3D.relative` default change is listed under 4.6 but is in the 4.6 to 4.7 table; `SkeletonModifier3D` dates from 4.3, `LookAtModifier3D` from 4.4 | Correct the version labels | `breaking-changes.md` |
| 0011 | MEDIUM | `Array(survivors)` / `Dictionary(monster)` return the same typed container, so `to_dict()` can still send typed containers | Build fresh untyped containers (`out.assign(...)`, `merge`); unit test `is_typed() == false` | NOT SOURCEABLE |
| 0011 | LOW | Telemetry reading views "at round end" can hit a freed owner after teardown; Verification 1 is vacuous (ENet fragments reliable packets) | Telemetry consumes the `RoundEnded` payload; replace Verification 1 with a byte budget | NOT SOURCEABLE |
| 0012 | MEDIUM | 5 cm rule rationale is muddled: a point inside a convex collider blocks its own ray regardless of `hit_back_faces`; the missed case is the eye end (`hit_from_inside` false lets a clipped eye see through a wall) | Restate: ray ends must be outside any SIGHT collider; keep eye out of geometry or set `hit_from_inside = true` | NOT SOURCEABLE |
| 0012 | LOW | `intersect_ray` listed as a post-cutoff API; only the Jolt backend is | Change entry to "none; Jolt backend" | `modules/physics.md` |
| 0013 | MEDIUM | Occlusion ray ignores doors (N8) | Reuse `SightTest` path | ADR-0012 §1 |
| 0013 | MEDIUM | Footstep events sit on the floor, so the listener-to-source ray can hit the floor and route every footstep to `*Occluded` | Lift the ray end (about 0.3 m); test an open-floor case | NOT SOURCEABLE |
| 0013 | MEDIUM | Duck counter leaks: `stop()` (steal, re-route) emits no `finished`, loops never finish, so Scare stays ducked | Decrement explicitly on steal/stop; count by voice handle or only non-looping cues | NOT SOURCEABLE |
| 0013 | LOW | Client ray outside `_physics_process` (N8); bus ordering rule is in the official docs, not NOT SOURCEABLE; local player's own footsteps trigger ducking | Queue rays to physics step; cite `tutorials/audio/audio_buses`; exclude own footsteps from the duck trigger or confirm intent | official docs |

The reference itself needs one fix: `breaking-changes.md` attributes the 4.7 `area_mask` default to `AudioStreamPlayer`; the property is on `AudioStreamPlayer3D`.

## Architecture Document Coverage

Every system in `systems-index.md` appears in `architecture.md`; no orphaned architecture. Drift found and fixed in this review: `architecture.md` referenced ADR-0001 to 0009 only and said "Eight ADRs exist". Now updated to ADR-0013: header, ADR Audit rows 0010 to 0013, coverage line (114 / 19 / 2 / 3), Required ADRs marked Written, and a Presentation paragraph naming `BodyPuppet`/`ClientBodies`, `AudioDirector`, the `*StatsView`s and `SightTest`. Still missing: Accessibility Options, HUD and Match Telemetry have no GDD or UI ADR.

---

## Verdict: CONCERNS

- No requirement rests on an Accepted ADR: 114 🟡 rows cap the verdict at CONCERNS. Route out: `/architecture-decision accept ADR-NNNN` once each ADR's verification items pass.
- No blocking cross-ADR conflict. N6 and N8 are MEDIUM amendments; N4, N5, N7 are LOW.
- Two HIGH engine findings (ADR-0010 animation hand-off) are design-level errors in a Proposed ADR, to be amended before acceptance, not blocking at `workflow: standard`.
- The two remaining gaps are deferred voice features.

### Required ADRs (most foundational first)

1. UI and input-focus framework, after the existing `design/ux/*.md` specs (HIGH; TR-index-012, TR-pings-004/-005)
2. Seeded objective candidate selection (LOW; TR-objectives-002), or fold into an ADR-0012 amendment
3. Scare screen flash and camera reaction presentation (LOW; TR-scare-009/-012)
4. Proximity voice transport, deferred

Amendments before acceptance: ADR-0010 (animation hand-off, warp method, pre-warm variants, flashlight policy), ADR-0013 (occlusion doors/floor/physics step, duck counter leak, knob ownership), ADR-0011 (untyped `to_dict()`, registry keys), ADR-0012 (5 cm rule wording), ADR-0009 (flashlight budget).
