# Story 010: Transformation warp and distortion audio

> **Epic**: Borrowed Face
> **Status**: In Review
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]


## Context

A transformation is noisy and visible: nearby survivors hear a distortion from its direction and anyone looking sees the warp. This is the counterplay window.

**GDD**: `design/gdd/borrowed-face.md`
**Requirement**: `TR-borrowedface-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Borrowed Face rendering (primary, Proposed); ADR-0013: Spatial audio pipeline (Proposed); ADR-0004: Replication scope and information hiding
**ADR Decision Summary**: The distortion is a positional sound event with no body reference, sent within its radius; the warp is a client effect during Transforming.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: 4.7 changed the `AudioStreamPlayer3D.area_mask` default to 0 (ADR-0013).

**Control Manifest Rules (this layer)**:
- Required: (Proposed) rules per ADR-0010 and ADR-0013 — re-check the control manifest once they are Accepted

---

## Acceptance Criteria

*From `borrowed-face.md` Acceptance Criteria (distortion), scoped to this story:*

- [ ] A survivor client within 15 m hears the distortion with its panned bearing within ±15° of the true bearing (proposed tolerance); one at 20 m does not.
- [ ] The warp plays on every client in view for the whole Transforming state (retained capture).

---

## Implementation Notes

*Derived from ADR-0010 and ADR-0013 (Proposed):*

- The positional sound path exists from network-authority story 009.

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
- Visual/Feel: retained screenshot or capture in `production/qa/evidence/` + sign-off in `production/qa/evidence/transform-warp-audio-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 003, 009; ADR-0010 and ADR-0013 Accepted
- Unlocks: none
