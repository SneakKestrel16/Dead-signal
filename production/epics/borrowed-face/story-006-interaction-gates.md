# Story 006: Disguise gates on objectives, rescue and defense interactions

> **Epic**: Borrowed Face
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Objectives stay readable: a disguised shapeshifter cannot carry drives, rescue, hide or barricade. Trying is a tell for survivors to spot.

**GDD**: `design/gdd/borrowed-face.md`
**Requirement**: `TR-borrowedface-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Hold-to-interact protocol
**ADR Decision Summary**: Each owner's `eligible(actor)` rejects the shapeshifter where its GDD says so; fakeable interactables accept a fake hold instead (ADR-0008 §6).
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: As controller-interaction story 008.

**Control Manifest Rules (this layer)**:
- Required: only `HoldService` times holds

---

## Acceptance Criteria

*From `borrowed-face.md` Acceptance Criteria (drive, rescue, hiding, barricade, search), scoped to this story:*

- [ ] A pickup or install request from the shapeshifter is rejected and objective state is unchanged on all clients.
- [ ] A rescue request on a Downed survivor is rejected and the bleed-out timer is unchanged.
- [ ] Requests to enter a hiding spot, barricade or remove a barricade are rejected with spot and door state unchanged; a search of a hiding spot plays the monster search on every client.

---

## Implementation Notes

*Derived from ADR-0008 §2, §6 and `borrowed-face.md` rule 11:*

- The owner interactables come from Survivor Objectives, Downing and Survivor Defense; until those epics land, test against fixture interactables using the same `eligible` rule, and re-run with the real ones.

---

## Out of Scope

- Fake holds themselves (controller-interaction story 010)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/borrowed-face/disguise_gates_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003; controller-interaction story 010
- Unlocks: Survivor Objectives, Downing, Survivor Defense epics
