# Story 013: Hiding marker facing and eject in front

> **Epic**: Survivor Defense
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]


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

- [ ] Each hiding marker in the map data has a yaw, and the map loader validates it (a missing yaw is a load problem, not a silent 0).
- [ ] An eject, whether from a completed Search or from a Search that completes during an entry, places the survivor at the marker floor plus `hide_eject_offset_m` along the marker's facing. The offset is a new knob with a range and a source comment.
- [ ] If the spot in front is blocked by a wall, the survivor falls back to the marker position (inference; a designer ruling settles any other fallback).

---

## Implementation Notes

- The `place(actor, pos)` call in `src/feature/survivor_defense/hiding_spots.gd` is the only eject site.
- New knob: add it to the knobs `.tres` file and re-pin `SHIPPED_DIGEST` in `tests/integration/data_config/digest_version_test.gd`.

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/survivor-defense/hiding_eject_facing_test.gd`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: survivor-defense story 006 (Complete)
