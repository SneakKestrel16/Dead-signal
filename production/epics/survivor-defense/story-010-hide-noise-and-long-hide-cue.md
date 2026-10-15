# Story 010: Hiding noise and the long-hide cue

> **Epic**: Survivor Defense
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15


## Context

Entering or leaving makes a soft sound audible within `hide_noise_radius_m`; after `hide_quiet_s` of continuous hiding the spot emits a faint cue every `hide_cue_interval_s`. The cue is Vertical Slice priority in the GDD.

**GDD**: `design/gdd/survivor-defense.md`
**Requirement**: `TR-defense-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013: Spatial audio pipeline (Proposed)
**ADR Decision Summary**: Gameplay-relevant noise is emitted as a positional sound with a radius; the pipeline decides attenuation and delivery.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Needs ADR-0013 accepted; emission API not yet fixed.

**Control Manifest Rules (this layer)**:
- Required: positional sound emission through the pipeline's single entry (ADR-0013, Proposed)
- Forbidden: never send the cue to clients outside its audible radius
- Guardrail: Every value is read from `DefenseKnobs` (`data/knobs/defense.tres`), none hardcoded.

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md` (Detailed Design and Acceptance Criteria), scoped to this story:*

- [x] Enter and exit each make a sound heard within 8 m (rule 19).
- [x] A survivor hidden for 20 s triggers the cue, then again every 5 s; it stops on exit (rule 21).

---

## Implementation Notes

- Blocked until ADR-0013 is accepted. Timers are server-side and testable without audio.
- Only emission is built here; the actual sounds are in story 011.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: the sounds themselves

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration: `tests/integration/survivor-defense/hide_noise_cue_test.gd`

**Status**: [x] `tests/integration/survivor-defense/hide_noise_cue_test.gd` (5 tests)

---

## Dependencies

- Depends on: Story 006; ADR-0013 accepted
- Unlocks: Story 011

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-213):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 1151/1151 after the wave merge, no leak warnings.
- The cue uses the 8 m hide-noise radius: rule 21 calls it faint but names no radius (a cue-radius knob would settle it).
- The occupant hears all three sounds (source -1). The entry sound plays on completion only; a cancelled entry is silent (reading of rule 19).
- Sound-set names hide_enter, hide_exit, hide_cue are new; story 011's audio catalog must match.
**Test Evidence**: 5 tests. Mutations caught: cue one interval late, quiet timer not cleared on leave, no exit sound.
**Code Review**: Complete (orchestrator review at merge)
