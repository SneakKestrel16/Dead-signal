# Story 007: Feed cap, opaque backing, marker cap, shapes and wheel stick steering

> **Epic**: HUD & Results Screen
> **Status**: Complete
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

**Status**: [x] production/qa/evidence/feed-and-marker-conformance-evidence.md (6 png); tests/unit/hud-results/feed_and_marker_conformance_test.gd (7)

---

## Dependencies

- Depends on: Story 001; pings-and-callouts 011
- Unlocks: None

## Progress Notes (2026-10-15)

Merged 162ff92+081889e+1ef6535. PingCalloutHud reads markers and feed from HudModel; feed shows 4 lines (FEED_VISIBLE), rest in scrollback; one opaque black backing (21:1); feed_region is a polite live region (AccessibilityServer.LIVE_POLITE, confirmed by running on 4.7.2; not in the reference docs); marker font 20; shape per kind (location diamond, item square, warning triangle); right-stick wheel steering with centre dead zone; zone_rect 48 px or 64 px inside the 16:9 rect when wider; global marker cap HudModel.MAX_MARKERS 6 newest kept (const from Visual Budget). ping_markers.gd deleted (copy of HudModel.on_ping). CHANGED ASSERTIONS (justified by hud.md Feedback table "4 visible (10 in scrollback)" and AC "four visible, the first in scrollback"): ping_callout_presentation_test feed_lines size 10 to 4 (two asserts), warning_pings_feed_scrollback_test first feed_lines size 10 to 4; scrollback asserts unchanged; marker_lifecycle_test setup only (HudModel instead of PingMarkers, every expected value unchanged). OPEN: marker labels use font size 20, a capital measures 14 px; if hud.md means glyph height, sizes go to about 28 and 38 (designer). Item square and right stick unit-tested only (no item in view, no gamepad; project.godot has no gamepad bindings). Windowed client logs 12 ObjectDB leaked at exit, same on base 12d1f18. 7 new unit tests; 3 mutations caught. Full suite 1444 with 7 failures all in integration/match-flow from a concurrent agent run on the same ports (ENet create errors); re-run alone 37/37.

## Closed (2026-10-15)

Closed on its retained screenshots (UI gate). The designer played the shipped build on 2026-10-15 (lobby to round to Results; survivor, shapeshifter and spectating sessions), then approved closing the sprint-9 UI stories in chat (AD-242). Orchestrator reviewed the evidence images. Earlier shots predate BUG-0010/0011 (fixed in b024355); after-fix shots are in production/qa/evidence/hud-budget-accessibility/after/.
