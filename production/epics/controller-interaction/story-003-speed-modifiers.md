# Story 003: Speed modifier set: lock, root and slow

> **Epic**: First-Person Controller & Interaction
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Taser stuns, takedown commits, rescues and transforms all limit movement. Each owner adds and removes its own entry; the controller applies the most restrictive one, never a product.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Authoritative simulation, tick and input
**ADR Decision Summary**: §5–6: the server simulates movement from input frames and applies server-side state; effective speed = lock (0, no look change) > root (0) > the lowest slow multiplier, from a per-owner modifier set read by the shared movement step.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Plain GDScript; no engine API beyond Story 002's step.

**Control Manifest Rules (this layer)**:
- Required: one movement step function shared by server and owning client
- Forbidden: client-sent position, velocity, speed or progress [client_sent_position]

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (Modifiers) and Formulas (effective_speed), scoped to this story:*

- [ ] From a true-form sprint (5.75): slow 0.5 gives 2.875; slows 0.5 and 0.7 give 2.875 (not 2.01); a root gives 0; a lock and a slow give 0.
- [ ] When the last modifier is removed with sprint still held, the next tick moves at 5.75 with no re-press.
- [ ] With owners A and B each adding a modifier, removing A's leaves B's active.

---

## Implementation Notes

*Derived from ADR-0002 §5–6 and `first-person-controller.md` rule 6:*

- `SpeedModifiers.add(owner: StringName, kind, mult := 1.0)`, `remove(owner)`, `effective(base) -> float`; keyed by owner so removals never clobber.
- Lock also blocks look changes for the locked states named in the GDD; the view direction itself is Story 006.

---

## Out of Scope

- Owners that add modifiers (taser, takedown, rescue) belong to their own epics

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/first-person-controller/speed_modifiers_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002
- Unlocks: Survivor Defense, Monster Abilities and Downing epics
