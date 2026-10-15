# Lobby queue order evidence (story lobby-role-assignment/012)

Captured 2026-10-15 with Godot 4.7.2 windowed (`Godot_v4.7.2-stable_win64.exe`), 1280x720,
`--write-movie`, from `res://src/main.tscn` driven by the screen's `--lobby-*` command-line flags. Four
processes on 127.0.0.1, port 24681, all joining with `--lobby-ready`:
host Ann (`--lobby-host --lobby-seed=3 --lobby-cancel-round`, 900 frames), then Bob, Cy (900 frames) and
Dee (700 frames). Seed 3 shuffles the queue to Dee, Bob, Ann, Cy. The countdown runs, the roster locks
and draws the queue, `--lobby-cancel-round` ends the round as Cancelled at once (stand-in for Match Flow:
the round start is not wired yet), so the lobby returns to Waiting with the queue not advanced (rule 9)
and Ready cleared. Dee then quits on their own (`--quit-after`), which leaves an absent token at the head.

| Screenshot | State shown | AC |
|---|---|---|
| `lobby-queue-order/01-client-ready-picker-disabled.png` | Client Bob, Ready, in the countdown: the Character picker is greyed out (disabled while Ready); the queue line says it is drawn when the first round starts | 2 |
| `lobby-queue-order/02-host-absent-head-next-shapeshifter.png` | Host Ann after the cancelled round: queue 1. Dee (away), 2. Bob marked "next shapeshifter", 3. Ann (you), 4. Cy | 1 |
| `lobby-queue-order/03-client-bob-absent-head-picker-enabled.png` | Client Bob, same queue and next shapeshifter (himself); not Ready, so the picker is enabled | 1, 2 |
| `lobby-queue-order/04-client-cy-absent-head.png` | Client Cy, same queue and next shapeshifter as host and Bob | 1 |

The host and both remaining clients show the same server queue, so the order and the next
shapeshifter come from the server's `LobbySync` packet. The picker request path (fixed packets, refused
while Ready) and the queue encode/decode are covered by `tests/unit/lobby/queue_order_display_test.gd`.
The next shapeshifter is marked in text only: there is no art-direction spec for a highlight colour yet.

## Sign-off

- [ ] Designer sign-off
