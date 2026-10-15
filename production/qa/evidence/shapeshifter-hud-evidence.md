# Evidence: Shapeshifter HUD (story hud-results/006)

**Story**: `production/epics/hud-results/story-006-shapeshifter-hud.md` (UI)
**Spec**: `design/ux/hud.md` S1-S7; ADR-0004 §5, ADR-0014 §6
**Captured**: 2026-10-15, Godot 4.7.2, 1280x720, `--write-movie` (drawn frames, not wall seconds)

## How it was captured

```
godot --headless --path . -s res://tests/manual/round_host.gd -- --port=30682 --players=5
godot --path . --resolution 1280x720 --write-movie <tmp>.avi --quit-after 2400 res://tests/manual/round_view.tscn -- \
    --port=30682 --count=5 --view=monster --bot=shifter --shots=production/qa/evidence/shapeshifter-hud
```

`--bot=shifter` (added to `tests/manual/round_view.gd` for this story): the shown shapeshifter requests a Lunge,
walks to the nearest survivor while observing, changes into it once its face is available, and that survivor
then tases it.

## Screenshots

| File | State | What it shows | Printed value at the shot |
|---|---|---|---|
| `shapeshifter-hud/trueform.png` | True form | S1 face list filling (top left), S2 "Form: True form Ready", S3 Lunge counting down, False Signal and Blackout Ready (bottom right) | lunge 2.0 s, face 0.41 |
| `shapeshifter-hud/transforming.png` | Transforming | S4 bar under the crosshair at ~40%, every face Available | progress 0.40 |
| `shapeshifter-hud/disguised.png` | Disguised | S2 "Form: C2 12" (the form cooldown), S4 gone | form cooldown 11.6 s |
| `shapeshifter-hud/stunned.png` | Disguised, stunned | S5 "Stunned 2.0" in Z4 (the blue edge is the shock presentation of survivor-defense/011) | stun 2.0 s |

The ambience debug overlay (facility-map/012) is drawn over the top of the face list in Z1; it is a debug
overlay, not part of the HUD spec.

## Not shown

- S6 install alert: needs a survivor installing a fuse during the capture; covered by
  `tests/unit/hud-results/shapeshifter_hud_test.gd` (`test_install_alert_lives_its_duration`) only.
- S7 placement preview: not built. No client aiming state exists for False Signal or Blackout, so there is
  no trigger state to draw it in.
- Survivor absence: proved by `tests/integration/hud-results/shapeshifter_hud_absence_test.gd` (5 real-ENet
  clients; no `^S[1-7]` node or `ShapeshifterHud` in any survivor client's tree).

## Sign-off

- [ ] Lead sign-off (UI screenshots reviewed)
