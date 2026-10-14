# Story 002: Roster lock, Match Flow hand-off and return to Waiting

> **Epic**: Lobby & Role Assignment
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] Rosters of 4, 5 and 6 players hold exactly 1 shapeshifter and 3, 4, 5 survivors; 3 or 7 players are refused.
- [ ] At countdown 0 Match Flow receives a roster with `player_count` and, per player, peer ID, display name and role; survivors have a character and the shapeshifter none; loading begins on every peer and `player_count` does not change for the round.
- [ ] The roster is published as a read-only `RosterView`; a test fails if the view exposes a setter.
- [ ] After a round ends in Results, and separately after a Cancelled round, every connected peer is back in Waiting with Ready cleared; a survivor whose grace expired mid-round is absent from the lobby.

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

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/lobby/roster_lock_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 003; event-catalog stories 003, 004
- Unlocks: Match Flow epic; Story 007
