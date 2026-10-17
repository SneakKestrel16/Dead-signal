# Art pass in the round (b078dfb, 81ef3ee, b2a1ef4)

In-round captures of the 2026-10-16 art merges: evacuation arrows and PA speaker in H-N, the red C4 beacon, the
survivors' accessories, and the VFX on art meshes (warp, taser arc, stagger, lunge). 1280x720 window, Movie Maker
at 30 fps, captured 2026-10-17. `$G` is the Godot 4.7.2 console exe (`project.yaml` `engine.path`).

```bash
# host: every survivor at x:z, 1 m apart along +x, the shapeshifter 1 m short of the first
"$G" --headless --path . -s res://tests/manual/round_host.gd -- --port=<p> --players=5 --place=<x>:<z> [--force=8:evac]
"$G" --path . res://tests/manual/round_view.tscn --windowed --resolution 1280x720 --write-movie <tmp>/m.avi \
    --fixed-fps 30 --quit-after <n> -- --port=<p> --count=5 --view=survivor <view args> --shots=<dir>
```

| Shot | `--place` | View args | Shows |
|---|---|---|---|
| `hn_arrows_evacuation.png` | `14:2.6`, `--force=8:evac` | `--solo --yaw=-55 --pitch=12 --shot-at=500` | H-N in Evacuation: the `>` arrow at x 17 clear of the pipes, the PA speaker at x 24 beside the pipe run, the orange beacon, the blue stripe |
| `hn_arrow_behind_pipes_before.png` | `19:2.6`, `--force=8:evac` | `--solo --yaw=-20 --pitch=25 --shot-at=500` | Before the fix: the x 20 arrow behind the x 21 pipe run (the faint `>` between the brackets) |
| `c4_beacon_red_evacuation.png` | `55:25`, `--force=8:evac` | `--solo --yaw=10 --pitch=15 --shot-at=500` | C4 in Evacuation: the red beacon and its red floor wash, exit chevrons on the right |
| `warp-late.png`, `disguise.png` | `52:24` | `--bot=stage --disguise --stun` (2400 frames) | The line in C4: the shapeshifter (second from left) mid-transform, then wearing its blue neighbour |
| `arc.png`, `stagger.png` | as above | as above | The taser arc lighting the disguised shapeshifter blue; 6 frames into its stagger |
| `lunge_windup.png`, `lunge_hit.png` | `52:24` | `--bot=lunge` (2400 frames) | The true form's lunge on the shown survivor: wind-up and the hit (Seized) |

`--solo` (new in `round_view.gd`) hides every body but the shown client's own: all five clients draw into one window,
so the others' own bodies stood in front of the camera.

## Found and fixed

- **Arrows hidden behind wall pipes.** The pipe run (`tools/art/build_dressing.py` `cooling_pipes`) is 3 m long at
  2.2-2.6 m; the H-N arrows at x 8 and 20 (2.4 m) sat inside the runs at x 9 and 21, and the H-N PA speaker
  (x 26, 2.3 m) inside the run at x 27. Moved to x 12, 17 and 24 (`data/art/dressing_layout.tres`).
  `map_dressing_test.gd` `test_arrows_and_pa_speakers_hang_clear_of_wall_pipes` fails on the old layout (three
  overlaps) and passes on the new.

## For the designer

These are greybox-lit captures for sign-off: the arrows are unlit signage, so they read only where a ceiling light
reaches them; whether evacuation arrows should glow is an art call (art bible §6 wayfinding names zone colour,
stripes, room signs and landmark lights, not arrows).
