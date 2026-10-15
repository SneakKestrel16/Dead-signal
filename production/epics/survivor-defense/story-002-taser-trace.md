# Story 002: Taser trace along the view ray with rewind

> **Epic**: Survivor Defense
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Turns a validated fire intent into a hit: after `stun_use_delay_s` the server traces from the shooter's view, finds the first body in `stun_range_m` within `stun_aim_tolerance_deg`, skipping Seized and Downed survivors, and returns who was hit. It applies nothing yet; stories 003 and 004 act on the result.

**GDD**: `design/gdd/survivor-defense.md`
**Requirement**: `TR-defense-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Lag compensation and rewind; secondary: ADR-0007
**ADR Decision Summary**: Every server hit test, lunge and taser alike, goes through `LagCompensation.targets_at` with positions rewound to the shooter's view tick, capped at `max_rewind_ms` (180).
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Uses `LagCompensation` and `RewindHistory`; physics queries run in the server tick only. Glass blocks the dart (projectile mask `world | glass`, GDD open question, ADR-0007 default).

**Control Manifest Rules (this layer)**:
- Required: all hit tests use `LagCompensation` (ADR-0003); trace on the server only (ADR-0002)
- Forbidden: never trust a client-reported hit or position; never rewind beyond `max_rewind_ms`
- Guardrail: Every value is read from `DefenseKnobs` (`data/knobs/defense.tres`), none hardcoded.

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md` (Detailed Design and Acceptance Criteria), scoped to this story:*

- [ ] The shot hits the first body within `stun_range_m` (5 m) inside the aim tolerance; at 5.1 m or outside 10 degrees it hits nothing, and one cartridge is still consumed (rule 8).
- [ ] A survivor standing in front of the monster is the hit; the monster behind is not (rule 8, edge case).
- [ ] Seized and Downed survivors are skipped: the shot passes through and the monster behind is hit (rule 8).
- [ ] The shot resolves against positions rewound to the shooter's view tick, the same path as the lunge test, and a target that moved after that tick is still hit (rule 8).

---

## Implementation Notes

- `SurvivorDefense` queues the shot for `stun_use_delay_s`, then calls `targets_at(view_tick, rewind, ids)` and picks the nearest body on the ray.
- Seized/Downed come from `Downing` status; hidden survivors are not bodies (story 006).
- Return a result dictionary (hit id or -1, reason in {hit, missed, blocked, range}) so the failure texture in Game Feel can be shown later.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: shocking a hit survivor
- Story 004: stunning the monster
- Story 005: what clients are told

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Logic: `tests/unit/survivor-defense/taser_trace_test.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Stories 003, 004
