# Story 002: Win evaluation order and immediate endings

> **Epic**: Match Flow & Win Conditions
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

The win check in its fixed priority order, run on relevant events and once at the end of every tick in the `MATCH_FLOW_RESOLVE` slot. Downing and Survivor Objectives have no code yet; tests emit `SurvivorEliminated` and `ObjectiveProgressChanged` directly.

**GDD**: `design/gdd/match-flow.md`
**Requirement**: `TR-matchflow-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order
**ADR Decision Summary**: Server-only typed events on the `EventBus`; owner-written state in the `StateRegistry`; Match Flow runs in the `MATCH_FLOW_BEGIN` (100) and `MATCH_FLOW_RESOLVE` (900) slots.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Plain GDScript; no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: implement `server_tick(tick)` and register with `TickRunner` in the `MATCH_FLOW_BEGIN` / `MATCH_FLOW_RESOLVE` slots; never rely on `_physics_process` (ADR-0002, ADR-0005)
- Forbidden: never emit an event from a client (ADR-0005); never let Match Flow tally other systems' stats or call into their modules (ADR-0011, Proposed)
- Guardrail: every tuning value comes from `MatchFlowKnobs` (`data/knobs/match_flow.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/match-flow.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] When all survivors are eliminated (including by bleed-out), the round ends at that moment with "All survivors eliminated"; with only Downed survivors inside and the drives not out, it does not end until the last bleeds out (rules 12, 13, 18).
- [ ] If nobody is left inside (all Escaped or Eliminated) and a drive was not Extracted, the round ends at once with "Evidence lost"; a survivor in reconnect grace counts as inside (rule 13).
- [ ] With nothing done, the deadline at 9:00 ends the round "Shapeshifter Wins — Evacuation deadline expired"; a 15 s activation started at 8:50 does not finish and the monster wins at 9:00 (rules 8, 9).
- [ ] Within one tick the order is evidence escaped, all eliminated, evidence lost, deadline, forfeit: the second drive Extracted in the same tick as the last elimination, or as the deadline, is a survivor win (rule 16).

---

## Implementation Notes

- `MatchFlow.resolve` at `TickOrder.MATCH_FLOW_RESOLVE` runs the checks in rule 16's order and stops at the first that fires; the event handlers only mark the check dirty — one evaluation per tick keeps the order deterministic.
- Track per-survivor status (inside Healthy/Downed, Escaped, Eliminated, in grace) from events only; never read Downing's internals (ADR-0011 forbids calling into other modules).
- On an outcome, emit `RoundEnded` with outcome and reason; the results payload is story 008.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: escapes, the outcome lock and the post-escape window
- Story 006: the forfeit check's inputs
- Story 008: the results payload

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match-flow/win-evaluation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Stories 003, 004, 006, 008
