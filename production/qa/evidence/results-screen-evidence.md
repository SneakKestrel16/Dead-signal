# Evidence: hud-results story 008, Results screen

Captured 2026-10-15 on one PC, Godot 4.7.2, shipped knobs (`results_duration_s` 20 s). Two sources:

1. **Fixture payloads**: `tests/manual/results_view.tscn` builds the screen from a payload made by
   `RoundResults.to_dict()` (`tests/unit/hud-results/results_fixtures.gd`, the `results.md` wireframe
   numbers), windowed at 1920 x 1080. This gives a survivors-win round, a shapeshifter-win round and a
   missing owner on demand.
2. **Shipped lobby path**: a real round from the boot scene, with `--lobby-shots`, two windows and two
   headless joiners, port 30722. Nobody played, so the round ran to its deadline (540 s), which is a
   shapeshifter win.

```
G=<Godot 4.7.2 console exe>
"$G" --path . --windowed --resolution 1920x1080 res://tests/manual/results_view.tscn -- --shot=<png> [--payload=shapeshifter|missing|corrupt] [--ui-scale=1.5] [--focus=N] [--leave]
timeout 760 "$G" --path . --windowed --resolution 1280x720 -- --lobby-host --lobby-port=30722 --lobby-name=Host --lobby-ready --lobby-shots=production/qa/evidence/results-screen/live-host
timeout 760 "$G" --path . --windowed --resolution 1280x720 -- --lobby-join=127.0.0.1 --lobby-port=30722 --lobby-name=Guest --lobby-ready --lobby-shots=production/qa/evidence/results-screen/live-client
timeout 760 "$G" --headless --path . -- --lobby-join=127.0.0.1 --lobby-port=30722 --lobby-name=Bot1 --lobby-ready   # and Bot2
```

| Case | Screenshot | What it shows |
|---|---|---|
| Survivors win | `results-screen/survivors-win.png` | R1 "SURVIVORS WIN", reason and 8:12, four rows with fate, drive and cause phrases, R4, five objective lines, Z4 with Lunges interrupted. Keyboard focus is on Ana's row, so the ring (a border shape) is visible |
| Shapeshifter wins | `results-screen/shapeshifter-win.png` | "SHAPESHIFTER WINS", "Evacuation deadline expired · 9:00", "(Taken down)", objectives never done show "—", "0/2" and "No" |
| Stats group missing | `results-screen/missing-defense.png` | `stats_defense` listed in `missing`: every stun figure (rows, "Stunned", "Survivor stuns landed") reads "Results unavailable", never 0; other figures unaffected |
| Payload error | `results-screen/corrupt-payload.png` | A survivor's `downs` is a string and `blackouts` is -1: Z2 and Z4 show "Results unavailable", R1, R2, R4, Z3 and the countdown stay |
| 150% UI scale | `results-screen/survivors-win-150.png` | `content_scale_factor` 1.5 at 1920 x 1080: body text at font size 36 px (24 x 1.5), R1 at 72 px; Z2-Z4 scroll (scrollbar shown), focus on the stats group scrolled into view; nothing clips |
| Leave confirm (P29) | `results-screen/leave-confirm.png` | "Leave this session?" with Leave / Stay; keyboard focus on Stay |
| Live round, host | `results-screen/live-host/results.png` | The screen from a real `RoundEnded` on the host's seat: "SHAPESHIFTER WINS", "Evacuation deadline expired · 9:00", the 3 survivors and the shapeshifter by lobby name. The composed round registers no Downing, Survivor Defense or Objectives stats view yet, so the payload lists them in `missing`: downs, rescues, stuns and the whole objectives zone read "Results unavailable", a real missing-group case |
| Live round, joined client | `results-screen/live-client/results.png` | The same content on the joined client |
| Back in the lobby | `results-screen/live-host/back.png`, `live-client/back.png` | After 20 s both are back in the room with no input |

Not shown by a screenshot: the 100 ms and 500 ms timings (the screen is built in the first `_process` after
`MatchDisplay` reports the round ended, so its first frame is the next one; no measured number), and the
2560 x 1080 / 1920 x 1200 safe-margin checks (the screen sits in a 16:9 `AspectRatioContainer` with a 48 px
margin; not captured). The 150% figure is the theme font size, not a measured glyph height.

The automated proof is `tests/unit/hud-results/results_screen_test.gd` (14 cases).

- [ ] Lead sign-off
