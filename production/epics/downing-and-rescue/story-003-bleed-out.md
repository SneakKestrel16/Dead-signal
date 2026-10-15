# Story 003: Bleed-out timer and anti-camping slow

> **Epic**: Downing, Rescue & Elimination
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

A Downed survivor bleeds out unless rescued; the timer pauses during a rescue and slows while any other non-Downed player is near, so nobody can stall the round.

**GDD**: `design/gdd/downing-and-rescue.md`
**Requirement**: `TR-downing-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order
**ADR Decision Summary**: Server-only typed events on the `EventBus`; owner-written state in the `StateRegistry`; Downing runs in the `DOWNING` (500) slot after Monster Abilities and before Holds.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Straight-line distance from registry positions; no physics queries.

**Control Manifest Rules (this layer)**:
- Required: run in the `DOWNING` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel` (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never emit an event from a client; never let `HoldService` emit events (ADR-0005, ADR-0008)
- Guardrail: every timer, range and multiplier comes from `DowningKnobs` (`data/knobs/downing.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/downing-and-rescue.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] A Downed survivor left alone is Eliminated after `bleedout_s` (60 s ±1 tick) with reason "Bled out"; holding a rescue pauses the timer and releasing resumes it from the same value (rule 6, Formulas "Bleed-out").
- [ ] With at least one survivor Healthy and any other non-Downed player (survivor or shapeshifter, any form) 9 m away, the timer advances at 0.25 s per second; at 11 m at 1 s per second from the same value; Eliminated, Escaped and disconnected players never slow it.
- [ ] With every living survivor Downed and the shapeshifter 5 m from one of them, that survivor's timer keeps advancing at full rate and each is Eliminated on their own timer (rule 10).
- [ ] Every value this story uses is read from `DowningKnobs`, not hardcoded.

---

## Implementation Notes

- `slowed = nearest_player_distance_m <= camp_slow_radius_m and healthy_survivors >= 1` (Formulas); keep the per-tick step a static helper.
- The two playtest ACs in the GDD (rescue timing and camping radius) are not this story's: they are recorded for the designer before Milestone 2.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: the rescue hold that pauses it
- Match Flow story 002: ending the round on the last elimination
- GDD playtest ACs (camp_slow_mult, camp_slow_radius_m): designer review before Milestone 2

---

## QA Test Cases

*From `/qa-plan sprint` (production/qa/qa-plan-sprint-005-2026-10-14.md). Implement against these cases.*

- **AC-1**: Bleed-out and rescue pause
  - Given: a Downed survivor alone
  - When: 60 s pass; separately a rescue is held 3 s
  - Then: Eliminated "Bled out" at 60 s ±1 tick; timer paused during the hold, resumes from the same value
  - Edge cases: rescue completes on the expiry tick → rescue wins
- **AC-2**: Camping slow
  - Given: one survivor Healthy, another player at 9 m then 11 m
  - When: 10 s pass at each
  - Then: +2.5 s at 9 m, +10 s at 11 m; Eliminated/Escaped/disconnected players never slow
  - Edge cases: exactly 10.0 m
- **AC-3**: All Downed
  - Given: every living survivor Downed, shapeshifter at 5 m
  - When: time passes
  - Then: full-rate bleed-out, each Eliminated on its own timer
  - Edge cases: one survivor Escaped

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/downing-and-rescue/bleed-out_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 006
