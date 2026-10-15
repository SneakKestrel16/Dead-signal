# Story 012: Display state catch-up on rejoin

> **Epic**: Match Flow & Win Conditions
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]


## Context

The `batch_extras` display entries are sent only when something changes. These are Downing's bleed ring and the Survivor Defense CHARGES, HIDING and BARRICADE entries. A client that rejoins mid-round, or whose connection is down on the tick of a change, misses that change until the next one. ServerMovement's catch-up replays only catalog events. This gap was found in SD-12 and listed as condition 4 in the sprint 6 QA sign-off.

**GDD**: `design/gdd/match-flow.md` (reconnect), `design/gdd/survivor-defense.md`, `design/gdd/downing-and-rescue.md`
**Requirement**: `TR-matchflow-007` (reconnect state)

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding (re-send on re-entry); secondary: ADR-0005
**ADR Decision Summary**: A rejoining peer receives the current projected state it is allowed to see, never another role's hidden state.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [ ] On rejoin, ServerMovement sends each `batch_extras` provider's full current state for that viewer: the ring, charges, hiding and barricades. Afterwards the client's displays match a client that never left.
- [ ] The replay keeps each provider's visibility rule (AD-194): a rejoining monster gets no charges or hiding entries.
- [ ] Test: a real-ENet client drops, misses a barricade break and a charge spend, then rejoins and shows both correctly. The test is bounded, with no widened timing.

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/match-flow/display_catch_up_test.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: survivor-defense story 012 and downing-and-rescue story 007 (both Complete)
