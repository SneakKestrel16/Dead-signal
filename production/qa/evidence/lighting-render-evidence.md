# Lighting replication and render evidence (facility-map/010)

Story: `production/epics/facility-map/story-010-lighting-render-blackout.md`. Captured on 2026-10-15 with
Godot 4.7.2, windowed, at 1152x648 with `--write-movie` and `--fixed-fps 30`. The renderer is Forward+ on
the Windows default backend. The backend was not printed (see Not done). The host is
`tests/manual/round_host.gd` and the client is `tests/manual/round_view.gd` with 5 clients in one process.
The map is lit only by `LightingPresenter` (`src/core/facility/lighting_presenter.gd`), using the looks in
`data/lighting/lighting_presets.tres`, which are greybox placeholders. There is no sun.

## Screenshots

All four are in `production/qa/evidence/lighting-render/`.

| File | State | What it shows |
|------|-------|---------------|
| `low-power.png` | Low Power (round start), frame 400 | A survivor in A1 looks east. The overhead spots are dim pools and the red emergency strips glow at floor level. |
| `power-restored.png` | Power Restored (forced at 10 s), frame 1195 | Same view. The overhead pools are brighter. |
| `evacuation.png` | Evacuation (forced at 20 s), frame 2262 | Same view. The overheads are about half of Power Restored. No beacon is in frame (see Not done). |
| `blackout-b2-monster.png` | Blackout in B2, frame 13 after the request | The shapeshifter stands in B2, which it blacked out. On B2's floor only the red emergency strip is lit. The H-N corridor beyond is lit (overhead pools plus strips). |

## AC 1: all clients change state within 1 s

These times come from the round_view `LIGHT` log, one line per record each client applied (run `c`):

- **Power Restored** (tick 601): clients 0-4 applied it between 11153 and 11161 ms.
- **Evacuation** (tick 1201): clients 0-4 applied it between 21154 and 21162 ms.

The spread is under 10 ms. All 5 clients ran in one process on loopback, so this does not measure
real-network spread.

On the server, `lighting_replication_test.gd` (`test_evacuation_reaches_every_viewer_in_the_same_tick`)
shows that every viewer of the volume gets the change in the same tick's reliable batch.

## AC 2: a Blackout darkens one volume and the strips stay

Run `d`: B2 went dark until tick 369. Only client 4, the shapeshifter standing in B2, received a dark
record. The survivors in A1 do not have B2 in their visibility set, so they received nothing for it. This
is ADR-0009 §5 working as designed.

`lighting_presenter_test.gd` covers this:

- `test_blackout_darkens_one_volume_except_emergency_strips`
- `test_every_light_stays_inside_its_volume`: the build-time range check from ADR-0009 §6.

The screenshots show one volume only: there is no "every room and corridor segment" set yet.

## AC 3: reduced flash and frame budget

The steady variants are covered by unit tests:

- `test_evacuation_beacons_use_the_steady_variant_under_reduced_flash`
- `test_reduced_flash_alarm_holds_steady`

There is no retained capture with reduced flash on, and no frame-budget number is recorded. See Not done.

## Commands

```text
<godot> --headless --path . -s res://tests/manual/round_host.gd -- --port=24764 --players=5 --force=10:power,20:evac
<godot> --path . res://tests/manual/round_view.tscn --windowed --write-movie <tmp>/c.avi --fixed-fps 30 --quit-after 2500 \
    -- --port=24764 --count=5 --view=survivor --yaw=-90 --pitch=-10 --shot-at=400 --shot-when=power,evac --shots=<tmp>
<godot> --headless --path . -s res://tests/manual/round_host.gd -- --port=24765 --players=5
<godot> --path . res://tests/manual/round_view.tscn --windowed --write-movie <tmp>/d.avi --fixed-fps 30 --quit-after 700 \
    -- --port=24765 --count=5 --view=monster --blackout --shot-at=300 --shot-when=dark --shots=<tmp>
```

`--force` makes the host emit the trigger events (`ObjectiveProgressChanged` terminal POWERED and
`RoundPhaseChanged` to Evacuation). The objective and timer rules do not run for these forced events.

## Findings

- **Readability.** Low Power and Blackout are very dark on the greybox: much of the frame is black, and the
  ambient light is 0.15. This matches the slice note about the true-form view. The levels to tune are in
  the presets: `overhead_energy`, `ambient_energy` and `emergency_energy`.
- **Fixed.** Parked bodies were getting H-N1's lighting records. Bodies not yet spawned, or Out, wait at
  y = -1000, and `MapQueries.volume_at` reads only x and z, so they counted as standing in H-N1.
  `LightingReplication` now sends nothing to a body more than 1 m below its volume's floor. A regression
  test covers this.

## Not done

- Beacons are not visible in `evacuation.png`. The beacon reach is clipped to half the corridor width
  (2 m), and the camera did not frame a beacon volume.
- No retained reduced-flash capture.
- No frame-budget measurement. `round_view --measure` exists but has not been run. The B1 rack lanes and
  glass partitions are not in the greybox, so they cannot be measured yet.
- D3D12 vs Vulkan comparison not done. The backend was not recorded.

## Sign-off

- [ ] Lead sign-off (Visual/Feel)
