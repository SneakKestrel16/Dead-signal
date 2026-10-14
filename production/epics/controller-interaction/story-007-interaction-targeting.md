# Story 007: Interaction targeting by the server's view ray

> **Epic**: First-Person Controller & Interaction
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Pressing interact targets the nearest interactable on the server's view ray that is within its own range, and walls and glass block it. The same query drives the client prompt.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-007`, `TR-controller-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Movement, physics and collision layers (primary); ADR-0008: Hold-to-interact protocol
**ADR Decision Summary**: ADR-0007 §10: interactables register a point and radius from map data; the view ray picks the nearest one within `interact_ray_max_m` and its own range; `intersect_ray` on `world | glass` plus the analytic door test gives the blocking distance. ADR-0008 §2: map interactables get net ids `0..N-1` in map order; `MapQueries.interactable_on_ray` returns a net id.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: ADR-0008 Verification (2) PASS: `PROJECTILE` stops at glass, `SIGHT` passes it, the door blocker is left to the analytic test; `collide_with_areas = false`.

**Control Manifest Rules (this layer)**:
- Required: gameplay zones and interactables are analytic from map data
- Required: hold line-of-sight rays use `PROJECTILE` plus the analytic door test and exclude the actor's own RID
- Forbidden: `Area3D` for gameplay zones, or interactables on a physics layer

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (Hold-to-interact: prompt range; nearest in range; wall) and rule 12, scoped to this story:*

- [ ] With eye height 1.6 m, capsule centre 0.9 m, `interact_ray_max_m` 3.0 and an interactable with `range_m` 2.0 whose point is 2.0 m from the capsule centre, the target resolves; at 2.05 m it does not.
- [ ] With an out-of-range interactable 1.0 m along the ray and an in-range one 1.8 m along it, the 1.8 m one is the target.
- [ ] A wall, a glass pane or a closed door between eye and point gives no target; an open door does not block.
- [ ] The target is computed from the server's view direction, not a client-claimed one.

---

## Implementation Notes

*Derived from ADR-0007 Decision §10 and ADR-0008 Decision §2:*

- `MapQueries.interactable_on_ray(eye, dir) -> int` (net id or −1); client prompt calls the same function on its predicted view.
- Range is measured capsule centre to point; the ray only picks candidates.

---

## Out of Scope

- Story 008: Start validation in `HoldService`
- Prompt UI (HUD epic)

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-003-2026-10-14.md` (/qa-plan, 2026-10-14). Implement against these and the Acceptance Criteria above.*

**What to test**:
- Eye 1.6 m, capsule centre 0.9 m, `interact_ray_max_m` 3.0, interactable `range_m` 2.0: point 2.0 m from capsule centre resolves; 2.05 m does not.
- Out-of-range interactable at 1.0 m along the ray and in-range one at 1.8 m: the 1.8 m one wins.
- Wall, glass pane, closed door between eye and point: no target. Open door: target resolves.
- Target uses the server's view direction: a client-claimed direction passed alongside is ignored.
- Return value is the net id from `MapQueries.interactable_on_ray`, or −1.

**Edge cases to cover**:
- Ray excludes the actor's own RID; `collide_with_areas` false (control manifest).
- Two interactables at equal distance: deterministic pick (lowest net id); record the rule in the code.

**Estimated test count**: ~8 unit tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/first-person-controller/interaction_targeting_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 006
- Unlocks: Story 008
