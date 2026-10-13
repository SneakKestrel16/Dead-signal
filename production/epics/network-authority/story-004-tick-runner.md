# Story 004: TickRunner and the server clock

> **Epic**: Network Authority & Replication
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-12
> **Last Updated**: [set by /dev-story when implementation begins]

BLOCKED: ADR-0002 is Proposed — accept with `/architecture-decision accept` once the two-PC real-network test passes.

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

- [ ] `current_tick()` increases by exactly 1 per physics step; server time is `server_tick / sim_tick_hz`.
- [ ] Registered stub features run in `phase_order` inside phase 4, after movement and history and before flush and snapshots.
- [ ] `physics_ticks_per_second` is set once at boot from `NetKnobs.sim_tick_hz` and a test fails if any script changes it later.

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

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/network/tick_runner_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: data-config Story 001
- Unlocks: Stories 005, 006, 007; event-catalog Story 004
