# Story 010: Rejection echo for over-cap pings and the sight test blind spot

> **Epic**: Pings & Callouts
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Two defects found while building stories 004 and 008. First, `PingsCallouts.request_ping` drops requests beyond `ping_bucket_size` in one tick with no rejection echo, so the sender's pending marker never clears (only a modified client sends that fast). Second, the ping sight check calls `SightTest` with a 360-degree cone at yaw 0, and a point exactly behind (+Z) computes an angle a hair over pi and is refused; story 004 and scare-events story 005 worked around it locally (range plus ray, or fov INF).

**GDD**: `design/gdd/pings-and-callouts.md` rules 2, 6
**Requirement**: `TR-pings-001`, `TR-pings-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Authoritative simulation, tick rate and input; secondary: ADR-0012 (SightTest)
**ADR Decision Summary**: The server validates every request and answers each one; sight uses the shared `SightTest`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: every request gets a server answer (accepted copy or rejection) to its sender only
- Forbidden: unbounded per-tick memory for a flooding client

---

## Acceptance Criteria

*From GDD `design/gdd/pings-and-callouts.md`, scoped to this story:*

- [x] A request over the per-tick cap is answered with `PING_REJECTED` to its sender's peer only; per-tick memory stays bounded (no growth with the number of requests beyond a fixed cap).
- [x] A ping at a point exactly behind the sender (+Z at yaw 0), in range and with a clear line, is accepted.
- [x] `SightTest` with a 360-degree cone never refuses on angle (fix in `SightTest` itself, so the local workarounds can be removed or left harmless).

---

## Implementation Notes

- Fix at the root: a 360-degree cone should skip the angle check in `SightTest`; check every caller (ambush, observation, discovery, pings) still passes.
- For the echo, count over-cap requests per player per tick and emit at most one extra rejection per over-cap request up to a fixed bound.

---

## Out of Scope

- Client marker presentation (story 008).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/pings-and-callouts/ping_reject_echo_sight_fix_test.gd` must exist and pass

**Status**: [x] tests/unit/pings-and-callouts/ping_reject_echo_sight_fix_test.gd (6 cases); full suite 1399/1399

---

## Dependencies

- Depends on: Stories 001, 004
- Unlocks: None

## Progress Notes (2026-10-15)

Merged c51c8e9. SightTest skips the angle test when fov_deg >= 360; PingsCallouts queue holds up to 2 * ping_bucket_size requests per tick, over-cap requests answered PING_REJECTED to sender only without validation or token spend; monster_sees workaround removed. 6 cases in ping_reject_echo_sight_fix_test.gd; mutations caught (not-full guard, cap = bucket size, cap 1000x). Full suite 1399/1399, no leak lines. ambush_test.gd fov INF workaround left harmless (its comment reason is now outdated).
