# Story 007: Rewind history and lag compensation

> **Epic**: Network Authority & Replication
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

Unblocked 2026-10-13: ADR-0001..0008 Accepted. 

## Context

A hit lands on what the attacker saw. The server keeps 16 ticks of target history and rewinds targets by the attacker's reported view lag, clamped by what the server itself measures.

**GDD**: `design/gdd/monster-abilities.md`, `design/gdd/survivor-defense.md`
**Requirement**: `TR-index-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Lag Compensation and Rewind
**ADR Decision Summary**: Remote players render 50 ms behind; `rewind = clamp(T - view_tick, 0, min(cap_ticks, rtt_bound))` with a 180 ms cap; history of position, capsule and chest per tick, interpolated between brackets; only target positions are rewound; analytic capsule and door tests with `SIGHT` / `PROJECTILE` rays; clamps are logged as disputes.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification results (1): `hit_from_inside` false, `hit_back_faces` true, `collide_with_areas` false. (4) dodge holds at 0.43 s with a 27 ms margin at `accel_time_s` 0.05.

**Control Manifest Rules (this layer)**:
- Required: every hit test goes through `LagCompensation`; reject non-finite or future `view_tick`
- Forbidden: moving bodies or `intersect_shape` for player hit tests; rewound eligibility [rewound_eligibility]; client-claimed latency [client_claimed_latency]
- Guardrail: 6 players × 16 ticks × about 40 bytes

---

## Acceptance Criteria

*From ADR-0003 and Validation Criteria, scoped to this story:*

- [x] At simulated 50, 100 and 150 ms RTT the full-rewind error is 0.00 m up to the cap; the capped error at 150 ms is reported.
- [x] A frame with a non-finite or future `view_tick` gives rewind 0 and a log entry.
- [x] `sample()` outside history returns `ok = false`, current positions are used, and the case is logged.
- [x] Eligibility read in a hit test is the current tick's, not the rewound tick's (a target hidden after the rewound time is not hit).

---

## Implementation Notes

*Derived from ADR-0003 Decision and Implementation Guidelines:*

- `RewindHistory.push(...)`, `sample(player_id, tick) -> {ok, pos, height, radius, chest}`; `LagCompensation.rewind_ticks`, `capsule_hits_segment`, `ray_first_hit` as pure functions.
- Rewind values from `NetKnobs`; capsule half-length is `height / 2 - radius`.
- Lunge and taser use these helpers in their Feature epics.

---

## Out of Scope

- Monster Abilities and Survivor Defense epics: lunge and taser rules

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/network/lag_compensation_test.gd` — must exist and pass

**Status**: [x] `tests/unit/network/rewind_lag_compensation_test.gd` (12 tests)

---

## Dependencies

- Depends on: Story 006
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: all passing (automated)
**Deviations** (AD-150):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 806/806 after the wave merge, no leak warnings.
- `RewindHistory`, `LagCompensation`; ServerMovement owns the history; `position_at` reads it.
- `slack_ticks` value 1 (range 0-10) and chest height (feet + height - radius) are inference; real-network clamp counts and a controller knob settle them. SHIPPED_DIGEST re-pinned.
- Capped rewind error at 150 ms RTT: 0.055 m; under 0.005 m at 50 and 100 ms.
- No client fills `view_tick` / `ack_snapshot_tick` yet: until one does, every hit test clamps to the cap and logs. Composition root must construct LagCompensation.
- Test file written first but first run after implementation; mutations stand in for the red run.
**Test Evidence**: 12 tests. Mutations caught: RTT bound dropped, interpolation removed, future view_tick accepted, full-height capsule axis.
**Code Review**: Complete (orchestrator review at merge)
