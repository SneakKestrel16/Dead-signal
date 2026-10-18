# Facility detail pass, trim (2026-10-17)

The designer's note, 2026-10-17: "facility needs more detail". `MapTrim` (`src/core/facility/map_trim.gd`) adds
the following, built from the wall skins, volumes and passages:

- kick plates, and rails on the painted band;
- riveted pilasters at wall ends and every 3 m;
- ceiling beams on the light grid's thirds;
- doorway headers from 2.5 m to the ceiling, with jambs and hazard-edge thresholds;
- corridor cable trays and pipes.

It uses the existing trim sheets: three merged meshes for the whole map.

Captured in the round, 1280x720, with the same procedure as `art-pass-evidence.md`:

```bash
"$G" --headless --path . -s res://tests/manual/round_host.gd -- --port=<p> --players=5 --place=<x>:<z>
"$G" --path . res://tests/manual/round_view.tscn --windowed --resolution 1280x720 --write-movie <tmp>/m.avi \
    --fixed-fps 30 --quit-after 520 -- --port=<p> --count=5 --view=survivor --solo --yaw=<y> --pitch=<p> \
    --shot-at=500 --shots=<dir>
```

| Shot | `--place` | `--yaw` / `--pitch` | Before (same spot) |
|---|---|---|---|
| `facility-detail/hn_trim.png` | `14:2.6` | -55 / 5 | `art-pass/hn_arrows_evacuation.png` (Evacuation lighting) |
| `facility-detail/a3_trim.png` | `5:20` | -120 / 5 | none |
| `facility-detail/c4_trim.png` | `55:25` | 10 / 10 | `art-pass/c4_beacon_red_evacuation.png` (Evacuation lighting) |

Checked by `tests/unit/facility-map/map_trim_test.gd`:

- No trim stands in a doorway's clear opening below the 2.4 m lintel, which the 2.4 m true form needs. Mutation
  check: a 2.0 m header fails the test 66 times.
- No beam sits over a ceiling fixture.

Full suite: 1735/1735.

Not yet done: more clutter props. Only the hand-placed dressing sets exist.
