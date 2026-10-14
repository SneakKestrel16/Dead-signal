# Story 005: Action restrictions while Disguised or Transforming

> **Epic**: Borrowed Face
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

A disguise is a costume, not a power: the shapeshifter must change to true form to attack, cannot change mid-attack, and is slowed to walking while transforming.

**GDD**: `design/gdd/borrowed-face.md`
**Requirement**: `TR-borrowedface-007`, `TR-borrowedface-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Hold-to-interact protocol (primary); ADR-0005: Event catalog, state registry and tick order
**ADR Decision Summary**: Disguise permissions are `eligible(actor)` gate checks in each owner's `Interactable` and request handlers, reading Borrowed Face's form view; the movement step reads Transforming to cap the gait at walk.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: As controller-interaction story 008.

**Control Manifest Rules (this layer)**:
- Required: resolve body targets through the requesting peer's handle table
- Forbidden: client hold completion [client_hold_complete]

---

## Acceptance Criteria

*From `borrowed-face.md` Acceptance Criteria (Lunge, Transforming), scoped to this story:*

- [ ] A Lunge requested while Disguised is rejected; a transformation requested during a Lunge takedown commit is rejected.
- [ ] While Transforming, the shapeshifter can walk, but sprint, interact and ability requests are rejected.
- [ ] Every client receives the transforming state within 250 ms of acceptance (simulated 150 ms RTT).

---

## Implementation Notes

*Derived from ADR-0008 §2, §7 and `borrowed-face.md` rules 8, 11:*

- Lunge is Monster Abilities; use a stub request handler that reads the form view.

---

## Out of Scope

- Story 006: objective and defense interaction gates

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/borrowed-face/disguise_restrictions_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003; controller-interaction stories 002, 008
- Unlocks: Monster Abilities epic
