# Story 005: AbilityUsed emission and Lunge state publishing

> **Epic**: Monster Abilities
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: —

## Context

Every accepted ability emits exactly one `AbilityUsed`; it never reaches a survivor client because it carries the disguised monster's position. Lunge state is published to the `StateRegistry` for Borrowed Face and Survivor Defense to read.

**GDD**: `design/gdd/monster-abilities.md`
**Requirement**: `TR-monster-006`, `TR-monster-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding; secondary: ADR-0005
**ADR Decision Summary**: `AbilityUsed` is server-internal with an empty `project()`; consumers replicate only their own effect. Lunge state is registry state owned by Monster Abilities.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Plain GDScript; reuses the existing `EvAbilityUsed`.

**Control Manifest Rules (this layer)**:
- Required: run in the MonsterAbilities slot via `server_tick(tick)` registered with `TickRunner` (ADR-0002, ADR-0005); every number from `AbilityKnobs` (ADR-0006)
- Forbidden: never emit an event from a client (ADR-0005); no literal for a tuning knob in ability code
- Guardrail: the dodge-window values are coupled; rerun the steering check after changing wind-up, turn rates, dash, radius or cone

---

## Acceptance Criteria

*From GDD `design/gdd/monster-abilities.md`, scoped to this story:*

- [ ] Every accepted Lunge emits exactly one `AbilityUsed` (ability, position, target) at wind-up start; a rejected request emits none
- [ ] A capture of what every survivor peer receives contains no `AbilityUsed` and no monster position derived from it
- [ ] Lunge wind-up, Active and commit are readable from the registry so transformation is blocked during them (Borrowed Face rule 7) and Survivor Defense can end stun immunity

---

## Implementation Notes

- `EvAbilityUsed.project()` already returns `{}`; the test asserts it through the real replication path, not only the method.
- Registry key and owner follow ADR-0005; Borrowed Face `set_attack_source` reads this state in story 006.

---

## Out of Scope

- Wiring Borrowed Face to the new source: story 006

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/monster-abilities/ability_used_hiding_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 006
