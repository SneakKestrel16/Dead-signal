# Evidence: monster-abilities story 007, lunge cue, coil pose and hit feedback

`LungePresenter` (`src/feature/monster_abilities/lunge_presenter.gd`) in `RoundClient`, fed by the server's
Lunge sounds (`MonsterAbilities.CUE_SOUND`, `SCRAPE_SOUND`, `HIT_SOUND`, sent through
`ServerMovement.emit_sound` at `lunge_cue_radius_m`). Launched by `tests/manual/round_view.tscn --bot=lunge`
against `tests/manual/round_host.gd` (5 players, real ENet on 127.0.0.1). Godot 4.7.2, windowed,
`--write-movie <tmp>/f.avi --fixed-fps 30`, 2026-10-15. Each screenshot is the drawn frame, saved after
`RenderingServer.frame_post_draw`. Everything shown is a greybox placeholder: the shapeshifter is the red
capsule, survivors are coloured capsules.

## Captures (`lunge-presentation/`)

1. `windup.png` (frame 1249): a survivor's view 4 frames after the cue arrived (`COIL seen at frame 1245`).
   The red shapeshifter body is squashed and widened: the placeholder coil pose (`COIL_SCALE`).
2. `dash.png` (frame 1320): the first frame the drawn shapeshifter had moved more than 0.3 m from its
   wind-up spot. The body is back at full height, dashing at the camera.
3. `hit.png` (frame 1338): the frame the hit sound arrived and the 80 ms hit-stop started; the
   shapeshifter stands at the survivor. The host logged `tick 760 SurvivorDowned` after the takedown commit.

Not captured: the miss stumble (forward tilt for `miss_slow_s`). An earlier run of the same bot missed and
logged `STUMBLE seen at frame 1346`, but that run's harness did not dash (see Harness change), so its
frame is not kept. The stumble is covered by `lunge_presenter_test.gd`. Sound cannot be shown in a
screenshot: the cue's position and radius are asserted in `lunge_presenter_test.gd` and `lunge_cue_test.gd`.

## Commands

Captured on port 24777; the commands below use the manual-capture range (30000-30999) that is now the rule.

```text
<godot> --headless --path . -s res://tests/manual/round_host.gd -- --port=30777 --players=5   # ports 30000-30999 only; the host lives until its round ends: stop it after the capture
<godot> --path . res://tests/manual/round_view.tscn --windowed --write-movie <tmp>/f.avi --fixed-fps 30 \
    --quit-after 2400 -- --port=30777 --count=5 --view=survivor --bot=lunge --shots=<tmp>
```

## Harness change

`TestMoveStep.apply` (the stand-in step both manual scenes use) ignored `MovementModifiers.dash_speed`, so
the monster stood still through Active. It now calls `MovementStep._dash` while a dash is set.

## Timing note

Under `--write-movie` the client renders faster than real time while the headless host runs in real
time, so frame gaps between captures are not game time.

## Sign-off

- [ ] Lead sign-off: coil pose, dash and hit-stop read correctly (Visual/Feel gate)
