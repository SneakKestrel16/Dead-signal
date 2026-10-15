# Story 007: Presentation-only guarantees: slammed doors and no fake teammates

> **Epic**: Scare Events
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

A RoundScript slammed door plays a slam and a shudder at its anchor, but the door's real state never changes. No scare may produce footsteps, a teammate voice, a ping or a callout.

**GDD**: `design/gdd/scare-events.md` rules 4, 7, 21
**Requirement**: `TR-scare-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order; secondary: ADR-0007
**ADR Decision Summary**: Scares are events with no state writes; door state belongs to Survivor Defense.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Forbidden: Scare never writes another module's state

---

## Acceptance Criteria

*From GDD `design/gdd/scare-events.md`, scoped to this story:*

- [ ] A RoundScript slammed door leaves its door's server open or closed state unchanged; a lunge, an observation line of sight and a ping through an open anchor door behave the same before and after the slam.
- [ ] RoundScript never produces footsteps, a teammate voice, a ping or a callout.

---

## Implementation Notes

- Assert on the door state view and on the event stream over a full scripted round.

---

## Out of Scope

- Story 008: the slam sound itself.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scare-events/presentation_only_scares_test.gd` (real ENet where the AC names clients)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006
- Unlocks: None
