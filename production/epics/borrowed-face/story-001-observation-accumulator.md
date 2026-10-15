# Story 001: Observation accumulator

> **Epic**: Borrowed Face
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

## Context

The shapeshifter must watch a survivor for 3 s, close and in view, before it can copy them. The server counts valid observation per tick per survivor.

**GDD**: `design/gdd/borrowed-face.md`
**Requirement**: `TR-borrowedface-003`, `TR-borrowedface-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Movement, physics and collision layers (primary); ADR-0005: Event catalog, state registry and tick order; ADR-0006: Data-driven configuration
**ADR Decision Summary**: Observation sight rays use the `SIGHT` mask (`world` only; glass does not block; doors tested analytically from authoritative state); Borrowed Face runs at its fixed place in the tick order and owns its state; `observe_time_s`, range and cone from `BorrowedFaceKnobs`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0008 Verification (2): `SIGHT` passes glass; doors are left to the analytic test.

**Control Manifest Rules (this layer)**:
- Required: every physics query uses a `PhysicsLayers` mask; world rays use `SIGHT` for line of sight
- Forbidden: inline layer or mask numbers [inline_layer_numbers]

---

## Acceptance Criteria

*From `borrowed-face.md` Acceptance Criteria (observation), scoped to this story:*

- [x] A survivor is marked observed only after 3 s cumulative valid observation within 15 m and the view cone; behind a wall or a closed door nothing accumulates.
- [x] A survivor 46° off the look direction accumulates nothing; at 44° it does. A survivor 46° off measured horizontally to the chest point accumulates nothing even if the head is in view at any pitch.
- [x] While Stunned, and during the shock lock (Survivor Defense rule 14), no observation accumulates on a survivor that otherwise qualifies.
- [x] `observe_time_s`, range and cone half-angle are read from `BorrowedFaceKnobs`.

---

## Implementation Notes

*Derived from `borrowed-face.md` rule 2 and ADR-0007 §5:*

- Count in ticks via `Knobs.ticks`; the cone test is horizontal to the chest point.
- Stun and lock come from Survivor Defense state views; stub them until that epic lands.

---

## Out of Scope

- Observed-faces HUD panel (HUD epic)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/borrowed-face/observation_test.gd` — must exist and pass

**Status**: [x] `tests/unit/borrowed-face/observation_accumulator_test.gd` (13 tests)

---

## Dependencies

- Depends on: controller-interaction stories 001, 006; event-catalog story 003
- Unlocks: Story 002

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: all passing (automated)
**Deviations** (AD-144):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 748/748 after the wave merge, no leak warnings.
- New `BorrowedFace` module at `TickOrder.BORROWED_FACE`; collaborators injected via `set_roster` and `set_sight_sources`.
- `MapQueries.clear_sight` added; `_door_blocks` now takes a `door_closed` Callable (callers updated).
- Range eye-to-chest is inference (GDD: `dist(monster_eye, survivor)`). Stun and shock lock are one injected `locked` Callable until Survivor Defense publishes SHOCK_STUN_LOCK.
- Not wired into a live round yet.
**Test Evidence**: 13 tests. Mutations caught: cone to head, full FOV, lock check removed, wrong ray mask.
**Code Review**: Complete (orchestrator review at merge)
