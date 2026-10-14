# Story 013: Flinch view offset and client-only camera effects

> **Epic**: First-Person Controller & Interaction
> **Status**: Blocked
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

BLOCKED: ADR-0015 is Proposed — accept it with `/architecture-decision accept ADR-0015` once decided.

## Context

The scare flinch is the one sanctioned server-side view change; every other camera effect is a client-side visual offset that never moves the aim ray.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-006`, `TR-controller-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015: Scare presentation and view offset (primary, Proposed); ADR-0002: Authoritative simulation, tick and input §8
**ADR Decision Summary**: Flinch record and view-offset epoch held on the server and added to client yaw/pitch, ramped in within 0.3 s; offsets replace, not sum; re-baseline (no snap) on reset events; camera shake, jitter and jolt are client-only `Node3D` camera-child effects.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: ADR-0015: plain GDScript on ADR-0002's frame; `CanvasLayer`, `ColorRect` and a `Node3D` camera child, none changed post-cutoff.

**Control Manifest Rules (this layer)**:
- Required: (Proposed) view offset rules per ADR-0015 — re-check the control manifest once it is Accepted

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (Look and view ray: flinch criteria), scoped to this story:*

- [ ] The downing camera impact and shake and the survivor-defense jitter and jolt leave the server view direction and aim ray unchanged.
- [ ] A flinch for a toggled-on player makes the server view direction equal client yaw/pitch plus the offset within 0.3 s and keeps it; for a toggled-off player the view direction never changes; no flinch starts during a lunge wind-up.
- [ ] A second flinch replaces the offset (ramp from current to new target, at most `flinch_max_angle_deg`), and a wind-up cancelling a running flinch freezes the offset.
- [ ] On round end, Downed, Hidden, Seized, reconnect or toggle-off, the offset re-baselines to 0 with no change in view direction on that tick; after a reconnect server and client agree on the first tick.

---

## Implementation Notes

*Derived from ADR-0015 (Proposed) and ADR-0002 §8:*

- Add the offset to `ViewState.server_dir` (Story 006).
- Do not start until ADR-0015 is Accepted; its interfaces may change.

---

## Out of Scope

- Scare event selection (Scare Events epic)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/first-person-controller/view_offset_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006; ADR-0015 Accepted
- Unlocks: Scare Events epic
