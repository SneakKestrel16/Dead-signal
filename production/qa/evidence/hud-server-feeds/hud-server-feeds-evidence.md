# Evidence: hud-results story 011, the server feeds the HUD (H4 roster names)

Captured 2026-10-15 on one PC from the shipped boot scene (`res://src/main.tscn`) through the shipped lobby path
(LobbyScreen -> RosterHandoff -> RoundHost -> RoundComposer). The host and two players ran headless and one player
ran in a window. All four used the shipped knobs on port 31111. Nothing in `tests/manual/round_view.gd` seeds this
roster: the names come from the server's RosterFeed entry.

```
G=<Godot 4.7.2 console exe>
timeout 150 "$G" --headless --path . -- --lobby-host --lobby-port=31111 --lobby-name=Ana --lobby-ready
timeout 150 "$G" --path . --windowed --resolution 1280x720 -- --lobby-join=127.0.0.1 --lobby-port=31111 --lobby-name=Ben --lobby-ready --lobby-shots=production/qa/evidence/hud-server-feeds
timeout 150 "$G" --headless --path . -- --lobby-join=127.0.0.1 --lobby-port=31111 --lobby-name=Cy --lobby-ready
timeout 150 "$G" --headless --path . -- --lobby-join=127.0.0.1 --lobby-port=31111 --lobby-name=Dee --lobby-ready
```

| Step | Ben's window |
|---|---|
| Lobby, countdown running | `lobby.png` |
| In the round: H4 (Z1) shows the three survivors by their lobby names (Ana, Dee, Ben). The shapeshifter (Cy this round) is not listed | `round.png` |

AC2 (H3 countdown and Paused) and AC3 (H9 "In use" on a refused Start, "Moved away" on a cancel) are shown over
real ENet by `tests/integration/hud-results/hud_server_feeds_test.gd`. Story 011 makes no visual change to H3 or
H9 (out of scope), so the screenshots in `always-on-hud/` and `prompt-hold-ring-reject/` still show their look.

- [ ] Lead sign-off
