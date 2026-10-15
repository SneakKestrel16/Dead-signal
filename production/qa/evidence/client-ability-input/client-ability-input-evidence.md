# Evidence: monster-abilities story 011, client ability input and S7 placement preview

Captured 2026-10-15 on one PC with `tests/manual/round_host.gd` (headless, 5 players) and
`tests/manual/round_view.gd` (windowed, `--write-movie`, 1280x720, 5 clients). Each view client is the shipped
`RoundClient`, the same one the lobby adopts into a round (match-flow 013), so `ShapeshifterAim` is mounted
exactly as in the lobby-to-round build. The bots press the shipped input actions with `Input.action_press`;
only the shapeshifter's client holds a `ShapeshifterAim`, so only it reacts. No raw request bytes are sent.

```
G=<Godot 4.7.2 console exe>
"$G" --headless --path . -s res://tests/manual/round_host.gd -- --port=30762 --players=5
"$G" --path . --resolution 1280x720 --write-movie <tmp>/aim.avi --quit-after 900 res://tests/manual/round_view.tscn -- --port=30762 --count=5 --view=monster --bot=aim --shots=production/qa/evidence/client-ability-input
"$G" --headless --path . -s res://tests/manual/round_host.gd -- --port=30763 --players=5
"$G" --path . --resolution 1280x720 --write-movie <tmp>/lunge.avi --quit-after 1500 res://tests/manual/round_view.tscn -- --port=30763 --count=5 --view=survivor --bot=lunge --via-input --shots=production/qa/evidence/client-ability-input
```

Each host was stopped after its view exited.

| Shot | What it shows | Log |
|---|---|---|
| `fs_preview.png` | False Signal held (shapeshifter view): the snapped floor point (ring) and the 12 m footstep path along the view | `PREVIEW fs_preview: valid true ... end (25, 0, -5.93)` |
| `invalid.png` | False Signal held looking at the sky: no floor in range, so the preview is crossed out. Releasing sent nothing | `AIM false_signal released ...: valid false` |
| `bo_preview.png` | Blackout held: the outline of the target lighting volume (B2) | `PREVIEW bo_preview: valid true ... volume B2` |
| `bo_dark.png` | After the Blackout release: Blackout and False Signal cooldowns are running in S2 | `COOLDOWNS lunge 0.0 s, false_signal 23.0 s, blackout 44.1 s` |
| `windup.png`, `dash.png`, `hit.png` | Survivor view of a Lunge the shapeshifter's client asked for through the `lunge` action: coil, dash, hit-stop | `LUNGE requested at 2.94 m`, `HIT-STOP seen`, host `tick 567 SurvivorDowned` |

The server accepted both releases: the False Signal cooldown started after the first release, and the
Blackout cooldown started after the Blackout release. The crossed-out release in between changed no cooldown.
In the first run the host's lighting record showed the target volume dark (`C5 ... dark_until 632`).
The greybox room barely changes in `bo_dark.png`: before power is restored only the red emergency pools light
it, and a Blackout leaves those on (rule 18). The visible proof is the cooldown and the lighting record.

A survivor client holds no S7 node and sends no request. This is proven automatically, not by screenshot:
`tests/unit/monster-abilities/client_ability_input_test.gd` and
`tests/integration/hud-results/shapeshifter_hud_absence_test.gd` (5 real clients).

- [ ] Lead sign-off
