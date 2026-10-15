# Story 007: Feed cap, opaque backing, marker cap, shapes and wheel stick steering

> **Epic**: HUD & Results Screen
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

`/ux-review` (2026-10-15) found the shipped Sprint 8 feed and markers differ from `hud.md`: no 4-line cap, a 0.85-alpha backing instead of the opaque box, no global cap of 6 markers, one diamond for every ping type, 18 px marker labels, no gamepad wheel steering, and a flat 48 px feed inset at 21:9.

**GDD**: `design/ux/hud.md` H10, H12, H17; Visual Budget; Platform Adaptation; Accessibility
**Requirement**: `TR-ui-001`, `TR-pings-005`, UX-hud-07, UX-hud-10
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus
**ADR Decision Summary**: Feed and markers read HudModel; the feed is a polite live region; markers clamp to the edge with an arrow.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: feed text at least 28 px and marker labels at least 20 px at 1080p
- Required: the feed is a polite live region; countdowns never are

---

## Acceptance Criteria

*From GDD `design/ux/hud.md`, scoped to this story:*

- [ ] Five callouts in one second all appear in order: four visible, the first in scrollback; the feed sits on an opaque box at 7:1 contrast.
- [ ] At most 6 world markers show at once, newest kept; each ping type has its own shape; labels are at least 20 px.
- [ ] The right stick steers the callout wheel on a gamepad; the feed respects the 64 px margin from the 16:9 safe rectangle at 21:9.
- [ ] `PingCalloutHud` and `PingMarkers` read HudModel; retained screenshots of the five-callout feed and a six-marker view.

---

## Implementation Notes

- Depends on pings-and-callouts 011 (warning pings and scrollback key) being merged; build on it, do not redo it.

---

## Out of Scope

- Screen-reader verification with NVDA (ADR-0014 Verification 3, designer).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: retained screenshot of each screen touched in `production/qa/evidence/feed-and-marker-conformance/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001; pings-and-callouts 011
- Unlocks: None
