# Test Evidence: Warning pings and feed scrollback key

> **Story**: `production/epics/pings-and-callouts/story-011-warning-pings-feed-scrollback.md`
> **Story Type**: UI
> **Date**: 2026-10-15
> **Tester**: ui-programmer agent (scripted capture)
> **Build / Commit**: wt-pc11, code bed8749 (capture bot and evidence committed on top)

---

## What Was Tested

`PingCalloutHud.warn()` and the `feed_scrollback` hold (`src/feature/pings_callouts/ping_callout_hud.gd`) in a
real 5-client round: `round_host.gd --port=30955 --players=5` with
`round_view.tscn --count=5 --view=survivor --bot=warn` (windowed, `--write-movie`, 1280x720). The shown
survivor faces the nearest drawn body and warning-pings it; another survivor warning-pings where it looks;
two survivors call out. The feed is shot after its 8 s hold, then again with `feed_scrollback` held
(`Input.action_press`). Logic (WARNING_PLAYER by handle vs WARNING_POINT, hidden and off-ray bodies, the
wall stopping the pick, "Monster" label, warning style flag and colour, 10-line scrollback regardless of
age) is covered by `tests/unit/pings-and-callouts/warning_pings_feed_scrollback_test.gd`.

**Acceptance criteria covered**: AC-1, AC-2, AC-3.

---

## Acceptance Criteria Results

| # | Criterion (from story) | Result | Notes |
|---|----------------------|--------|-------|
| AC-1 | A warning-ping action sends WARNING_POINT at the aimed point, or WARNING_PLAYER when the aim ray hits a visible player body; the marker shows the warning style and the target's displayed identity ("Monster" for true form) | PASS ("Monster" by unit test) | warning.png: the server's WARNING_PLAYER marker (kind 4, identity 3) as a red triangle "Warning: C3  3 m" at the target's feet; a WARNING_POINT from C2 at 40 m. The true-form body was not drawn for the shown survivor in this run, so the "Monster" label is unit-tested only |
| AC-2 | Holding the scrollback key shows the last 10 feed lines regardless of age; releasing it returns to the 8 s rule | PASS | expired.png: feed empty after 8 s; scrollback.png: both retained lines back while held. The 10-line cap and the release are unit-tested |
| AC-3 | Retained screenshots of a warning marker and the scrollback view | PASS | Files below |

---

## Screenshots / Video

| # | Filename | What It Shows | Acceptance Criterion |
|---|----------|--------------|----------------------|
| 1 | `warning-pings-feed-scrollback/warning.png` | Player warning marker on C3 and a point warning from C2, warning style (red triangle) | AC-1, AC-3 |
| 2 | `warning-pings-feed-scrollback/expired.png` | Feed empty once the lines passed their 8 s hold | AC-2 |
| 3 | `warning-pings-feed-scrollback/scrollback.png` | The same moment with `feed_scrollback` held: the retained lines shown again | AC-2, AC-3 |

---

## Test Conditions

- **Game state at start**: fresh round, shown survivor at its spawn facing the nearest drawn body
- **Platform / hardware**: Windows 11, Godot 4.7.2 windowed, `--write-movie` fixed frame step
- **Framerate during test**: not measured (movie mode)
- **Any special setup required**: `--bot=warn` in `tests/manual/round_view.gd`

---

## Observations

- The capture needed the SightTest 360-degree fix (a target straight behind yaw 0 failed the "full circle"
  cone by float rounding, so the server rejected the player warning). This branch does not carry it; main
  fixed it in PC-10 (34c717e). The shots were taken with an equivalent local patch, not committed here.
- A client knows bodies only by opaque handle, so the server now resolves a WARNING_PLAYER target from the
  sender's handle (`RoundComposer._body_of_handle` -> `PingsCallouts.set_body_resolver`).
- Bindings Z (warning ping) and Tab (scrollback) are inference; a controls pass settles them.
- Placeholder look: fallback font, plain shapes; the HUD art pass replaces the drawing.

---

## Sign-off

- [ ] Lead sign-off
