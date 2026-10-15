# Story 001: Defense module, charges and intent validation

> **Epic**: Survivor Defense
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

The module's first slice: a new `SurvivorDefense` that owns per-survivor taser charges, the reuse delay and the item-use gate, and rejects forged client claims. Later stories hang the trace, the lock, hiding and barricades off it.

**GDD**: `design/gdd/survivor-defense.md`
**Requirement**: `TR-defense-001, TR-defense-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Authoritative simulation, tick rate and input; secondary: ADR-0005, ADR-0006
**ADR Decision Summary**: The server owns every charge, timer and occupancy; clients send intents in input frames and the server validates them in its own tick slot.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Builds on `TickOrder.SURVIVOR_DEFENSE` (200) and `DefenseKnobs`; no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: run in `TickOrder.SURVIVOR_DEFENSE` via `server_tick(tick)`; clients send intent only; the server owns charges and timers (ADR-0002, ADR-0005)
- Forbidden: never accept a client-reported stun, charge or completion; never emit an event from a client
- Guardrail: Every value is read from `DefenseKnobs` (`data/knobs/defense.tres`), none hardcoded.

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md` (Detailed Design and Acceptance Criteria), scoped to this story:*

- [ ] Each survivor starts with exactly `stun_item_charges` (2) cartridges; a third fire attempt does nothing and spends nothing (rules 7, 29).
- [ ] A second fire inside `stun_item_reuse_s` is ignored; charges persist through a down and rescue and are lost on elimination (rules 8, 13).
- [ ] A Downed, Seized or hidden survivor cannot fire; the monster has no items (rule 13).
- [ ] A forged client message claiming a stun hit, a charge change or a completed barricade causes no state change (rule 1).

---

## Implementation Notes

- New module `src/feature/defense/survivor_defense.gd` with `setup(tick_runner, bus, registry, knobs)` / `server_tick(tick)`, registered at `TickOrder.SURVIVOR_DEFENSE`.
- Item eligibility reads `Downing.eligible(player)` and the hidden set published here; charges publish read-only under `StateKeys.HIDDEN_ITEM_USE`.
- Players are ids, never node references.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the trace and what a shot hits
- Story 003: the shock lock a hit applies
- Story 006: the hidden set

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Logic: `tests/unit/survivor-defense/defense_charges_test.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (builds on merged Downing, Event Catalog and Data Config)
- Unlocks: Stories 002, 003, 006, 007, 009
