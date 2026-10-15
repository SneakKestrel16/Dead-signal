# Story 008: Results payload

> **Epic**: Match Flow & Win Conditions
> **Status**: Blocked
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

> **BLOCKED**: ADR-0011 is Proposed — accept it with `/architecture-decision accept ADR-0011` once decided.

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

- [ ] `RoundEnded` carries outcome, reason (rule 23), every survivor's status with downs taken and rescues performed (rule 24), objective progress x/2 drives recovered, docked and extracted, x/2 fuses, activation, and completion times (rule 25), and the stats in rule 26.
- [ ] All clients receive the same payload; it is read once from each owner's `*StatsView` on the outcome tick and Match Flow tallies nothing itself.
- [ ] `var_to_bytes` of the largest payload (6 players, every counter, longest names) is under 4 KB, and `to_dict()` holds no typed containers (ADR-0011 verification).

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
- Logic: `tests/unit/match-flow/results-payload_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 002, 003
- Unlocks: None
