# Story 001: Round clock and phase state machine

> **Epic**: Match Flow & Win Conditions
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

The server-only round clock and the phase machine (Infiltration, Investigation, Evacuation) with the early switch to Evacuation when the terminal is armed. This is the core every other Match Flow story builds on. The terminal-armed input comes from Survivor Objectives, which has no code yet: tests feed `ObjectiveProgressChanged` directly.

**GDD**: `design/gdd/match-flow.md`
**Requirement**: `TR-matchflow-001`, `TR-matchflow-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order; secondary: ADR-0002, ADR-0006
**ADR Decision Summary**: Server-only typed events on the `EventBus`; owner-written state in the `StateRegistry`; Match Flow runs in the `MATCH_FLOW_BEGIN` (100) and `MATCH_FLOW_RESOLVE` (900) slots.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Plain GDScript on the server tick; no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: implement `server_tick(tick)` and register with `TickRunner` in the `MATCH_FLOW_BEGIN` / `MATCH_FLOW_RESOLVE` slots; never rely on `_physics_process` (ADR-0002, ADR-0005)
- Forbidden: never emit an event from a client (ADR-0005); never let Match Flow tally other systems' stats or call into their modules (ADR-0011, Proposed)
- Guardrail: every tuning value comes from `MatchFlowKnobs` (`data/knobs/match_flow.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/match-flow.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] With default knobs and nothing done, the phase is Infiltration at 0:00, Investigation at 2:00 and Evacuation at 7:00, and `elapsed_s` reaches the deadline at 9:00 (rule 5, Formulas "Phase from elapsed time").
- [ ] Arming the terminal at 5:00 switches to Evacuation at 5:00 and the deadline stays 9:00; arming it at 1:00 moves Infiltration straight to Evacuation with exactly one `RoundPhaseChanged` (rule 6, States and Transitions).
- [ ] Every phase change sends exactly one `RoundPhaseChanged`; the phase never moves backwards.
- [ ] All Tuning Knobs are read from `MatchFlowKnobs`; a config with `infiltration_end_s >= round_duration_s - evacuation_window_s` fails load-time validation (`MatchFlowKnobs.validate_cross`) and the game refuses to host.

---

## Implementation Notes

- New module `src/feature/match_flow/match_flow.gd` (Feature layer; the code root has no `feature/` yet — create it, matching `src/core/` and `src/foundation/`) with `setup(tick_runner, bus, registry, knobs)` and `server_tick(tick)`, registered at `TickOrder.MATCH_FLOW_BEGIN`. The clock advances by one tick of `net.sim_tick_hz` per `server_tick`; derive time from the tick count, never wall time.
- Phase is a pure function of `elapsed_s` and `terminal_armed` (Formulas); keep it a static helper so the unit test covers it without a round.
- Publish phase and `time_remaining_s` in the `StateRegistry` for readers; emit `RoundPhaseChanged` (`ev_round_phase_changed.gd`) on change.
- Add the cross-knob rule to `MatchFlowKnobs.validate_cross()` (currently returns []).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: win evaluation and the deadline outcome
- Story 004: Loading and spawning before Infiltration

---

## QA Test Cases

*From `/qa-plan sprint` (production/qa/qa-plan-sprint-005-2026-10-14.md). Implement against these cases.*

- **AC-1**: Phases at 0:00, 2:00, 7:00; deadline at 9:00
  - Given: default knobs, terminal not armed
  - When: the clock steps tick by tick to 540 s
  - Then: phase is Infiltration < 120 s, Investigation 120–420 s, Evacuation >= 420 s; `time_remaining_s` reaches 0 at 540
  - Edge cases: elapsed exactly 120.0 and 420.0 (boundary ticks)
- **AC-2**: Terminal armed switches to Evacuation early; deadline unchanged
  - Given: elapsed 300 s, then separately elapsed 60 s
  - When: `terminal_armed` becomes true
  - Then: phase is Evacuation at that tick, deadline stays 540; from 60 s exactly one `RoundPhaseChanged` (Infiltration → Evacuation)
  - Edge cases: armed on the same tick Investigation would begin
- **AC-3**: One event per phase change, never backwards
  - Given: a full round with arming at 300 s
  - When: all `RoundPhaseChanged` are captured
  - Then: 3 events in order, none repeated, phase never decreases
  - Edge cases: disarming input after arming changes nothing
- **AC-4**: Knobs from data; bad cross-knob config refuses
  - Given: `infiltration_end_s` 180, `round_duration_s` 420, `evacuation_window_s` 240
  - When: `MatchFlowKnobs.validate_cross()` runs
  - Then: one error naming the constraint
  - Edge cases: equality (`infiltration_end_s == evac_start_s`) also fails

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match-flow/round-clock-phases_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (RoundServer, TickOrder and the event catalog exist)
- Unlocks: Stories 002–009
