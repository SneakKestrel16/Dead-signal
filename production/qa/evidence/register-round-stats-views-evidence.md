# Evidence: match-flow story 014, every round stats view registered (AC-3)

Captured 2026-10-15 on one PC from the shipped boot scene, run under `tests/manual/results_stats_host.tscn`,
which instances `res://src/main.tscn` unchanged. One windowed host and three headless joiners, shipped
knobs, port 30852.

```
G=<Godot 4.7.2 console exe>
timeout 150 "$G" --path . --windowed --resolution 1280x720 res://tests/manual/results_stats_host.tscn -- --lobby-host --lobby-port=30852 --lobby-name=Host --lobby-ready --lobby-seed=6 --lobby-shots=<dir>
timeout 150 "$G" --headless --path . -- --lobby-join=127.0.0.1 --lobby-port=30852 --lobby-name=Bot1 --lobby-ready   # then Bot2, Bot3, 1 s apart
```

Once the round is Running, the driver lines the bodies up along each player's server view direction. It
sends a Lunge request and taser shots through `RoundComposer._on_packet`, which takes the same bytes a
client sends, so the down and the stun come from the real rules. It then calls `Downing.rescue_completed`,
because a real hold needs aimed input frames. Finally it ends the round with `SurvivorEliminated` for every
survivor, as `lobby_to_round_wiring_test` does.

Shortest legitimate end: all survivors eliminated or escaped. Unscripted, that takes two completed
takedowns per survivor or a full evacuation. With nobody playing, the only end is the deadline
(`round_duration_s` 540 s), so the end is forced.

`--lobby-seed=6` makes the host seat the shapeshifter. A survivor's seat that is Out when the round ends
never shows Results. `ServerMovement._snapshot_phase` skips a spectator whose watched survivor has no
body, so once the last survivor is removed, no Out client gets the RoundEnded batch. This is a bug outside
this story, reported to the orchestrator.

| Shot | What it shows |
|---|---|
| `register-round-stats-views/results.png` | "SHAPESHIFTER WINS · All survivors eliminated · 0:06". Bot1: downs 1. Bot2: rescues 1, stuns 1. Takedowns 1, Eliminations 3, Lunges landed 1, Stunned 1. Objective lines 0/2 with no "Results unavailable" anywhere (`missing` is empty) |

The automated proof (real ENet, 5 clients) is in
`tests/integration/match-flow/register_round_stats_views_test.gd`.

- [ ] Lead sign-off
