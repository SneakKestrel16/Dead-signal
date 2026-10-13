# Story 006: Snapshots, owner prediction and reconciliation

> **Epic**: Network Authority & Replication
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-12
> **Last Updated**: [set by /dev-story when implementation begins]

BLOCKED: ADR-0002 is Proposed — accept with `/architecture-decision accept` once the two-PC real-network test passes.

## Context

The server sends each peer one snapshot per tick. The owner predicts its own movement with the shared movement step and reconciles against the acknowledged state, so movement responds in one frame and corrections stay invisible.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-index-001`, `TR-index-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Authoritative Simulation, Tick and Input; secondary ADR-0007
**ADR Decision Summary**: Unreliable per-peer snapshot stamped with `server_tick`; own entry carries last consumed `seq`, position, velocity, on-floor flag and effective modifier; the client restores, `apply_floor_snap()`s, replays unacked frames, corrects beyond 0.005 m, smooths under 1.0 m on a non-interpolated child, snaps above with `reset_physics_interpolation()`; client tick estimate from snapshots; inside-geometry restore to last valid position.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification results (3) PASS: OFF-interpolation child shows the offset at once; (4) PASS at 5 mm deadzone on a 40° ramp; (6) 6-body snapshot 144 B, one datagram; (7) PASS: `apply_floor_snap()` cuts replay error from 17 mm to 1.6 mm. Cross-machine Jolt drift (5) NOT RUN.

**Control Manifest Rules (this layer)**:
- Required: one shared movement step; every snap calls `reset_physics_interpolation()`; restore the floor with `apply_floor_snap()`
- Forbidden: client-only movement code; state-changing facts in snapshots
- Guardrail: about 87 kbps host upload per client at 60 Hz

---

## Acceptance Criteria

*From ADR-0002 §5–9 and Validation Criteria, scoped to this story:*

- [ ] With 5 clients at simulated 150 ms RTT, 30 ms jitter and 2% loss, owner corrections are at or below 53 per 5022 states and snaps are under 0.35 m p95.
- [ ] A replay over step and ramp geometry shows no snap on a clean link.
- [ ] The host and a remote client complete the same scripted route with identical server-side positions.
- [ ] A player pushed inside geometry is restored to the last valid position and the owner receives it through the snap path.

---

## Implementation Notes

*Derived from ADR-0002 Decision and Implementation Guidelines:*

- Correction values (`correction_deadzone_m`, `correction_smooth_max_m`, `correction_smooth_s`) from `NetKnobs`.
- Prediction collides with static geometry and replicated doors (`MOVE_PREDICT`, ADR-0007).
- Camera yaw and pitch render from local input at frame rate; the camera node is non-interpolated.
- Real-network rows of this story run in the two-PC test.

---

## Out of Scope

- Story 008: which bodies a snapshot carries
- Controller epic: the movement step itself

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/network/prediction_reconcile_test.gd` — must exist and pass; two-PC results documented in `production/qa/evidence/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 004, 005
- Unlocks: Stories 007, 008
