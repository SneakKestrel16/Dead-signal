# Architecture Review Report

Date: 2026-10-12 (fourth run)
Engine: Godot 4.7.2 (GDScript, Jolt, Forward+)
Mode: full, `workflow: standard`, `automation: autonomous` (write approvals taken as [A], logged here)
GDDs Reviewed: 10 system GDDs + `systems-index.md`, `game-concept.md`, `design/levels/research-facility.md` (24 files in `design/gdd/`, 11 of them cross-review reports)
ADRs Reviewed: 15 (ADR-0001 to ADR-0015, all Proposed)
Prior report: [`architecture-review-2026-10-12c.md`](architecture-review-2026-10-12c.md) (CONCERNS). Freshness check: ADR-0002, 0006, 0009 to 0013, `scare-events.md`, `systems-index.md` CHANGED; ADR-0014 and ADR-0015 NEW (structural change), so a full re-run. The reviewer authored no ADR.

```
Reviewed-Content-Hash: docs/architecture/adr-0001-hosting-session-join-reconnect.md acf172593ac3118d60a8b778e413ad095cd9a603
Reviewed-Content-Hash: docs/architecture/adr-0002-authoritative-sim-tick-input.md 99cdcf767262cd71fa667d70b88c798d99a8c62a
Reviewed-Content-Hash: docs/architecture/adr-0003-lag-compensation-rewind.md 4338ad63e8d5332fea02670466ba3bcd864873fc
Reviewed-Content-Hash: docs/architecture/adr-0004-replication-scope-information-hiding.md 7e692431781e821d18d3eefd142b3aa02ace1f10
Reviewed-Content-Hash: docs/architecture/adr-0005-event-catalog-state-registry-tick-order.md f242f31aefa9e2bbd2f74848ddfe66ac31312ded
Reviewed-Content-Hash: docs/architecture/adr-0006-data-driven-configuration.md b8860c6955e39712fc0dd8ac96cae9f6feec9cd3
Reviewed-Content-Hash: docs/architecture/adr-0007-movement-physics-collision-layers.md 487a83ce194eb5f31f306a216497379d3d9effdc
Reviewed-Content-Hash: docs/architecture/adr-0008-hold-to-interact-protocol.md 5d49510b622f0c9ccd42906840e7eb1c853b8ae3
Reviewed-Content-Hash: docs/architecture/adr-0009-lighting-states-and-blackout.md fb129bb1fcdc799a760f688db2f2a2014d8b92c2
Reviewed-Content-Hash: docs/architecture/adr-0010-borrowed-face-rendering.md 582135ffce93c7073038baa3901f38b4f54e0925
Reviewed-Content-Hash: docs/architecture/adr-0011-round-stats-and-results-payload.md 9563b15eb57e5c5ace85eb972371c30ce090253e
Reviewed-Content-Hash: docs/architecture/adr-0012-objective-discovery.md 34abbd5c902645fea5c7b3d8ec6f97f2f255efc0
Reviewed-Content-Hash: docs/architecture/adr-0013-spatial-audio-pipeline.md 3fef6905491ed6a61a1f07633a7f9704cb87db06
Reviewed-Content-Hash: docs/architecture/adr-0014-ui-and-input-focus.md e8b9aff4e4613416d1f5f81aed5c0d4dc79fe3f9
Reviewed-Content-Hash: docs/architecture/adr-0015-scare-presentation-and-view-offset.md 0db98e17ef86fd2ffff79df8591f45e5343e0a8b
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
Reviewed-Content-Hash: design/gdd/scare-events.md f78e8edca823a586ba20dfdbc8f253bf5adc665e
Reviewed-Content-Hash: design/gdd/survivor-defense.md c1599d79cc292de2110218f1241d95960bbbc50b
Reviewed-Content-Hash: design/gdd/survivor-objectives.md dfaa6cef738a33fd5c678b594b5abc1bfd0f3610
Reviewed-Content-Hash: design/gdd/systems-index.md 42872a34d825ce9157da21f08c5fe4e217195a20
Reviewed-Content-Hash: design/levels/research-facility.md a50a3fe81d5c8e2447aabb470a2e13e2f65586cb
```

---

## Traceability Summary

Total requirements: 138. No new TR-IDs and no GDD requirement reworded (registry version 4 to 5, no entries changed). `design/ux/*.md` and `design/accessibility-requirements.md` are not GDDs and were not extracted.

| Status | 12c | This run |
|---|---|---|
| ✅ Covered (Accepted ADR) | 0 | 0 |
| 🟡 Covered (Proposed ADR) | 114 | 122 |
| ⚠️ Partial | 19 | 11 |
| ❌ Gap | 2 | 2 |
| — No ADR needed | 3 | 3 |

