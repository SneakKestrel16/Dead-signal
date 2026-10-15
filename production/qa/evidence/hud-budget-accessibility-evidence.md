# Test Evidence: HUD visual budget and accessibility pass

**Story**: `production/epics/hud-results/story-010-hud-budget-accessibility-pass.md` (UI, BLOCKING)
**GDD**: `design/ux/hud.md` Visual Budget, Accessibility, Acceptance Criteria 1, 5, 6, 9, 10
**Captured**: 2026-10-15, Godot 4.7.2, windowed 1920x1080, `--write-movie <tmp>/f.avi --fixed-fps 30` (clock run:
`--fixed-fps 30` without a movie, 9 minutes). Real ENet host `tests/manual/round_host.gd` on 127.0.0.1, ports 30901 and 30903.
**Tool**: `tools/hud_measure.py` (stdlib only; PIL is not installed). Every number below is a line it printed.
Screenshots: `production/qa/evidence/hud-budget-accessibility/` (abbreviated `HB/` below).

## How the HUD is isolated

`round_view.gd --bot=budget` saves each state twice: `<tag>.png` (the frame as played) and `<tag>_hud.png`, the
next drawn frame with the camera's cull mask 0 over a flat magenta (255, 0, 255) background, so every non-magenta
pixel is HUD. `<tag>.json` holds the world-marker rects (shape plus label, taken from `PingCalloutHud.place` and the
label width), which coverage excludes, and the Label rects of the roster, checklist, clock and phase label.
Coverage counts pixels differing from the background by more than 12 in any channel; backing plates count in
full, so this is the area the HUD covers, not just glyph ink.

## AC 1 (hud.md AC 5): coverage

| State | Screenshot | HUD px | Marker px excluded | Share | Limit | Result |
|---|---|---|---|---|---|---|
| Exploration (Infiltration, roster 5, checklist, clock, crosshair, taser count; no feed, no markers) | `HB/explore.png`, `HB/explore_hud.png` | 127100 | 0 | **6.13%** | 8% | PASS |
| Busiest: Evacuation, holding (ring at half), 4 feed lines, 5 markers, taser count | `HB/busy.png`, `HB/busy_hud.png` | 181813 | 22232 | **8.77%** | 12% | PASS |

Both include the zone-ambience debug label in the top-left (BUG-0011). Without it: 6.00% and 8.64%.
The busiest capture has no reject label or activation countdown (H9, H3); each is one short plate under 0.5% at
these sizes (inference from the prompt plate, about 160x45 px = 0.35%), so the 3.2-point margin covers them.
A capture with them on screen settles it.

## AC 2 (hud.md AC 6): colourblind simulation

Machado, Oliveira and Fernandes (2009) matrices at severity 1.0, applied in linear RGB, written to `HB/cvd/`.
Contrast is the WCAG ratio between the 95th and 5th luminance percentiles inside each rect (glyph or shape vs. its
plate or surround), before and after each simulation.

| State | Carried by | Source | Original | Protan | Deutan | Tritan |
|---|---|---|---|---|---|---|
| Roster Healthy | "● Healthy" | `HB/busy.png` | 17.62 | 17.62 | 17.62 | 17.62 |
| Roster Downed | "✚ Downed" | `HB/src-downed.png` (copy of `own-state-and-hud-states/downed.png`, 1280x720) | 15.70 | 15.70 | 15.70 | 15.71 |
| Roster Eliminated | "○ Eliminated" | `HB/src-spectating.png` (copy of `own-state-and-hud-states/spectating.png`, 1280x720) | 17.62 | 17.62 | 17.62 | 17.62 |
| Checklist Drives 0/2 | word + count | `HB/busy.png` | 16.90 | 16.90 | 16.90 | 16.93 |
| Checklist Fuses 0/2 | word + count | `HB/busy.png` | 16.79 | 16.79 | 16.79 | 16.79 |
| Checklist Terminal Locked | word | `HB/busy.png` | 16.43 | 16.30 | 16.51 | 16.33 |
| Ping location | diamond + "[name] [n] m" | `HB/src-markers.png` C1 (copy of `feed-and-marker-conformance/markers.png`) | 4.73 | 3.44 | 5.58 | 4.74 |
| Ping location | diamond | same, C4 | 11.83 | 11.00 | 12.34 | 11.67 |
| Ping warning point | triangle + "Warning:" | same | 6.01 | 4.11 | 7.24 | 5.32 |
| Busy markers (location, 5) | arrow / shape | `HB/busy.png` | 4.73-9.36 | 3.44-8.65 | 5.47-9.80 | 4.74-9.26 |

Lowest simulated contrast: 3.44 (protanopia, a red location marker on the dark floor), above the 3:1 WCAG
non-text minimum. Every state differs from the others by word or shape, not colour: roster rows by icon and word,
checklist lines by word, pings by shape (diamond / triangle) and the "Warning:" prefix. Under tritanopia the
warning and location markers both turn pink-red (`HB/cvd/src-markers-tritanopia.png`); they stay apart by shape and word.
**Result: PASS**, with two gaps: the item ping (square) is not in any capture (unit-tested shape only, as in the
feed-and-marker evidence), and only the Locked terminal and 0/2 counts are captured (the other checklist states
are words by construction in `AlwaysOnHud`). No Wounded roster state is drawn yet (AlwaysOnHud header).

