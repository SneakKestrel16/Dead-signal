# Story 004: TickRunner and the server clock

> **Epic**: Network Authority & Replication
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-13

Unblocked 2026-10-13: ADR-0001..0008 Accepted. 

## Context

One server clock in ticks drives every rule. A single TickRunner runs the six phases each physics tick so the order is fixed and testable.

**GDD**: none (systems-index server-authority rule)
**Requirement**: `TR-index-001`, `TR-index-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Authoritative Simulation, Tick and Input
**ADR Decision Summary**: `server_tick` advances once per `_physics_process`; `Engine.physics_ticks_per_second` is set once at boot from `sim_tick_hz` (60); TickRunner phases: dequeue input, movement, snapshot history, feature `server_tick` in ADR-0005 order, flush events, per-peer snapshots.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification results (2): `Engine.max_physics_steps_per_frame` default 8; on a slow host everyone slows together because timers count ticks.

**Control Manifest Rules (this layer)**:
- Required: rules run only from TickRunner phases; timers count ticks
- Forbidden: rules in a module's own `_physics_process` [rules_in_own_physics_process]; wall-clock timers [wall_clock_rule_timer]
- Guardrail: server tick max 2.0 ms

---

## Acceptance Criteria

*From ADR-0002 §1–2, scoped to this story:*

- [x] `current_tick()` increases by exactly 1 per physics step; server time is `server_tick / sim_tick_hz`.
- [x] Registered stub features run in `phase_order` inside phase 4, after movement and history and before flush and snapshots.
- [x] `physics_ticks_per_second` is set once at boot from `NetKnobs.sim_tick_hz` and a test fails if any script changes it later.

---

## Implementation Notes

*Derived from ADR-0002 Decision and Implementation Guidelines:*

- API: `signal tick_started(tick)`, `current_tick() -> int`, `register_feature(module, phase_order)`.
- Movement, history and snapshot phases call into stories 005–007; stub them until those land.

---

## Out of Scope

- Story 005: input queue
- event-catalog story 004: the feature order itself

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-001-2026-10-12.md` (/qa-plan, 2026-10-12). Implement against these and the Acceptance Criteria above.*

**What to test**:
- `current_tick()` +1 per physics step; server time = tick / `sim_tick_hz`.
- Phase 4 stubs run after movement and history, before flush and snapshots.
- `physics_ticks_per_second` set once from knobs.

**Edge cases to cover**:
- Two features with the same `phase_order` → assert at registration.

**Estimated test count**: ~4 unit tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/network/tick_runner_test.gd` — must exist and pass

**Status**: [x] `tests/unit/network/tick_runner_test.gd` — 12 tests; suite 69/69 pass (2026-10-13)

---

## Dependencies

- Depends on: data-config Story 001
- Unlocks: Stories 005, 006, 007; event-catalog Story 004

---

## Completion Notes
**Completed**: 2026-10-13
**Criteria**: 3/3 passing, each covered by a gdUnit4 test (12 tests, 0 failures, 0 orphans)
**Deviations** (advisory):
- Phases 1–3 and 6 are `Callable` hooks (`input_stage`, `movement_stage`, `history_stage`, `snapshot_stage`), default no-op, for stories 005–007 to set. Phase 5 is skipped when `bus` is null (tests only).
- `step()` runs one tick and is what `_physics_process` calls, so tests drive ticks without the engine loop.
- Boot-once is per runner instance. "Set once" is enforced across the code by a source-scan test: no script under `src/` but `tick_runner.gd` assigns `physics_ticks_per_second` (minimum-file guard; scanner proved on a fixture).
- Duplicate `phase_order` and a second `boot()` are recorded violations, with `assert` only when `fail_hard` (same pattern as `EventBus`).
- `server_time()` before `boot()` divides by zero (returns inf); `boot()` is the composition root's first call.
- The 2.0 ms server-tick guardrail is not measured here (no real phase work yet).
**Test Evidence**: Logic: `tests/unit/network/tick_runner_test.gd`; mutation-checked (phase 2 replaced by a second phase 3; features sorted descending: each failed the ordering test).
**Code Review**: Skipped (lean mode). The runner was read in full by the orchestrator; no specialist or QA review ran.
