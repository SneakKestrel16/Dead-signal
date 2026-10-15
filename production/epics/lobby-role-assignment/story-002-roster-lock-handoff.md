# Story 002: Roster lock, Match Flow hand-off and return to Waiting

> **Epic**: Lobby & Role Assignment
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

## Context

At lock the server builds a roster of 4–6 players with exactly one shapeshifter, publishes it read-only, and hands it to Match Flow. After Results or a Cancelled round everyone returns to Waiting with Ready cleared. Phase M1.

**GDD**: `design/gdd/lobby-role-assignment.md`
**Requirement**: `TR-lobby-008`, `TR-lobby-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order (primary); ADR-0002: Authoritative simulation, tick and input
**ADR Decision Summary**: Owners register typed read-only state views once; views have no setters; the composition root wires modules with `setup()` and no gameplay autoloads.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: 4.7: overrides inherit the parent's typed return; restate it.

**Control Manifest Rules (this layer)**:
- Required: read-only views registered once per owner (event-catalog story 003)
- Forbidden: gameplay autoloads

---

## Acceptance Criteria

*From `lobby-role-assignment.md` AC-LB-01, AC-LB-24, AC-LB-27, scoped to this story:*

- [x] Rosters of 4, 5 and 6 players hold exactly 1 shapeshifter and 3, 4, 5 survivors; 3 or 7 players are refused.
- [x] At countdown 0 Match Flow receives a roster with `player_count` and, per player, peer ID, display name and role; survivors have a character and the shapeshifter none; loading begins on every peer and `player_count` does not change for the round.
- [x] The roster is published as a read-only `RosterView`; a test fails if the view exposes a setter.
- [x] After a round ends in Results, and separately after a Cancelled round, every connected peer is back in Waiting with Ready cleared; a survivor whose grace expired mid-round is absent from the lobby.

---

## Implementation Notes

*Derived from ADR-0005 §3 (state registry) and `lobby-role-assignment.md` rules 11–14:*

- M1 picks the shapeshifter uniformly at random (seeded RNG); the rotation queue replaces it in Story 007.
- Session id and round index travel with the roster.

---

## Out of Scope

- Story 007: rotation queue
- Match Flow loading and Results (Match Flow epic)

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-004-2026-10-14.md` (/qa-plan, 2026-10-14). Implement against these and the Acceptance Criteria above.*

**Test file path**: `tests/integration/lobby/roster_lock_test.gd`
**What to test**:
- 4, 5, 6 players: exactly 1 shapeshifter and 3, 4, 5 survivors; 3 or 7 refused.
- At countdown 0 Match Flow receives `player_count` and per player peer ID, display name, role; survivors have a character (LB-3 deal), the shapeshifter none; loading starts on every peer; `player_count` fixed for the round.
- `RosterView` is read-only; a test fails if it exposes a setter.
- After Results and after Cancelled, every connected peer is back in Waiting with Ready cleared; a survivor whose grace expired is absent.

**Edge cases to cover**:
- A disconnect during the countdown (LB-1 rules).

**Estimated test count**: ~7 integration tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/lobby/roster_lock_test.gd` — must exist and pass

**Status**: [x] Created; passes (15 tests, plus 2 in `tests/integration/network/host_join_auth_test.gd`)

---

## Dependencies

- Depends on: Stories 001, 003; event-catalog stories 003, 004
- Unlocks: Match Flow epic; Story 007

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: 4/4 passing (automated)
**Deviations** (AD-108):
- The roster carries player IDs, not peer IDs: the control manifest keeps peer IDs inside NetAuthority. AC2's "peer ID" is read as the player ID.
- AC2's "loading begins on every peer" is Match Flow's: this story hands Match Flow the roster (`RosterHandoff.handed_off`). Sending the roster to clients and Loading are out of scope (Match Flow epic).
- The view is registered by `RosterHandoff.publish(registry)`, which the composition root calls after `RoundServer.start_round`, because each round builds a fresh registry after countdown 0.
**Test Evidence**: Integration: `tests/integration/lobby/roster_lock_test.gd`; 16 mutations each caught. Full suite 425/425.
**Code Review**: Complete (godot-gdscript-specialist and qa-tester; every finding verified and fixed)
