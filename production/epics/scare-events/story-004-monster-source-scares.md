# Story 004: Monster-source scares: door burst, reveal and Blackout

> **Epic**: Scare Events
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Player-triggered scares are a presentation layer over the gameplay cue that its own system owns. The Scare module listens to `BarricadeBroken`, the reveal (`FormChanged` to true form) and Blackout, and fires the matching Monster-source scare. False Signal never produces a scare.

**GDD**: `design/gdd/scare-events.md` rules 2, 4, 5
**Requirement**: `TR-scare-001`, `TR-scare-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order; secondary: ADR-0009
**ADR Decision Summary**: Scare consumes catalog events in tick order; it requests no lighting state.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: read events in tick order; Scare runs after Pings
- Forbidden: Scare never writes lighting state (ADR-0009 §7)

---

## Acceptance Criteria

*From GDD `design/gdd/scare-events.md`, scoped to this story:*

- [ ] A barricade break, a reveal and a Blackout each fire their Monster-source scare to the relevant clients.
- [ ] Across 20 False Signals of every type, no `ScareTriggered` is emitted; a survivor client's capture of a fake callout or sound matches the real one except the absent gesture event.
- [ ] No scare changes health, down state, objective progress, cooldowns or position on the server.

---

## Implementation Notes

- The fake-vs-real capture half depends on Pings & Callouts story 007; if it is not merged, test the no-`ScareTriggered` half and note the other as pending.

---

## Out of Scope

- Story 005: the ambush lunge scare.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scare-events/monster_source_scares_test.gd` (real ENet where the AC names clients)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: None