## AC 3 (hud.md AC 9, 10): reduced motion and text sizes

### Motion: consecutive HUD-only frames with `--reduced-motion`

| Element | Frames | Measured | Result |
|---|---|---|---|
| H2 phase label on the change to EVACUATION | `HB/evac_00..07.png` | `motion --rect=840,120,240,50`: 0 changed px on frames 1-7 (a cut) | PASS |
| H7 prompt appearing | `HB/prompt_00..07.png` | `motion --rect=660,560,600,80`: 5364, 5304, then 0 changed px; peak luminance 0.471, 0.786, 1.000 on frames 0-2 (a fade) | **FAIL** (BUG-0008) |
| H1 clock, final 30 s | `HB/clock_off_00..07.png` (reduced motion off, 26 s left), `HB/clock_on_00..07.png` (on, 22 s left) | `motion --rect=840,50,240,80`: off 2410, 1371, 1022, 1314, 1006, 1080, 1031 changed px (the pulse, every frame); on 290 on frame 1 (bbox 993-1015 x 77-107: one digit ticking) then 0 | PASS |
| H12 marker fade-out | code: `PingCalloutHud` alpha over FADE_S, no reduced-motion branch | not captured | FAIL by source (BUG-0008) |

Reduced motion is set by the harness: no settings path reaches the presenters' `reduced_motion` (BUG-0008).

### Text sizes at 1080p

Verdict on the font size the code passes (Godot font size = em height in px); ink height (rows holding pixels
brighter than 0.5 luminance in the rect, `hud_measure.py ink`) recorded alongside from `HB/busy_hud.png`.

| Text | Kind | Font size | Ink height | Limit | Result |
|---|---|---|---|---|---|
| Roster rows (H4) | critical | 28 (`AlwaysOnHud.TEXT_FONT`) | 29 | 20 | PASS |
| Checklist (H5) | critical | 28 | 21-22 | 20 | PASS |
| Clock (H1) | critical | 44 | 31 | 20 | PASS |
| Phase label (H2) | critical | 28 | 21 | 20 | PASS |
| Prompt (H7) | critical | 22 (`InteractionHud.FONT_PX`) | 16 (`HB/prompt_07.png`) | 20 | PASS on font size |
| Own state word, bleed-out (H15, H16) | critical | 28 (`OwnStateHud.FONT_PX`) | not captured here | 20 | PASS |
| Taser count (H11) | critical | 28 | 21 | 20 | PASS |
| World progress (H13) | critical | 40 | not captured | 20 | PASS |
| Marker labels (H12) | marker | 20 (`PingCalloutHud.MARKER_FONT`) | 22 (marker 3; others are coloured below the 0.5 threshold) | 20 | PASS |
| Feed lines (H10) | feed | 28 (`PingCalloutHud.FEED_FONT`) | 22 (no descender), 29 (with) | 28 | PASS |
| Install alert label (S6) | marker | 18 (`ShapeshifterInstallAlert.FONT_PX`) | not captured | 20 | **FAIL** (BUG-0009) |
| Face list, kit, status (S1, S2, S3, S5) | critical | 16 (no override: engine default theme size) | not captured | 20 | **FAIL** (BUG-0010) |

Ink height is not the verdict: at font size 20 the ink of a capital is about 15 px, so an ink rule would fail
every 20 px marker label the spec itself sizes. Which one hud.md means is a qa-lead ruling.

## AC 4: this file

Every number above came from the tool on the named screenshot.

## Reproduce

```
G=<godot 4.7.2 console exe>
"$G" --headless --path . -s res://tests/manual/round_host.gd -- --port=30901 --players=6 --force=15:evac &
"$G" --path . res://tests/manual/round_view.tscn --windowed --resolution 1920x1080 --write-movie <tmp>/f.avi \
    --fixed-fps 30 --quit-after 3000 -- --port=30901 --count=6 --view=survivor --bot=budget --reduced-motion \
    --shots=production/qa/evidence/hud-budget-accessibility
# clock: host --players=5 on 30903; view --count=5 --bot=budget --clock, --fixed-fps 30, no movie (about 9 minutes)
python tools/hud_measure.py coverage HB/explore_hud.png HB/explore.json
python tools/hud_measure.py cvd HB/busy.png HB/cvd HB/busy.json
python tools/hud_measure.py ink HB/busy_hud.png HB/busy_text.json
python tools/hud_measure.py motion --rect=660,560,600,80 HB/prompt_0*.png
```

## Sign-off

- [ ] QA lead: numbers reviewed, text-size measure (font size vs. ink height) ruled
- [ ] UX designer: failures accepted as BUG-0008..0011
