# Story 006: Integrate with Downing and Borrowed Face

> **Epic**: Monster Abilities
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: —

## Context

Replace the stand-ins. Downing tests drive `SurvivorHit` directly, and Borrowed Face 005 (`tests/integration/borrowed-face/disguise_restrictions_test.gd`) uses `StubAbilities`. With the real module, re-check that both still hold and add the end-to-end Lunge to takedown path.

**GDD**: `design/gdd/monster-abilities.md`
**Requirement**: `TR-monster-002`, `TR-monster-003`, `TR-monster-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order; secondary: ADR-0003
**ADR Decision Summary**: Tick order Defense > BorrowedFace > MonsterAbilities > Downing; events are the only coupling between modules.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Plain GDScript; no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: run in the MonsterAbilities slot via `server_tick(tick)` registered with `TickRunner` (ADR-0002, ADR-0005); every number from `AbilityKnobs` (ADR-0006)
- Forbidden: never emit an event from a client (ADR-0005); no literal for a tuning knob in ability code
- Guardrail: the dodge-window values are coupled; rerun the steering check after changing wind-up, turn rates, dash, radius or cone

---

## Acceptance Criteria

*From GDD `design/gdd/monster-abilities.md`, scoped to this story:*

- [ ] Borrowed Face `set_attack_source` is fed from `MonsterAbilities` state; the Borrowed Face 005 disguise-restriction tests pass with the real module in place of `StubAbilities` (re-checked; stub removed or reduced to a thin adapter)
- [ ] The existing Downing tests that emit `SurvivorHit` directly still pass; one new test drives a real Lunge into a Downing takedown commit through to `SurvivorDowned`
- [ ] Multi-client: across 20 lunges with 5 clients (one at 150 ms simulated latency), all clients agree on every hit/miss and the survivor's resulting state; every dispute is logged

---

## Implementation Notes

- Do not delete the Downing direct-drive tests; they stay as unit coverage of its consumer.
- Re-run `tests/integration/downing-and-rescue/` and `tests/integration/borrowed-face/` in full.

---

## Out of Scope

- New ability behaviour (stories 001-005)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/monster-abilities/lunge_end_to_end_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 003, 004, 005
- Unlocks: Story 007
