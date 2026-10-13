# HUD mock (prototype)

**Hypothesis:** the `design/ux/hud.md` zone layout (roster top left, clock and phase top centre, checklist top right, centre prompt and hold ring, feed bottom left, kit bottom right, edge cues) reads at a glance and stays inside the 48 px safe margin.

**Run** (writes 30 frames; keep the last):

```
"<godot console exe>" --path . --windowed --write-movie "<abs path>/hud.png" --quit-after 30 res://prototypes/hud-mock/hud_mock.tscn
```

Movie Maker records at the project window size, 1152 × 648; the mock scales its 1080p reference sizes by height.

**Status:** concluded (layout only).

**Findings (2026-10-12):** all zones fit inside the safe-margin guide with no overlap at 16:9; the centre stays clear apart from the crosshair, ring and one prompt line. Not tested: 21:9, fonts, icons, colourblind palette, real scene lighting. Evidence: `production/qa/evidence/hud-mock/01-survivor-holding-investigation.png`.
