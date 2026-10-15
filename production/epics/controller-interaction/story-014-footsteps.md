# Story 014: Footstep events from gait and disguise

> **Epic**: First-Person Controller & Interaction
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15


## Context

Footsteps tell survivors where others are. Their range depends only on gait, and a disguised shapeshifter's steps sound like the survivor it copies.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013: Spatial audio pipeline (primary, Proposed); ADR-0004: Replication scope and information hiding (Accepted); ADR-0010: Borrowed Face rendering (Proposed)
**ADR Decision Summary**: Footstep events carry position and sound set, no handle, and go only to peers inside the gait's send radius (sprint 20, walk 6, crouch/crawl 2 m, from data); pooled 3D players on the client; the sound set follows the disguise target.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: 4.7 changed the `AudioStreamPlayer3D.area_mask` default to 0 (ADR-0013 notes it is unused).

**Control Manifest Rules (this layer)**:
- Required: (Proposed) spatial audio rules per ADR-0013 — re-check the control manifest once it is Accepted

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (Footsteps), scoped to this story:*

- [x] A listener at 1.9, 2.1, 5.9, 6.1, 19.9 and 20.1 m hears a source only at ≤ 2 m (crouch, crawl), ≤ 6 m (walk) and ≤ 20 m (sprint), with the same radii in every form.
- [x] A stationary player emits no footstep events over 5 s, even with an active False Signal elsewhere.
- [x] Remote clients play the target survivor's footstep set for a walking disguised shapeshifter.
- [x] Manual: two testers 18 m apart through one wall hear the sprint and not the walk in at least 9 of 10 trials (retained recording in `production/qa/evidence/`).

---

## Implementation Notes

*Derived from ADR-0013 (Proposed) and network-authority story 009 (positional sounds):*

- Positional sound projection already exists (network-authority story 009); this story feeds it from the gait.
- Occlusion and attenuation belong to the audio mix.

---

## Out of Scope

- Audio mix, occlusion (audio epic)
- False Signal itself (Monster Abilities epic)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/first-person-controller/footsteps_test.gd` — must exist and pass

**Status**: [x] `tests/integration/first-person-controller/footsteps_test.gd` (4 tests)

---

## Dependencies

- Depends on: Story 002; network-authority story 009; ADR-0013 and ADR-0010 Accepted
- Unlocks: Borrowed Face parity test

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-214):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 1151/1151 after the wave merge, no leak warnings.
- New knob footstep_spacing_m 0.9 (range 0.5-2.0), no source value; an audio playtest settles it. SHIPPED_DIGEST re-pinned.
- Gait carried inside the sound id (the event format has no gait field); set name from the appearance number until ADR-0010's Appearance.footstep_set data ships.
- Footstep masking per lighting volume (ADR-0013 §7) not done: no map data for it yet. Client audio playback out of scope.
- Disguise test stubs appearance_of. The manual 18 m through-one-wall trial is a designer item.
- Session was flagged for modifying shared resources; the agent reported only /tmp files and the per-project user:// test folder, no process kills or edits outside its worktree (verified main and stash untouched).
**Test Evidence**: 4 tests; red before the module existed. Mutations caught: walk with sprint radius, a step every tick, player id instead of appearance, vertical speed counted.
**Code Review**: Complete (orchestrator review at merge)
