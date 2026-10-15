# Story 011: Warning pings and feed scrollback key

> **Epic**: Pings & Callouts
> **Status**: Ready
> **Layer**: Feature
> **Type**: UI
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Story 008 shipped location and item pings, the callout wheel and the feed, but not warning pings (point and player target) or the hold-to-show feed scrollback. Both are in the GDD and `design/ux/hud.md`.

**GDD**: `design/gdd/pings-and-callouts.md` rule 5 (warning ping); UI Requirements
**Requirement**: `TR-pings-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus
**ADR Decision Summary**: Input through `InputContextStack`; the HUD reads projected state only.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: new input actions added to the action list pinned by `view_direction_test`
- Required: UI reads only projected client state

---

## Acceptance Criteria

*From GDD `design/gdd/pings-and-callouts.md`, scoped to this story:*

- [ ] A warning-ping action sends WARNING_POINT at the aimed point, or WARNING_PLAYER when the aim ray hits a visible player body; the marker shows the warning style and the target's displayed identity ("Monster" for true form).
- [ ] Holding the scrollback key shows the last 10 feed lines regardless of age; releasing it returns to the 8 s rule.
- [ ] Retained screenshots of a warning marker and the scrollback view.

---

## Implementation Notes

- Server support for warning kinds exists (story 001); this is client input and presentation.
- Bindings are inference; mark them, a controls pass settles them.

---

## Out of Scope

- Gamepad wheel steering, toggle mode, screen-reader live region (separate follow-ups).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: retained screenshot of each screen touched in `production/qa/evidence/warning-pings-feed-scrollback/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 008
- Unlocks: None