Rows that moved to 🟡: TR-index-008, TR-scare-006, TR-scare-009, TR-scare-012, TR-controller-010 (ADR-0015); TR-index-012, TR-pings-004 (ADR-0014, with ADR-0011 and ADR-0013). TR-objectives-002 (ADR-0012 §6) showed ✅ in the matrix file, which is wrong with a Proposed ADR (R1 below); corrected to 🟡.

Still partial (11): TR-config-001, TR-index-010, TR-lobby-010, TR-matchflow-003, TR-objectives-004, TR-defense-006, TR-defense-011, TR-monster-007, TR-pings-005 (ADR-0014 gives the marker view but nothing covers the registry of pingable objects, the per-sender cap or the 8 s lifetime), TR-scare-004, TR-facility-001.

Full matrix: [`requirements-traceability.md`](requirements-traceability.md) (updated).

## Status of the 12c findings

| 12c | Now | Evidence |
|---|---|---|
| N4 stats keys vs state table | RESOLVED | Six `stats.*` rows in `systems-index.md`; ADR-0011 cites them (AD-44) |
| N5 ADR-0013 knobs without GDD owner | RESOLVED | Eight knob rows with Safe Ranges in `scare-events.md`; ADR-0013 requires them from `ScareKnobs`, in the digest (AD-46) |
| N6 body flashlight shadows | RESOLVED, wording nit L7 | ADR-0010 §8 and ADR-0009 agree: shadowed spots counted in `max_shadowed_spot`, `max_shadowed_flashlights` in `FacilityKnobs`, own light always shadowed (AD-43) |
| N7 footstep identity chain | RESOLVED | ADR-0013 §2 `<footstep_set>.<gait>`; guideline carve-out for masked footsteps (AD-46) |
| N8 occlusion ignores doors / physics step | RESOLVED | ADR-0013 §8 uses `SightTest.line_clear` (ADR-0012 §1), queued to `AudioDirector._physics_process`, source lifted 0.3 m (AD-45, AD-46) |
| ADR-0010 HIGH (no seek on AnimationTree; rest-pose frame) | RESOLVED | `AnimationNodeTimeSeek` per gait state, seconds of dominant clip, `advance(0.0)`; Verification 6 rewritten |
| ADR-0010 MEDIUM/LOW (overlay warp, pre-warm variants, version labels) | RESOLVED | Fragment-only warp; pre-warm covers overlay, tint, `SHADOWS_ONLY`, lit flashlight; Shader Baker evaluated |
| ADR-0011 MEDIUM/LOW (typed containers, telemetry source, vacuous check) | RESOLVED | Untyped `to_dict()` with `is_typed()` test; telemetry consumes `RoundEnded`; byte budget |
| ADR-0012 MEDIUM/LOW (5 cm rule, post-cutoff entry) | RESOLVED | Rule restated around ray ends and `hit_from_inside`; entry "none; Jolt backend" |
| ADR-0013 MEDIUM/LOW (doors, floor ray, duck leak, bus ordering, own footsteps) | RESOLVED | Counter decrements on finish, steal, stop; looping excluded; own footsteps never duck; bus ordering cited |
| `breaking-changes.md` `area_mask` attribution | RESOLVED | Says the property exists only on `AudioStreamPlayer3D` |
| TR-objectives-002 seeded selection (Required ADR 2) | RESOLVED | ADR-0012 §6 |
| Required ADR 1 (UI and input focus), 3 (scare presentation) | WRITTEN | ADR-0014, ADR-0015, reviewed below |

## Coverage Gaps (no ADR exists)

None in the critical set at `workflow: standard`.

| TR | GDD | Requirement | Suggested ADR | Domain | Engine risk |
|---|---|---|---|---|---|
| TR-pings-007, TR-pings-010 | pings-and-callouts | Proximity voice and transport | deferred (ADR-0013 reserves the `ProximityVoice` bus) | Audio | NOT SOURCEABLE |

## Cross-ADR Conflicts

Known conflict-prone areas: none recorded (`docs/consistency-failures.md` does not exist; nothing appended). No 🔴 conflicts. All findings below are open and amendment-sized.

### C1: ADR-0014 `WHEEL` context blocks the callout it exists to send (Pattern, MEDIUM)
- ADR-0014 §1 gives `WHEEL` `actions = no`, and §2 says `actions` off "blocks item, ping and callout RPCs". The callout wheel (P6) sends on release (hold mode) or confirm (toggle mode) while `WHEEL` is the top context. Read literally, no wheel selection can be sent.
- Resolution: pop `WHEEL` first and then send, or define `actions` as interact, item and ping only and exempt the wheel's own send. State which in §1/§2 and add it to Validation Criteria.

