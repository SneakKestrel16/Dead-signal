# Story 003: Escape, evidence extraction and outcome lock

> **Epic**: Match Flow & Win Conditions
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

A Healthy survivor entering the open exit escapes; the survivors win only when both drives are Extracted, and that win locks while the remaining survivors get a short window to leave.

**GDD**: `design/gdd/match-flow.md`
**Requirement**: `TR-matchflow-004`, `TR-matchflow-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order
**ADR Decision Summary**: Server-only typed events on the `EventBus`; owner-written state in the `StateRegistry`; Match Flow runs in the `MATCH_FLOW_BEGIN` (100) and `MATCH_FLOW_RESOLVE` (900) slots.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Plain GDScript; the exit volume comes from `MapQueries` (Facility Map).

**Control Manifest Rules (this layer)**:
- Required: implement `server_tick(tick)` and register with `TickRunner` in the `MATCH_FLOW_BEGIN` / `MATCH_FLOW_RESOLVE` slots; never rely on `_physics_process` (ADR-0002, ADR-0005)
- Forbidden: never emit an event from a client (ADR-0005); never let Match Flow tally other systems' stats or call into their modules (ADR-0011, Proposed)
- Guardrail: every tuning value comes from `MatchFlowKnobs` (`data/knobs/match_flow.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/match-flow.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] A Healthy survivor entering the exit volume after evacuation is activated is recorded Escaped and `SurvivorEscaped` is emitted; a Downed survivor in the exit volume is not (rule 10, edge case "Downed survivor crawls into the exit").
- [ ] A survivor escaping without drives is recorded Escaped and the round continues; survivors win only when Survivor Objectives reports both drives Extracted — one drive out is not a win (rule 11).
- [ ] After both drives are Extracted at 8:00, eliminating every survivor still inside does not change the outcome, and the round ends no later than 8:45 (`post_escape_window_s`), the deadline, or when every survivor is Escaped or Eliminated, whichever comes first; those still inside are "Did not escape" (rules 14, 15, Formulas "Post-escape end time").

---

## Implementation Notes

- Escape detection reads positions and life state from the registry and the exit volume from `MapQueries`; it runs in the begin slot so `SurvivorEscaped` is processed before the resolve check in the same tick.
- "Evacuation activated" and "drive Extracted" arrive as `ObjectiveProgressChanged`; Survivor Objectives owns what Extracted means (`survivor-objectives.md` rule 22).
- The lock is a field set once; every later check returns early on it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Survivor Objectives epic: carried drives becoming Extracted
- Story 007: escaped players becoming spectators

---

## QA Test Cases

*From `/qa-plan sprint` (production/qa/qa-plan-sprint-005-2026-10-14.md). Implement against these cases.*

- **AC-1**: Healthy escape only
  - Given: evacuation activated
  - When: a Healthy and a Downed survivor enter the exit
  - Then: Healthy one Escaped and `SurvivorEscaped`; Downed one not
  - Edge cases: exit entered before activation
- **AC-2**: Win needs both drives
  - Given: one drive Extracted
  - When: a survivor escapes empty-handed
  - Then: Escaped, round continues; win only when the second is Extracted
  - Edge cases: both drives on one carrier
- **AC-3**: Outcome lock and window
  - Given: both drives Extracted at 480 s
  - When: every survivor inside is then eliminated
  - Then: outcome stays survivor win; round ends by 525 s; remaining are "Did not escape"
  - Edge cases: lock at 530 s → ends at 540 (deadline)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match-flow/escape-and-outcome-lock_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002
- Unlocks: Story 008
