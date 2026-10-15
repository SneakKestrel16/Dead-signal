# Story 005: Downed crawl and action restrictions

> **Epic**: Downing, Rescue & Elimination
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Downed survivors crawl slowly and can do little else; Seized victims and the Committing monster are rooted.

**GDD**: `design/gdd/downing-and-rescue.md`
**Requirement**: `TR-downing-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Movement, physics and collision layers; secondary: ADR-0005
**ADR Decision Summary**: Speed changes go through the movement modifier stack (lock > root > slow); no direct velocity writes.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Uses `MovementModifiers.add(owner, kind, mult)` (CI-3).

**Control Manifest Rules (this layer)**:
- Required: run in the `DOWNING` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel` (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never emit an event from a client; never let `HoldService` emit events (ADR-0005, ADR-0008)
- Guardrail: every timer, range and multiplier comes from `DowningKnobs` (`data/knobs/downing.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/downing-and-rescue.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] A Downed survivor moves at `crawl_speed_mult` × walk speed (1 m/s at defaults) and cannot sprint, interact with objectives, barricade, hide or use items (rule 6, Formulas "Crawl speed").
- [ ] During a commit the victim and the monster are rooted; the monster cannot use abilities, transform or interact (rule 4.2).
- [ ] Rescuer and Downed survivor are rooted while a rescue is held; all modifiers are removed when the state ends.
- [ ] Every value this story uses is read from `DowningKnobs`, not hardcoded.

---

## Implementation Notes

- Add modifiers through the controller's `MovementModifiers` under owner `&"downing"`; publish the restriction flags in the registry for Defense, Objectives and Borrowed Face to gate on (they check, Downing never calls them).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Pings & Callouts epic: Call for Help

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/downing-and-rescue/downed-movement-restrictions_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: None
