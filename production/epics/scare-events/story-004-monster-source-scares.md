# Story 004: Monster-source scares: door burst, reveal and Blackout

> **Epic**: Scare Events
> **Status**: Complete
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

- [x] A barricade break, a reveal and a Blackout each fire their Monster-source scare to the relevant clients.
- [x] Across 20 False Signals of every type, no `ScareTriggered` is emitted; a survivor client's capture of a fake callout or sound matches the real one except the absent gesture event.
- [x] No scare changes health, down state, objective progress, cooldowns or position on the server.

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

**Status**: [x] `tests/integration/scare-events/monster_source_scares_test.gd` (3 cases, one over real ENet); packet half of AC-2 pending PC-7

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: None

## Progress Notes (2026-10-15)

Merged from wt-se4. Full suite 1362/1362, no leak lines. Mutations caught: acting monster not excluded, any form change firing the reveal, False Signal firing the blackout scare, range check disabled.

Notes:
- `MonsterScares` (`TickOrder.SCARE_EVENTS - 2`): `BarricadeBroken` fires `door_burst` at the door, `FormChanged` into true form from a disguise fires `transformation_reveal` at the monster, a Blackout `AbilityUsed` fires `blackout` at its target. False Signal fires nothing (20 of each type over real ENet: 60 `AbilityUsed`, 0 `ScareTriggered`).
- AC-3: every catalogue entry fired at every live player leaves positions, life state, downs, match status, objective state and every ability ready tick unchanged.

**In Review:** the packet half of AC-2 (a survivor's capture of a fake callout matches a real one except the gesture) is the parity test of Pings & Callouts story 007, not yet built. AC-2 is ticked for its no-`ScareTriggered` half only; close this story when PC-7 merges.

Deviations (inference):
- The acting monster is excluded from its own scare (a Major would otherwise flinch it toward its own door or blackout). A designer ruling settles it.
- Recipients by distance only (`recipients(scare_id, origin)`); swap for `ScareRelevance` (story 003) once merged. The reveal range in the catalogue (10 m) equals `reveal_radius_m`.
- Tests emit trigger events on the bus rather than driving full holds; AC-3 reads private fuse arrays (no public fuse count).

Closed 2026-10-15: the packet half of AC-2 is proven by `tests/integration/pings-and-callouts/identity_fake_parity_test.gd` (pings-and-callouts story 007): a fake callout's captured entry equals the real one with `gesture` false.
