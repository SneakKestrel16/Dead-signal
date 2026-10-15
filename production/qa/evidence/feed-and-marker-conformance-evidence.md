# Test Evidence: Feed cap, opaque backing, marker cap, shapes and wheel stick steering

> **Story**: `production/epics/hud-results/story-007-feed-and-marker-conformance.md`
> **Story Type**: UI
> **Date**: 2026-10-15
> **Tester**: ui-programmer agent (scripted capture)
> **Build / Commit**: wt-hud7, code 162ff92 (capture bot and evidence committed on top)

---

## What Was Tested

`PingCalloutHud` reading markers and feed lines from `HudModel` (`src/feature/pings_callouts/ping_callout_hud.gd`,
`src/feature/hud_results/hud_model.gd`) in a real 6-client round: `round_host.gd --port=<307xx> --players=6` with
`round_view.tscn --count=6 --view=survivor --bot=conform` (windowed, `--write-movie`, `--resolution 1920x1080`
and `--resolution 2560x1080`). The five survivors each send a different callout in the same drawn frame;
the feed is shot, then shot again with `feed_scrollback` held. Each survivor then pings twice (10 pings; the
shown survivor's second one is a warning ping) and the marker view is shot. The logic (4 visible, first in
scrollback, none dropped; 7:1 contrast of the box colours; global cap 6 newest kept including a pending own
ping; one shape per ping type; right-stick steering and dead-zone cancel; the 21:9 zone rect; the polite live
region) is covered by `tests/unit/hud-results/feed_and_marker_conformance_test.gd`.

**Acceptance criteria covered**: AC-1, AC-2, AC-3 (margin; stick steering by unit test only), AC-4.

---

## Acceptance Criteria Results

| # | Criterion (from story) | Result | Notes |
|---|----------------------|--------|-------|
| AC-1 | Five callouts in one second all appear in order: four visible, the first in scrollback; the feed sits on an opaque box at 7:1 | PASS | feed.png: lines 2-5 on one black box over the lit floor; scrollback.png: all 5 in arrival order. Log: `CONFORM feed visible=4`, `CONFORM scrollback lines=5`. Box pixels measured pure black (0,0,0) where the floor beside it is (0.086, 0.098, 0.106); white on black is 21:1 |
| AC-2 | At most 6 world markers at once, newest kept; each ping type has its own shape; labels at least 20 px | PASS (size see Observations) | markers.png: 10 pings sent, 6 drawn (`CONFORM markers drawn=6 model=6`); the four oldest gave way (no C2 or C3 marker is left). Location = diamond, warning = triangle ("Warning: C1 40 m"); the item square is unit-tested (no pingable item in view). Labels drawn at font size 20 |
| AC-3 | Right stick steers the wheel; the feed respects the 64 px margin from the 16:9 safe rect at 21:9 | PASS (stick by unit test) | wide/feed.png: leftmost feed ink at x 394 = 320 (16:9 rect left) + 64 + 8 text inset + 2 glyph bearing; lowest ink row 1014, box ends at 1015 (64 px from the bottom). At 1920x1080 the box spans x 48..417 and ends at row 1031 (48 px). Markers still clamp to the full screen edge (wide/markers.png). No gamepad was attached for the capture |
| AC-4 | `PingCalloutHud` and `PingMarkers` read HudModel; retained screenshots of the five-callout feed and a six-marker view | PASS | `PingMarkers` folded into `HudModel.markers_at`; files below |

---

## Screenshots / Video

| # | Filename | What It Shows | Acceptance Criterion |
|---|----------|--------------|----------------------|
| 1 | `feed-and-marker-conformance/feed.png` | 1920x1080: five callouts sent, four visible on the opaque box | AC-1, AC-4 |
| 2 | `feed-and-marker-conformance/scrollback.png` | Same, `feed_scrollback` held: all five in order | AC-1 |
| 3 | `feed-and-marker-conformance/markers.png` | 10 pings sent, 6 markers drawn; diamond and triangle shapes; 20 px labels | AC-2, AC-4 |
| 4 | `feed-and-marker-conformance/wide/feed.png` | 2560x1080: feed 64 px inside the centred 16:9 rect | AC-3 |
| 5 | `feed-and-marker-conformance/wide/scrollback.png` | 2560x1080 scrollback | AC-1, AC-3 |
| 6 | `feed-and-marker-conformance/wide/markers.png` | 2560x1080 marker view | AC-2 |

---

## Test Conditions

- **Game state at start**: fresh 6-player round, shown survivor at its spawn
- **Platform / hardware**: Windows 11, Godot 4.7.2 windowed, RTX 5070, `--write-movie` fixed frame step
- **Framerate during test**: not measured (movie mode)
- **Any special setup required**: `--bot=conform` in `tests/manual/round_view.gd`; pixel measurements by a
  throwaway Godot script reading the PNGs (not committed)

---

## Observations

- Marker label size: font size 20 renders a capital "C" 14 px tall (feed font 28: 21 px). hud.md says labels
  "measure at least 20 px tall"; this build reads that as the font's em size (inference, marked in code). If
  the art pass reads it as cap height, the sizes become 28 / 38. Designer to settle.
- The appearance assignment in `round_host` gives two survivors C1 in a 6-player round, so one line reads
  "C1: Follow me (not you)"; that is the host's greybox cast, not this story.
- The live region (`feed_region`, `AccessibilityServer.LIVE_POLITE`) is set and carries the newest line;
  screen-reader verification with NVDA is out of scope (ADR-0014 Verification 3).
- Both windowed clients print "12 ObjectDB instances were leaked at exit"; the same count appears at the base
  commit 12d1f18 with `--bot=ping`, so it predates this story. The unit and integration suites log no leaks.
- Placeholder look: fallback font, plain shapes; the HUD art pass replaces the drawing.

---

## Sign-off

- [ ] Lead sign-off
