# Evidence: hud-results story 009, lobby "Last round" view

Captured 2026-10-15 with Godot 4.7.2, windowed, 1280x720, on one PC. The capture scene
`res://tests/manual/lobby_last_round.tscn` runs the shipped `LobbyScreen`, which hosts a session from its own
`--lobby-*` flags on port 30860. No round is played. Instead, the recorded `survivors_win()` payload
(`tests/unit/hud-results/results_fixtures.gd`) is put where the lobby stores it at `RoundEnded`, and the
room is shown again. The view is then opened and closed with real `ui_accept` / `ui_cancel` input events.

```
G=<Godot 4.7.2 console exe>
timeout 60 "$G" --path . --windowed --resolution 1280x720 res://tests/manual/lobby_last_round.tscn -- --lobby-host --lobby-port=30860 --lobby-name=Host --shots=<abs path>/production/qa/evidence/lobby-last-round
```

| Screenshot | State shown | AC |
|---|---|---|
| `lobby.png` | Room after a round: **Last round** button between Ready and Leave, with keyboard focus | 1 |
| `view.png` | Last round view: title "Last round" above R1, the stored results, no countdown and no Leave session, **Back** (R9) focused | 1 |
| `back.png` | After Esc: the room again, with focus restored to the **Last round** button | 1 |

The button's absence before any round and after the host leaves is shown by
`tests/unit/hud-results/lobby_last_round_test.gd`. That suite also covers the stored payload, the missing
countdown, focus restore, Esc and a starting round closing the view.

Two things differ from the shipped path. The room sits at the top left because the capture scene parents the
screen under a plain Node, not under `main.tscn`. The round end is fed in by the scene; it is not reached
over the network.

## Sign-off

- [ ] Lead sign-off
