# Evidence: match-flow story 013, lobby countdown starts the round, round end returns to the lobby (AC-4)

Captured 2026-10-15 on one PC from the shipped boot scene (`res://src/main.tscn`). There were two windowed
instances, one hosting and one joining, plus two headless instances joining as players. The lobby needs
`min_players` = 4 (`data/knobs/lobby.tres`), so two windows alone cannot start a round. Every instance
ran the shipped knobs, port 31000. Screenshots come from the screen's `--lobby-shots` flag, which grabs
the viewport.

```
G=<Godot 4.7.2 console exe>
timeout 720 "$G" --path . --windowed --resolution 1280x720 -- --lobby-host --lobby-port=31000 --lobby-name=Host --lobby-ready --lobby-shots=production/qa/evidence/lobby-to-round-wiring/host
timeout 720 "$G" --path . --windowed --resolution 1280x720 -- --lobby-join=127.0.0.1 --lobby-port=31000 --lobby-name=Guest --lobby-ready --lobby-shots=production/qa/evidence/lobby-to-round-wiring/client
timeout 720 "$G" --headless --path . -- --lobby-join=127.0.0.1 --lobby-port=31000 --lobby-name=Bot1 --lobby-ready
timeout 720 "$G" --headless --path . -- --lobby-join=127.0.0.1 --lobby-port=31000 --lobby-name=Bot2 --lobby-ready
```

Nobody played, so the round ran to its deadline (`round_duration_s` 540 s) and then through Results
(`results_duration_s` 20 s).

| Step | Host window | Joining window |
|---|---|---|
| Lobby, countdown running | `host/lobby.png` | `client/lobby.png` |
| In the round (own first-person view, greybox round line) | `host/round.png` | `client/round.png` |
| Results (greybox outcome line; the Results screen is hud-results 009) | `host/results.png` | `client/results.png` |
| Back in the lobby: same session, Ready cleared, queue drawn and advanced | `host/back.png` | `client/back.png` |

The automated proof (real ENet, a host and 3 clients) is in
`tests/integration/match-flow/lobby_to_round_wiring_test.gd`.

- [ ] Lead sign-off
