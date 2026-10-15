# Story 013: Hiding marker facing and eject in front

> **Epic**: Survivor Defense
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15


## Context

SD-6 ejects a found survivor onto the hiding marker's floor position, because markers have no facing. GDD rule 22 says "in front of the spot". The user decided to add a facing to the markers (AD-200).

**GDD**: `design/gdd/survivor-defense.md` rule 22
**Requirement**: `TR-defense-006`

**ADR Governing Implementation**: ADR-0008: Hold-to-interact protocol; secondary: ADR-0006 (data-driven configuration), ADR-0007
**ADR Decision Summary**: The map data is the source of placement. The eject offset is a knob.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW

---

## Acceptance Criteria

- [x] Each hiding marker in the map data has a yaw, and the map loader validates it (a missing yaw is a load problem, not a silent 0).
- [x] An eject, whether from a completed Search or from a Search that completes during an entry, places the survivor at the marker floor plus `hide_eject_offset_m` along the marker's facing. The offset is a new knob with a range and a source comment.
- [x] If the spot in front is blocked, the survivor is placed at the nearest free point within 1 m; if there is none, the exit waits (`design/gdd/first-person-controller.md` edge cases, line 245).

---

## Implementation Notes

- The `place(actor, pos)` call in `src/feature/survivor_defense/hiding_spots.gd` is the only eject site.
- New knob: add it to the knobs `.tres` file and re-pin `SHIPPED_DIGEST` in `tests/integration/data_config/digest_version_test.gd`.

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/survivor-defense/hiding_eject_facing_test.gd`
**Status**: [x] `tests/unit/survivor-defense/hiding_eject_facing_test.gd` (7 tests)

## Dependencies

- Depends on: survivor-defense story 006 (Complete)

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-207):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 1110/1110 after the wave merge, no leak warnings.
- Shipped yaws are inference (each points into the room, away from the nearest wall; level doc gives no facings). Greybox placement settles them.
- hide_eject_offset_m 0.6, range 0.4-1.0, marked proposed (GDD names no value). SHIPPED_DIGEST re-pinned.
- 'Blocked' means the room's walls only: no server body-overlap query exists, so other players are not checked. A blocked eject therefore stays blocked for the round (no per-tick retry); no shipped spot hits this (tested).
- The 1 m search is a const (controller GDD rule), not a knob. A voluntary exit is not moved (unchanged, out of story scope).
**Test Evidence**: 7 tests; hiding_spots_test eject rows updated. Mutations caught: facing reversed, 1 m limit removed, capsule margin removed, yaw check removed from errors().
**Code Review**: Complete (orchestrator review at merge)
