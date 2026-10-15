# Evidence: hud-results story 002, always-on survivor HUD

`AlwaysOnHud` (`src/feature/hud_results/always_on_hud.gd`) on the `RoundClient` HUD layer, launched by
`tests/manual/round_view.tscn` against `tests/manual/round_host.gd` (5 players, real ENet on 127.0.0.1).
Godot 4.7.2, windowed, `--write-movie`, `--fixed-fps 30`, drawn frame 560 (about 18.7 s into the round),
2026-10-15. Spec: `design/ux/hud.md` H1-H6, Layout Zones, HUD States.

## Captures (`always-on-hud/`)

1. `exploration-1920x1080.png`: a survivor in exploration (Infiltration). Shows the roster top left (four
   survivors, each with "● Healthy"), the clock and "INFILTRATION" top centre, the checklist top right
   ("Drives 0/2", "Fuses 0/2", "Terminal Locked") and the crosshair dot at the centre. No activation
   countdown: the terminal is not Activating. No markers or feed lines were live.
2. `exploration-2560x1080.png`: the same at 21:9. The corner zones sit inside the centred 16:9 rect
   (x 320-2240) with the 64 px margin.
3. `exploration-1920x1200.png`: the same at 16:10. The anchors are the same as 16:9 and the extra height is unused.
4. `exploration-roster-off-1920x1080.png`: Show roster Off (`--no-roster`). The roster is absent and the
   rest is unchanged.

The "Ambience: zone A ..." line at the top left is the zone ambience debug overlay (facility-map story 012),
not part of this HUD.

## Measurements

These were measured on the PNGs with a pixel scan for bright text (luma > 0.7, below y = 40, where the
debug line ends). The scan finds glyph bounds. The backing plate edge is 12 px further out
(`PLATE_PAD_PX`), so plate margin = glyph margin - 12 minus the glyph's side bearing. The exact plate
rects are asserted in `test_margins_hold_at_16_9_16_10_and_21_9`.

| Capture | Roster glyphs left / top | Checklist glyphs right gap / top | Required |
|---|---|---|---|
| 1920x1080 | x 60 / y 69 | 62 px from the right edge / y 68 | 48 px from each edge |
| 2560x1080 | x 396 (76 px from the safe rect at 320) / y 85 | 398 px from the edge (78 px from the safe rect at 2240) / y 84 | 64 px from the 16:9 safe rect |
| 1920x1200 | x 60 / y 69 | 62 px / y 68 | 48 px |

Text height at 1080p: the "D" stem of "Drives" (28 px font) measures **21 px**, which is the capital
height. This meets the 20 px critical-text floor. The clock uses a 44 px font.

## Commands

```text
<godot> --headless --path . -s res://tests/manual/round_host.gd -- --port=30628 --players=5
<godot> --path . res://tests/manual/round_view.tscn --windowed --resolution 1920x1080 --write-movie <tmp>/f.avi \
    --fixed-fps 30 --quit-after 600 -- --port=30628 --count=5 --view=survivor --bot=look --light \
    --shot-at=560 --shots=<tmp>
# 2560x1080 on port 30629, 1920x1200 on 30630, --no-roster at 1920x1080 on 30631
```

## Known gaps

- **Roster names:** no server message carries the round roster to clients yet. `round_view` seeds the
  shown client's `HudModel.set_survivors` with its own clients' player ids ("View<i>"). In the shipped
  lobby path the roster shows only the survivors that an event has named, until a producer calls
  `set_survivors`.
- **Activation countdown seconds and "Paused":** no server message carries them yet. `HudModel.on_activation`
  is the handler (unit-tested). Without it, H3 reads "Activating" while the terminal is Activating.
- Not drawn: the Wounded state, which HudModel has no state for, the Hidden state's crosshair hide, and the
  final-30 s ticking layer, which is audio.
- The final-30 s pulse, the 150 ms fades and the 1 s checklist highlight are not in these stills.

## Sign-off

- [ ] Lead sign-off (UI evidence, `production/qa/evidence/always-on-hud/`)
