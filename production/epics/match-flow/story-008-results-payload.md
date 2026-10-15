# Story 008: Results payload

> **Epic**: Match Flow & Win Conditions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15


## Context

The results screen's data: outcome, reason, each survivor's status, objective progress and match stats, read once from each owner's stats view when the outcome is final.

**GDD**: `design/gdd/match-flow.md`
**Requirement**: `TR-matchflow-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Round stats and results payload (Proposed); secondary: ADR-0005
**ADR Decision Summary**: Each owner exposes a getter-only `*StatsView`; `MatchFlow.resolve` reads them once on the outcome tick into a typed `RoundResults` on `RoundEnded`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: `var_to_bytes` size check on the payload (ADR-0011 verification 1).

**Control Manifest Rules (this layer)**:
- Required: implement `server_tick(tick)` and register with `TickRunner` in the `MATCH_FLOW_BEGIN` / `MATCH_FLOW_RESOLVE` slots; never rely on `_physics_process` (ADR-0002, ADR-0005)
- Forbidden: never emit an event from a client (ADR-0005); never let Match Flow tally other systems' stats or call into their modules (ADR-0011, Proposed)
- Guardrail: every tuning value comes from `MatchFlowKnobs` (`data/knobs/match_flow.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/match-flow.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [x] `RoundEnded` carries outcome, reason (rule 23), every survivor's status with downs taken and rescues performed (rule 24), objective progress x/2 drives recovered, docked and extracted, x/2 fuses, activation, and completion times (rule 25), and the stats in rule 26.
- [x] All clients receive the same payload; it is read once from each owner's `*StatsView` on the outcome tick and Match Flow tallies nothing itself.
- [x] `var_to_bytes` of the largest payload (6 players, every counter, longest names) is under 4 KB, and `to_dict()` holds no typed containers (ADR-0011 verification).

---

## Implementation Notes

- Follow ADR-0011 once it is Accepted: `RoundResults` typed class, `to_dict()` with fresh untyped containers.
- Owners without code yet have no view: read a missing view as zeroes and say so in the payload, never invent values.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- HUD epic: presenting the results

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match-flow/results_payload_test.gd` — must exist and pass

**Status**: [x] `tests/unit/match-flow/results_payload_test.gd`

---

## Dependencies

- Depends on: Stories 002, 003
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-204):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 1076/1076 after the wave merge, no leak warnings.
- View getters named get_* (getter-only test rule), not the ADR's bare names.
- outcome and reason are ints (MatchFlow.Outcome/Reason, matching EvRoundEnded), not the ADR's StringNames. Payload adds shapeshifter_name, fate cause and missing.
- Base stats views created in the other owners' folders so Match Flow can read them; getter sets are a reading of the ADR-0011 owner table (each owner's stats story settles them).
- Round start tick = elapsed 0 (matches elapsed_s); MatchDisplay starts its clock at the Infiltration RoundPhaseChanged tick, which may differ (inference).
- 4 KB check asserts < 4096 bytes for 6 players, 16-char 3-byte names, all counters at int32 max.
- Test file is results_payload_test.gd (snake_case), not the story's hyphenated name.
- Untested: a nonzero start tick in duration math; reads on a tick other than the outcome tick.
**Test Evidence**: Red run 2 errors + 1 failure. Mutations caught: registered views ignored, typed array in to_dict, start tick shifted by one.
**Code Review**: Complete (orchestrator review at merge)
