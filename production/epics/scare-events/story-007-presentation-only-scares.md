# Story 007: Presentation-only guarantees: slammed doors and no fake teammates

> **Epic**: Scare Events
> **Status**: Complete
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

- [x] A RoundScript slammed door leaves its door's server open or closed state unchanged; a lunge, an observation line of sight and a ping through an open anchor door behave the same before and after the slam.
- [x] RoundScript never produces footsteps, a teammate voice, a ping or a callout.

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

**Status**: [x] Created and passing (2 tests; door probes use the composer's own sight Callables and MonsterAbilities.hit_test; anchors injected in memory as in story 006)

---

## Dependencies

- Depends on: Story 006
- Unlocks: None

## Progress Notes (2026-10-15)

Merged from wt-se7. Full suite 1370/1370, no leak lines. No violation found; no `src/` change. Mutations caught (temporary, in the composer): a `ScareTriggered` handler toggling a door, one emitting a footstep, composer sight ignoring doors.

Notes:
- AC-1 (headless composed round, anchors injected in memory as in story 006): after `slammed_door` at sd1 the A2-A3 door stays open (registry view and `Doors.closed_states()`); observation sight, ping sight and the lunge hit test through it answer the same before and after; closing the door for real flips all three.
- AC-2 (5 real ENet clients, Low to Emergency, survivor and monster walked through every anchor volume): no batch carries a positional sound, ping or rejected ping; every `ScareTriggered` is RoundScript `slammed_door` or `glass_break`; every door ends as it started.

Deviations (inference):
- The lunge check calls `MonsterAbilities.hit_test` with the composer's sight Callable rather than a full dash; the headless composer wires no door blockers.
- Phases advance by emitting `RoundPhaseChanged`, not the real clock.
- The anchor door (sd1 = A2-A3) is from the level doc; anchor positions copy story 006's inferred ones. Delete the injection helper once the map carries the anchors.
- AC-2's final door comparison misses an even number of toggles; AC-1 catches the toggle.
