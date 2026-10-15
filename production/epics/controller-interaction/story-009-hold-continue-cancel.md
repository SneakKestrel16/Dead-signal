# Story 009: Hold continuation, cancels and movement while Holding

> **Epic**: First-Person Controller & Interaction
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

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

- [x] An accepted hold continues when the actor turns 180° and when the actor walks to `range_m` + 0.2.
- [x] It cancels on that tick, with the owner's cancel rule applied, when the actor walks beyond `range_m` + 0.25, loses line of sight, releases input, is interrupted by an owner (`holds.cancel`), or starts another hold.
- [x] While Holding, sprint input gives 4.0 m/s; with `roots_actor` it gives 0; crouch input leaves posture and capsule height unchanged.
- [x] When the hold's target changes owner state mid-hold (picked up, rescued), the owner cancels it and its cancel rule applies.

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

*From `production/qa/qa-plan-sprint-004-2026-10-14.md` (/qa-plan, 2026-10-14). Implement against these and the Acceptance Criteria above.*

**Test file path**: `tests/integration/first-person-controller/hold_service_continue_test.gd`
**What to test**:
- Continues through a 180° turn and at `range_m` + 0.2.
- Cancels that tick, with the owner's cancel rule, beyond `range_m` + 0.25, on lost line of sight, released input, owner interrupt (`holds.cancel`), or another hold started.
- While Holding: sprint input gives 4.0 m/s; `roots_actor` gives 0; crouch input leaves posture unchanged.
- Target changes owner state mid-hold: the owner cancels it and its cancel rule applies.

**Estimated test count**: ~8 integration tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/first-person-controller/hold_service_continue_test.gd` — must exist and pass

**Status**: [x] Created; passes (16 tests)

---

## Dependencies

- Depends on: Stories 003, 008
- Unlocks: Owner epics with interactions

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: 4/4 passing (automated)
**Deviations** (AD-112):
- `HoldService._continue` runs each held tick except the Start tick: eligible, then range_m + hold_range_tolerance_m (capsule centre to point), then line of sight; cancel reasons `&"ineligible"`, `&"range"`, `&"sight"`. Skipping the Start tick keeps an owner whose `on_start` changes its own eligibility from cancelling its own hold.
- A rising edge needs a release first, so any new press ends the old hold (`&"replaced"`), accepted or not; a second press with no release changes nothing (ADR-0008 §3). Reason names let the owner pick reset, keep or decay.
- An actor with no frames at all (never sent input; the queue repeats the last frame when starved) skips the step, continuation included.
- `MovementStep`: `MoveState.hold_roots` stops the actor at once; `MovementStep.wants_low(frame, state, low_now)` ignores crouch while Holding. Sprint while Holding was already walk (story 002).
- Not wired yet: nothing in production copies `HoldService.hold_of()` into `MoveState` before the movement step, so ADR-0008 §7 "from the next tick" is unenforced until the player-tick caller exists (same caller as story 004's `set_low`).
- AC4 "picked up, rescued": the owner either calls `holds.cancel(actor, reason)` or stops answering `eligible()`; both are tested. Real interrupts are wired by their owner epics.
**Test Evidence**: Integration: `tests/integration/first-person-controller/hold_service_continue_test.gd`; 10 mutations each caught. Full suite 471/471.
**Code Review**: Complete (godot-gdscript-specialist and qa-tester; S2 rule-16 question answered above; S2 wiring gap recorded; S3 Start-tick continuation fixed)
