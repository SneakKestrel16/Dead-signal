# Story 010: Lighting replication, Blackout scope and reduced flash

> **Epic**: Facility Map
> **Status**: In Review
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]


## Context

All clients must agree on the lighting, a Blackout must darken exactly one volume while emergency strips stay visible, and flashing lights need reduced-flash variants.

**GDD**: `design/levels/research-facility.md`
**Requirement**: `TR-facility-004`, `TR-facility-010`, `TR-facility-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009: Lighting states and Blackout (Proposed)
**ADR Decision Summary**: Clients render the replicated per-volume state; §6 reduced-flash variants; Verification covers rack lanes and glass overdraw.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: 4.6 glow rework and D3D12 default on Windows; check both renderers.

**Control Manifest Rules (this layer)**:
- Required: (Proposed) rules per ADR-0009 — re-check the control manifest once it is Accepted

---

## Acceptance Criteria

*From `research-facility.md` Acceptance Criteria 8, 9, 12 and Technical Notes, scoped to this story:*

- [ ] On the Evacuation phase change and on power restored, all 5 clients enter the new state within 1 s of each other (proposed tolerance; recorded on all clients).
- [ ] A Blackout darkens exactly one lighting volume and emergency strips stay visible in it, in every room and corridor segment (retained screenshots).
- [ ] With reduced flash on, beacons and pulses use their reduced-flash variants (retained capture); the B1 rack lanes and glass partitions hold the frame budget (measured number recorded).

---

## Implementation Notes

*Derived from ADR-0009 (Proposed):*

- Slice note: the true-form view was very dark; check readability under Low Power.

---

## Out of Scope

- Art pass

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: retained screenshot or capture in `production/qa/evidence/` + sign-off in `production/qa/evidence/lighting-render-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 002, 009; ADR-0009 Accepted
- Unlocks: none
