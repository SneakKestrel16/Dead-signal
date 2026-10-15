# Lobby screen evidence (story lobby-role-assignment/005)

Captured 2026-10-15 with Godot 4.7.2 windowed, 1280x720, `--write-movie`, from `res://src/main.tscn`
driven by the screen's `--lobby-*` command-line flags. Host on port 24680 (the shipped default is
24690, so this is the non-default port of AC-LB-02). Each instance ran as its own process on 127.0.0.1.

| Screenshot | State shown | AC |
|---|---|---|
| `lobby-screen/01-join-form.png` | Join form: name, host address, port (knob default), Host and Join; focus on Name | form |
| `lobby-screen/02-host-waiting-host-controls.png` | Host view in Waiting: clients Bob and Cy listed, Kick on each other row, proximity voice enabled (host only) | 1, 2 |
| `lobby-screen/03-client-joined-port-24680.png` | Client Bob joined on port 24680: sees host Ann and self, voice toggle disabled (view only), no Kick | 1, 2 |
| `lobby-screen/04-client-countdown.png` | Client view of the server countdown, 4 Ready players: "Starting in 4" | 2 |
| `lobby-screen/05-client-roster-locked-starting.png` | Countdown reached 0, roster locked: "Starting" (round start not wired, story deviation) | 2 |
| `lobby-screen/06-join-rejected-reason.png` | Join refused by the host (17-character name, `bad_name`): reason text on the join form | 3 |

Every displayed lobby value comes from the server's `LobbySync` packet; the client sends only the
Ready request (`tests/unit/lobby/lobby_screen_test.gd`).

## Sign-off

- [ ] Designer sign-off
