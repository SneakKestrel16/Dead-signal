# Story 010: Blackout (Vertical Slice)

> **Epic**: Monster Abilities
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 2 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: —

## Context

Vertical Slice. Blackout darkens one blackout-able lighting zone for 6 s on every client; a backup switch restores its own zone. Lighting state belongs to the Facility Map; this module validates the target through `LightingView` before emitting `AbilityUsed`.

**GDD**: `design/gdd/monster-abilities.md`
**Requirement**: `TR-monster-009`, `TR-monster-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009: Lighting states and Blackout (Proposed); secondary: ADR-0008
**ADR Decision Summary**: Server-owned lighting state with a `blackout_able` flag per volume, replicated so all clients see the same zone dark; Monster Abilities validates through `LightingView`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Light nodes and environment; verify against the engine reference.

**Control Manifest Rules (this layer)**:
- Required: run in the MonsterAbilities slot via `server_tick(tick)` registered with `TickRunner` (ADR-0002, ADR-0005); every number from `AbilityKnobs` (ADR-0006)
- Forbidden: never emit an event from a client (ADR-0005); no literal for a tuning knob in ability code
- Guardrail: the dodge-window values are coupled; rerun the steering check after changing wind-up, turn rates, dash, radius or cone

---

## Acceptance Criteria

*From GDD `design/gdd/monster-abilities.md`, scoped to this story:*

- [ ] Blackout is rejected on a zone whose `blackout_able` is false, that is already dark, or beyond 15 m or without line of sight; cooldown 45 s from activation
- [ ] Blackout darkens the same zone on all 5 clients for 6 s (plus or minus 1 tick) with emergency lights visible; flashlights stay lit
- [ ] A backup switch held for 1 s restores its own zone only; releasing earlier does not
- [ ] Using Blackout while Disguised is accepted and leaves the disguise intact

---

## Implementation Notes

- Switch hold uses the existing `HoldService` pattern (ADR-0008); the shapeshifter cannot fake it.
- Facility Map owns reset on `RoundEnded` and the Evacuation exclusion.

---

## Out of Scope

- Lighting rendering (Facility Map)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/monster-abilities/blackout_test.gd` OR documented playtest

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 005; ADR-0009 accepted
- Unlocks: None
