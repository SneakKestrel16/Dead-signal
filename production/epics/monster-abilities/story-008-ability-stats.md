# Story 008: Ability stats for results

> **Epic**: Monster Abilities
> **Status**: Blocked — BLOCKED: ADR-0011 is Proposed — accept it with `/architecture-decision accept ADR-0011` once decided
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: —

## Context

The results screen shows ability counts. This module counts lunges (hit, miss, interrupted) and exposes a getter-only view under `stats.abilities`; Match Flow reads it once on the outcome tick.

**GDD**: `design/gdd/monster-abilities.md`
**Requirement**: `TR-monster-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Round stats and results payload (Proposed)
**ADR Decision Summary**: One owner per results field; getter-only `*StatsView` under `stats.<system>`; Match Flow resolves them into `RoundResults` on `RoundEnded`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Plain GDScript.

**Control Manifest Rules (this layer)**:
- Required: run in the MonsterAbilities slot via `server_tick(tick)` registered with `TickRunner` (ADR-0002, ADR-0005); every number from `AbilityKnobs` (ADR-0006)
- Forbidden: never emit an event from a client (ADR-0005); no literal for a tuning knob in ability code
- Guardrail: the dodge-window values are coupled; rerun the steering check after changing wind-up, turn rates, dash, radius or cone

---

## Acceptance Criteria

*From GDD `design/gdd/monster-abilities.md`, scoped to this story:*

- [ ] Lunge hit, miss and interrupted counts are exposed through a getter-only view and appear in the `RoundEnded` results payload
- [ ] Counters reset at round start

---

## Implementation Notes

- Follow the existing `stats.*` views in Downing and Objectives. Never tally from Match Flow.

---

## Out of Scope

- Results screen UI

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/monster-abilities/ability_stats_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004; ADR-0011 accepted
- Unlocks: None