### C2: ADR-0015 server evaluates the flinch with a record the client may not have had (State, MEDIUM)
- ADR-0015 §2 has the server evaluate "the" record at the frame's `offset_tick`, clamped to the record's `start_tick`. A new flinch replaces the record, and the owner learns of it one latency later. Frames sampled in that window were rendered with the old record, but the server uses the new one. During a ramp or hold the two differ by up to the new ramp's progress over one round trip (roughly 5 degrees at 150 ms of a 10 degree flinch), against Verification 2's 0.5 degrees. Verification 1 uses one record on both sides and Verification 2 covers only re-baseline, so neither catches it.
- Resolution: carry a short record id in the input frame beside `view_epoch` (the epoch already solves this for resets), keep the last four records per player on the server, and evaluate the frame's own record. Add an in-flight replacing-flinch case to Verification 2.

### C3: Dependency edges missing (Integration, LOW)
- ADR-0015 consumes ADR-0013 (stingers through `AudioDirector`) and ADR-0014 uses ADR-0011 results data (listed under Related only). Neither is in `Depends On`, so `adr-dep-graph.sh` omits the edges. No cycle results.
- Resolution: add the edges.

### C4: ADR-0002 clamp wording vs ADR-0015 (Integration, LOW)
- ADR-0002 Validation clamps raw frame pitch to +-85 degrees; ADR-0015 §3 requires the clamp on frame pitch + base + offset. Compatible (clamp both) but ADR-0002 line 56 and Validation do not say so.
- Resolution: one sentence in ADR-0002.

## ADR Dependency Order

From `.claude/scripts/adr-dep-graph.sh`: 15 ADRs, 49 edges, no `CYCLE`, no `NO_DEPS_SECTION`.

1. Foundation: ADR-0001
2. ADR-0002 (0001)
3. ADR-0003 (0002); ADR-0004 (0001, 0002)
4. ADR-0005 (0002, 0004); ADR-0007 (0002, 0003)
5. ADR-0006 (0001, 0002, 0005); ADR-0008 (0002, 0004, 0005, 0007); ADR-0011 (0004, 0005)
6. ADR-0009 (0002, 0004 to 0008); ADR-0012 (0002, 0004 to 0007); ADR-0014 (0002, 0004, 0005, 0007, 0008)
7. ADR-0010 (0002, 0004, 0006, 0007, 0009); ADR-0013 (0004 to 0007, 0009, 0012); ADR-0015 (0002, 0004, 0005, 0009, 0014)

⚠️ Every dependency is Proposed, so nothing downstream may be implemented as Accepted. Acceptance blockers: ADR-0001/0002/0003 real-network tests; ADR-0008 item 3; ADR-0009 greybox spike; ADR-0010 Verification 1 to 8; ADR-0011 Verification 1 to 2; ADR-0012 Verification 1 to 2; ADR-0013 Verification 1 to 5; ADR-0014 Verification 1 to 6; ADR-0015 Verification 1 to 3.

## GDD Revision Flags

None. No engine finding contradicts a GDD assumption. `interaction-patterns.md` marks "the wheel captures look" as an inference to confirm in a prototype; ADR-0014's `WHEEL` context follows it, so that stays a UX-spec question. Systems index not changed by this review (the ADR authors already updated its HUD and flinch rows).

## Engine Compatibility Issues

ADRs with Engine Compatibility section: 15 / 15, all Godot 4.7.2. Deprecated API references: none (ADR-0014 uses the 4.7 `AccessibilityServer.AccessibilityLiveMode`, not `DisplayServer.AccessibilityLiveMode`). Stale version references: none; `modules/*.md` remain 4.6 snapshots. ADR-0014 and ADR-0015 engine claims are mostly NOT SOURCEABLE and carried as Verification Required items, which is the honest treatment.

### Engine Specialist Findings (`godot-specialist`, second opinion on ADR-0014 and ADR-0015)

| ADR | Severity | Finding | Fix | Source |
|---|---|---|---|---|
| 0015 §5-6 | MEDIUM | An additive-blend `ColorRect` can only brighten; the 0.4 s "non-flashing dim" (scale 0, refused flash) cannot come from it | Add a second black `ColorRect` on `SCARE_FX` with the default mix blend for the dim | `CanvasItemMaterial` semantics; NOT SOURCEABLE |
| 0014 §7 | MEDIUM | Markers hidden when `is_position_behind` get no arrow, but TR-pings-005 needs direction; `unproject_position` mirrors points behind the camera | When behind, negate the offset from screen centre and clamp to the edge inset; never hide | NOT SOURCEABLE |
| 0014 §5 | MEDIUM | `InputContextStack extends RefCounted` has no `get_viewport()` | Use `focus_owner.get_viewport()` or inject the root `Viewport` | Node API |
| 0015 §5 | MEDIUM | The ADR does not say whether `physics/common/physics_interpolation` is enabled; behaviour of an interpolation-OFF child under an interpolated `CharacterBody3D` (4.4+ interpolation rework) is unverified | State the project setting; add a camera-stutter verification at 144 Hz | `breaking-changes.md` (3D interpolation rearchitected); child behaviour NOT SOURCEABLE |
| 0014 §7, §9 | MEDIUM | At `content_scale_factor` above 1 with `canvas_items`, it is unverified that `unproject_position` is in the space marker `Control`s use | Add factors 1.0 and 1.5 to Verification 5 | NOT SOURCEABLE |
| 0014 §5 | LOW | `grab_focus()` fails on a control not visible in the tree | Push shows the layer before grabbing; `call_deferred` if instanced this frame | NOT SOURCEABLE |
| 0014 §9 | LOW | `accessibility_name` set once from `tr()` goes stale on locale change; Buttons and Labels already expose their text | Re-apply on `NOTIFICATION_TRANSLATION_CHANGED`; set names only where there is no text | NOT SOURCEABLE |
| 0014 §3 | LOW | After alt-tab the captured mouse mode is lost | Re-apply on `NOTIFICATION_APPLICATION_FOCUS_IN`; the discard-first-motion rule applies there too | NOT SOURCEABLE |

