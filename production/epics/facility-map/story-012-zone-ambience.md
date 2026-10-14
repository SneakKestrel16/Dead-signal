# Story 012: Zone ambience and B3 footstep masking

> **Epic**: Facility Map
> **Status**: Blocked
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

BLOCKED: ADR-0013 is Proposed — accept it with `/architecture-decision accept ADR-0013` once decided.

## Context

Each zone has its own ambience, and B3's machinery masks footsteps, giving the shapeshifter a place to move quietly.

**GDD**: `design/levels/research-facility.md`
**Requirement**: `TR-facility-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013: Spatial audio pipeline (Proposed)
**ADR Decision Summary**: Zone ambience by volume; B3 footstep masking reduces the footstep send radius there.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: 4.7 `AudioStreamPlayer3D.area_mask` default is 0 (unused per ADR-0013).

**Control Manifest Rules (this layer)**:
- Required: (Proposed) rules per ADR-0013 — re-check the control manifest once it is Accepted

---

## Acceptance Criteria

*From `research-facility.md` Audio Direction, scoped to this story:*

- [ ] Each zone plays its ambience when the listener is in it, crossfading at volume borders (retained recording).
- [ ] Footsteps in B3 use the masked radius from data, and a listener just outside it does not hear a walk that would be audible elsewhere.

---

## Implementation Notes

*Derived from ADR-0013 (Proposed) and `research-facility.md` Audio Direction:*

- Footstep events come from controller-interaction story 014.

---

## Out of Scope

- Audio mix

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: retained screenshot or capture in `production/qa/evidence/` + sign-off in `production/qa/evidence/zone-ambience-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005; controller-interaction story 014; ADR-0013 Accepted
- Unlocks: none
