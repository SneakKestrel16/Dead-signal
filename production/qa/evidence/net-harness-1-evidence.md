# NH-1 evidence: host/join harness `tests/manual/net_check.tscn`

**Date**: 2026-10-14 · **Commit**: see the NH-1 commit · **Machine**: one Windows PC, local instances on 127.0.0.1 (Godot 4.7.2, headless clients, one windowed host)

## Runs

| Check | Command (after `--`) | Result |
|---|---|---|
| Host starts, prints VERSION | `--role=host --local-player=1` | `VERSION 0.1.0+908cc535`, `HOSTING port 24690, lobby waiting` |
| Valid join | `--role=client --host=127.0.0.1 --name=Ann --mode=route` | client `PLAYER_ID 0`; host `player_joined 0 <peer>` |
| `--build` mismatch | `--role=client --host=127.0.0.1 --build=0.0.9` | `REJECT version_mismatch { "server_version": "0.1.0+908cc535", "client_version": "0.0.9+908cc535" } after 23 ms`; host `sent reject version_mismatch` |
| Empty `--name` | `--name=` | `REJECT bad_name` |
| Raw garbage | `--raw=garbage` | `c0 REJECT bad_payload` |
| Key `L` | host, `L` twice | `LOBBY countdown`, `LOBBY in_match`; a new client gets `REJECT round_in_progress` |
| `--count=2` and key `R` | `--count=2 --name=Bo`, then `R` | `PLAYER_ID 0`, `PLAYER_ID 1`, then `REJOIN 0`, `REJOIN 1`; host `player_dropped` then `player_rejoined` for each (grace stub) |
| `--mode=route`, host local player | as above | host `FINAL host -6.76000 0.00100 -2.14100 ack=630` and `FINAL 0 -6.76000 0.00100 -2.14100 ack=630`; client `DONE ... corrections=0 snaps=0` |
| `--mode=bots --count=5`, host `--local-player=0` | as listed | 5 `PLAYER_ID`; each client `DONE`: 1675-1677 states, 0-2 corrections (6 in 8379 total), 0 snaps, max 0.044 m. Loopback, so this proves the mode works, not the AC1 budget |
| Token never printed | `grep -E "[0-9a-f]{32}"` over every log | 0 lines |

Keys were pressed by a throwaway SceneTree script calling `Input.parse_input_event` (deleted after the run); a person pressing them goes through the same `_unhandled_key_input`.

## Screenshot

`net-harness-1-host-route.png`: the windowed host's final frame of the route run (`--write-movie`, frame 899). It shows the join, the reject and both FINAL lines.

## Not covered here

The two-PC cases themselves (NA-V, designer session).
