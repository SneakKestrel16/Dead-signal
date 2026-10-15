# Story 004: Monster stun, immunity and cancels

> **Epic**: Survivor Defense
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

The monster's Normal, Stunned, Immune machine. A valid hit stuns for `stun_duration_s` and emits `MonsterStunned`; the immunity runs `stun_immunity_s` after and ends early on a lunge wind-up or a completed change into a disguise. A stun cancels a lunge, a takedown commit, a transformation, a search and a break. This replaces the Borrowed Face `StubDefense`.

**GDD**: `design/gdd/survivor-defense.md`
**Requirement**: `TR-defense-004, TR-defense-005, TR-defense-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order; secondary: ADR-0007
**ADR Decision Summary**: `MonsterStunned` is emitted by its owner; a stun beats same-tick completions through the tick order, and consumers react to the event.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Uses `EvMonsterStunned`; Downing and Borrowed Face already subscribe (`_on_monster_stunned`). The stand-ins are in three Borrowed Face tests.

**Control Manifest Rules (this layer)**:
- Required: events emitted by the owner in its tick slot; a stun processed before same-tick completions (ADR-0005)
- Forbidden: never emit `MonsterStunned` from a client path; never extend immunity on a second hit
- Guardrail: Every value is read from `DefenseKnobs` (`data/knobs/defense.tres`), none hardcoded.

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md` (Detailed Design and Acceptance Criteria), scoped to this story:*

- [ ] A taser first-hit on the true-form monster within 5 m applies a 2.0 s stun and emits `MonsterStunned`; out of range, missed or blocked by a survivor it does not (acceptance 1).
- [ ] A stun during lunge wind-up produces no `SurvivorHit`; during a takedown commit it frees the victim; during a transformation it cancels it; a stun beats a completion on the same tick (rule 15).
- [ ] A second true-form hit inside `stun_immunity_s` is resisted and applies nothing; two survivors firing on the same tick stun once and spend two charges (rule 10, edge case).
- [ ] A stun at 0 s, lunge wind-up at 2 s into immunity ends immunity, and a stun on that wind-up applies; a completed change into a disguise also ends immunity (rule 16).
- [ ] A search or break in progress is interrupted and barricade damage already dealt is kept (rule 15).

---

## Implementation Notes

- The module reads the lunge and wind-up from Monster Abilities through a narrow callable (that module is built in parallel, use a fixture until it lands).
- A disguised hit goes through story 003's lock instead of this machine; this machine runs only in true form.
- Stun timers keep running while the monster is disconnected.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: the lock a disguised monster gets
- Story 005: events seen by clients
- Story 012: re-running stand-in tests

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Logic: `tests/unit/survivor-defense/monster_stun_test.gd`. Re-run: `tests/unit/borrowed-face/transform_state_machine_test.gd`, `tests/unit/borrowed-face/transform_immunity_test.gd`, and the Downing commit-cancel tests under `tests/unit/downing-and-rescue/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 002, 003
- Unlocks: Stories 005, 008, 012
