# Story 010: Hiding noise and the long-hide cue

> **Epic**: Survivor Defense
> **Status**: Blocked
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

> **BLOCKED**: ADR-0013 is Proposed — accept with `/architecture-decision accept ADR-NNNN` once decided

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

- [ ] Enter and exit each make a sound heard within 8 m (rule 19).
- [ ] A survivor hidden for 20 s triggers the cue, then again every 5 s; it stops on exit (rule 21).

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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006; ADR-0013 accepted
- Unlocks: Story 011