Confirmed or plausible: `Input.mouse_mode`, `CanvasLayer.visible` and focus loss on hide, `BLEND_MODE_ADD`, `Window.content_scale_factor`, the `accessibility_live` type move, polling not seeing GUI consumption (so the mask is right), 2D on the root viewport drawing after tonemapping. No anti-pattern found in the sole-writer stack or `HudModel`.

### Reviewer findings (not from the specialist)

| ID | Severity | Finding | Fix |
|---|---|---|---|
| L1 | LOW | ADR-0015 §2 `offset_tick` is the low 16 bits of a 60 Hz tick (wraps at about 18 minutes); the expansion rule (nearest to the current tick) is unstated | State it |
| L2 | LOW | `PlayerSettingsView` / `player_settings` and the `set_flinch_enabled` RPC are not in `docs/registry/architecture.yaml` | Add a registry entry |
| L3 | LOW | ADR-0014 resets the stack to `GAMEPLAY` at round start only; round end and return to lobby should reset to `MENU` so a stale `OVERLAY` cannot persist | Add the reset to §1 |
| L4 | LOW | A new flinch record reaches the owner one latency late and starts mid-ramp, a small visible pop | Accept and say so |
| L5 | LOW | ADR-0015 §2 states the owner-only projection twice | Merge |
| L6 | LOW | ADR-0010 Verification list order reads 6, 8, 7 | Reorder |
| L7 | LOW | ADR-0009 flashlight budget "`max_shadowed_spot` minus `max_shadowed_flashlights` + 1" is wrong or ambiguous: own light plus N others is N + 1 flashlights, so fixtures = `max_shadowed_spot` - (`max_shadowed_flashlights` + 1) | Rewrite |

### Document consistency fixed in this review

- R1: `requirements-traceability.md` showed TR-objectives-002 as ✅ with a Proposed ADR; now 🟡. Eight rows updated to current ADR coverage; summary 122 / 11 / 2 / 3; stale "Partial rows" note replaced.
- `architecture.md`: header ADR-0001 to ADR-0015; ADR Audit rows for ADR-0014 and ADR-0015; coverage line 122 / 11 / 2 / 3. `tr-registry.yaml` version 5 (no entry changed).

## Architecture Document Coverage

Every system in `systems-index.md` appears in `architecture.md`; no orphaned architecture. HUD, Results and Accessibility Options now have a UI ADR (ADR-0014); Match Telemetry (Alpha) has only the ADR-0011 payload source. `control-manifest.md` already lists ADR-0001 to ADR-0015.

---

## Verdict: CONCERNS

- No requirement rests on an Accepted ADR: 122 🟡 rows cap the verdict at CONCERNS. Route out: `/architecture-decision accept ADR-NNNN` once each ADR's verification items pass. No ADR status was changed by this review.
- No blocking cross-ADR conflict. C1 and C2 are MEDIUM amendments to ADR-0014 and ADR-0015, as are the engine MEDIUMs.
- All 12c findings (N4 to N8 and the engine findings) are resolved. The 12c required ADRs 1 to 3 are written.
- The two remaining gaps are deferred voice features.

### Required ADRs (most foundational first)

None required for the MVP set. Proximity voice transport stays deferred.

Amendments before acceptance: ADR-0015 (record id for in-flight flinches C2, dim layer, interpolation setting and verification, `offset_tick` expansion), ADR-0014 (wheel send order C1, behind-camera markers, stack viewport, scale verification, focus order, locale refresh, alt-tab), ADR-0002 (clamp sentence C4), `Depends On` edges (C3), ADR-0009 (budget formula L7), registry row for `PlayerSettingsView` (L2).

Recommended next: one amendment pass over ADR-0014 and ADR-0015, then `/architecture-decision accept` as each ADR's verification items run on the greybox.
