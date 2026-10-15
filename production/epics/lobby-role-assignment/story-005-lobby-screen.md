# Story 005: Lobby screen: player list, Ready and countdown

> **Epic**: Lobby & Role Assignment
> **Status**: Ready
> **Layer**: Core
> **Type**: UI
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]


## Context

Players see who is in the lobby, toggle Ready, see the countdown, and the host sees host controls. The screen only displays server state.

**GDD**: `design/gdd/lobby-role-assignment.md`
**Requirement**: `TR-lobby-001`, `TR-lobby-007`, `TR-lobby-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus (primary, Proposed); ADR-0001: Hosting, session join and reconnect
**ADR Decision Summary**: A client `InputContextStack` owns mouse mode and the gameplay input mask; UI uses stock `Control` nodes on fixed `CanvasLayer`s with stock focus; screens read server state only.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: 4.6 dual focus; 4.7 device IDs no longer 0; `Control.accessibility_live` moved to `AccessibilityServer.AccessibilityLiveMode` (4.7).

**Control Manifest Rules (this layer)**:
- Required: (Proposed) UI rules per ADR-0014 — re-check the control manifest once it is Accepted

---

## Acceptance Criteria

*From `lobby-role-assignment.md` AC-LB-02 and UI Requirements, scoped to this story:*

- [ ] A client joining a host on a configured non-default port appears in the lobby list on every peer (retained screenshot).
- [ ] Ready toggles, the countdown and the host-only controls display server state; a client cannot start a countdown locally.
- [ ] A rejected join shows its reason text on the join screen (retained screenshot).

---

## Implementation Notes

*Derived from ADR-0014 (Proposed) and `lobby-role-assignment.md` UI Requirements:*

- The slice menu (`prototypes/dead-signal-vertical-slice/menu.gd`) is reference for flow only; never copy it.

---

## Out of Scope

- Story 012: queue order display
- Main menu (UX spec not yet written)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshot or capture in `production/qa/evidence/` + sign-off in `production/qa/evidence/lobby-screen-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 002; ADR-0014 Accepted
- Unlocks: Story 012
