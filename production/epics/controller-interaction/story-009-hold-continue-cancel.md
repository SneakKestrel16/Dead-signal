# Story 009: Hold continuation, cancels and movement while Holding

> **Epic**: First-Person Controller & Interaction
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Once accepted, a hold survives looking away and small steps, but cancels on range, line of sight, release, interrupts or a new action. While Holding the actor cannot sprint, and some holds root them.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Hold-to-interact protocol
**ADR Decision Summary**: §4 checks while Holding: range ≤ `range_m` + `hold_range_tolerance_m` (capsule centre to point), LOS, `eligible`; §5 owners cancel through `holds.cancel(actor, reason)` (hits, shocks, item use, hiding); §7 the movement step reads hold state: sprint off, speed 0 if `roots_actor`, crouch ignored, from the next tick.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: As Story 008.

**Control Manifest Rules (this layer)**:
- Required: read the hold target only on the rising edge of `interact`; continuation range is `range_m + hold_range_tolerance_m`
- Forbidden: accepting a client completion or progress message [client_hold_complete]

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (Hold-to-interact: accepted hold) and rules 14, 16, scoped to this story:*

- [ ] An accepted hold continues when the actor turns 180° and when the actor walks to `range_m` + 0.2.
- [ ] It cancels on that tick, with the owner's cancel rule applied, when the actor walks beyond `range_m` + 0.25, loses line of sight, releases input, is interrupted by an owner (`holds.cancel`), or starts another hold.
- [ ] While Holding, sprint input gives 4.0 m/s; with `roots_actor` it gives 0; crouch input leaves posture and capsule height unchanged.
- [ ] When the hold's target changes owner state mid-hold (picked up, rescued), the owner cancels it and its cancel rule applies.

---

## Implementation Notes

*Derived from ADR-0008 Decision §4, §5, §7:*

- Story 002's gait order already maps Holding to walk; add the root and crouch-ignore here.
- Cancel reasons are an enum passed to `on_cancel`; owners map them to reset, keep or decay.

---

## Out of Scope

- Real interrupts (`SurvivorHit`, `PlayerShocked`) are wired by their owner epics; this story tests through `holds.cancel`

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/first-person-controller/hold_service_continue_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 003, 008
- Unlocks: Owner epics with interactions
