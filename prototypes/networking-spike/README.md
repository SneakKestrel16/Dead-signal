# Networking Spike

**Status**: concluded for single-machine tests, 2026-10-12. Tests that need a second
PC on another network are still open (see [Deferred](#deferred-needs-a-second-pc-on-another-network)).

Throwaway prototype. Its numbers feed the Network Authority ADR. No production
code may import from here.

## Hypotheses

1. A Godot 4.7.2 listen server can own all movement (clients send intent only)
   while client prediction plus reconciliation keeps the owning player smooth at
   50–150 ms RTT.
2. 6 players fit comfortably in host upload bandwidth and server CPU at a 30 or
   60 Hz tick.
3. Lag-compensated hit checks (server rewind) can match what the attacker saw,
   within the 150 ms rewind cap `monster-abilities.md` assumes.
4. `MultiplayerSynchronizer` per-peer visibility can hide a node and its state
   from chosen peers (needed for the disguise, objective discovery and
   single-client hallucinations).
5. `SceneMultiplayer.auth_callback` can validate joins (version, lobby cap) and
   a player token can restore a reconnecting player's slot under a new peer ID.

## How to run

```bash
bash run_tests.sh            # all: move matrix (7 runs x 6 clients), vis, auth
bash run_tests.sh smoke      # 4 s, 2 clients
bash run_tests.sh move|vis|auth
```

Needs Godot 4.7.2 (path in the script, override with `GODOT=`). Each run starts a
headless server and headless bot clients on `127.0.0.1`. Results go to
`results/<tag>.json`; per-process logs to `logs/` (gitignored).

Latency, jitter and loss are **simulated in-process**: every sender delays its own
packets by the one-way latency (plus up to the jitter for unreliable sends) and
drops unreliable sends with the loss probability. Bots move in a 20 × 20 m room
with two pillars, change direction every 0.4–1.5 s and sprint half the time, using
the controller's numbers (walk 4.0 m/s, sprint ×1.25, capsule r 0.3 / h 1.8,
Jolt `CharacterBody3D`). Inputs carry the last 3 inputs for loss redundancy;
remote players render 100 ms behind the newest snapshot.

## Findings (single machine, Windows, 7 Godot processes sharing one CPU)

| Run | RTT p50 (ms) | Ticks/s | Host up per client (kbps) | Host up total (kbps) | Host down per client (kbps) | Server tick µs p50/p99 | Corrections / states | Snap p95/max (m) | Server input starvation | Rewind needed p50/p95 (ms) | Probes over 150 ms | Full-rewind err p95 (m) | 150 ms-capped err p95 (m) | No-rewind err p95 (m) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| t60-rtt0 | 7 | 60 | 86.9 | 521 | 40.4 | 55/131 | 1/6974 | 0.12/0.12 | 0.3% | 103/110 | 0/194 | 0.00 | 0.00 | 0.55 |
| t60-rtt50 | 62 | 60 | 86.9 | 521 | 40.4 | 49/90 | 4/6754 | 0.15/0.15 | 0.4% | 160/170 | 185/193 | 0.00 | 0.08 | 0.81 |
| t60-rtt100 | 117 | 60 | 86.9 | 521 | 40.3 | 55/131 | 20/5616 | 0.17/0.33 | 10.4% | 210/226 | 190/191 | 0.00 | 0.35 | 1.10 |
| t60-rtt150 | 159 | 60 | 86.9 | 521 | 40.1 | 55/117 | 5/5822 | 0.14/0.14 | 2.2% | 260/276 | 188/189 | 0.00 | 0.60 | 1.35 |
| t60-rtt150, 30 ms jitter, 2% loss | 159 | 60 | 85.2 | 511 | 39.4 | 56/141 | 53/5022 | 0.16/0.30 | 17.8% | 263/279 | 186/186 | 0.00 | 0.63 | 1.36 |
| t30-rtt100 | 117 | 30 | 43.7 | 262 | 20.8 | 58/130 | 10/3432 | 0.26/0.26 | 6.3% | 213/226 | 186/187 | 0.00 | 0.38 | 1.13 |
| t30-rtt150 | 159 | 30 | 43.7 | 262 | 21.0 | 57/143 | 99/3405 | 0.29/0.30 | 18.7% | 253/260 | 190/191 | 0.00 | 0.55 | 1.30 |

RTT is measured (simulated one-way 0/25/50/75 ms, plus about 8 ms of loop and
ENet overhead). "Server tick µs" is the movement simulation for 6 capsules plus
building the state; sending added another 77–100 µs per tick.

**H1 — server-owned movement with prediction: supported.** The owning client's
prediction matched the server on 99%+ of states at every latency. Corrections
happen only when an input reaches the server late (server "starvation": it
repeats the last input) on a tick where the bot changed direction. Snaps were at
most 0.33 m at 60 Hz and 0.30 m at 30 Hz. Starvation varied run to run (0.3–19%)
with clock phase between processes, not cleanly with latency: the server has no
input buffer. **Recommendation:** buffer 1–2 ticks of input on the server before
consuming; keep the 3-input redundancy.

**H2 — bandwidth and CPU: supported, with margin.** At 60 Hz with 6 players the
host uploads about 87 kbps per client, about 0.52 Mbps total (30 Hz halves it).
The state here is minimal (position, yaw, gait for 6 players); real state
(life state, form, item use) and voice add to it. Server cost for 6 Jolt
capsules was about 55 µs per tick (p99 under 0.15 ms) plus about 0.1 ms to send:
under 2% of a 16.6 ms frame. **Recommendation:** 60 Hz simulation; drop the
snapshot rate to 30 Hz only if the real-network test shows upload pressure.

**H3 — rewind within 150 ms: NOT supported as specified.** Full rewind reproduced
exactly what the attacker saw (error 0.00 m). But the rewind needed is the
one-way latency **plus the 100 ms interpolation delay** plus about one frame:
about 103 ms at 0 RTT, 160 at 50, 210 at 100, 260 at 150. With the 150 ms cap,
almost every probe at 50 ms RTT or more was capped. The capped error was
0.08 m at 50 ms RTT, 0.35 m at 100 and 0.60 m at 150 (p95), against a 1.2 m
lunge hit radius and the dodge window `monster-abilities.md` derives from a
150 ms rewind. **Recommendation for the ADR:** define the rewind budget as
interpolation delay + maximum supported one-way latency. Either raise the cap
to about 250–300 ms, or cut interpolation to about 50 ms (3 snapshots at 60 Hz),
or both. Then rerun the Monster Abilities dodge-window check with the chosen
budget. This is a design-relevant finding, not only a technical one.

**H4 — per-peer visibility: supported.** With `public_visibility = false` and
`set_visibility_for(A, true)`, the node spawned and synced on A only; B never
received it. Making it visible to B spawned it on B with current state;
revoking A despawned it on A while B kept syncing (`results/vis.json`).

**H5 — join validation and token reconnect: supported.** Six players were
accepted, a seventh was refused with `lobby_full`, a wrong build with
`version_mismatch` (both get the reason before the disconnect). The player with
token `t3` left and rejoined under a new peer ID and got slot 2 back
(`results/auth.json`).

### Limits of these results

- Loopback with simulated latency: no real jitter spikes, bursts, packet
  reordering by routers, MTU issues or NAT.
- All 7 processes share one CPU, which adds scheduling jitter of its own.
- Players do not collide with each other; state is minimal; bots, not humans.
- The ENet "Unable to send packet on channel 0" error appears once per client at
  teardown (sends to a peer that is closing); it does not affect the results.

## Deferred: needs a second PC on another network

Run these before the Network Authority ADR is accepted (they can follow its draft):

1. **Real WAN latency, jitter and loss:** host here, a client on another network
   (a friend's PC or a mobile hotspot). Compare measured RTT, starvation and
   correction rates with the simulated rows above.
2. **Host upload on a home connection:** confirm about 0.5 Mbps at 60 Hz for 6
   players fits with headroom, then add proximity voice when it exists.
3. **Reachability for direct-IP join:** port forwarding, firewall prompts, NAT
   types. Does a friend reach the host without manual router setup? Is UPnP or a
   relay needed?
4. **Clock drift between machines:** does the server input queue grow or starve
   over a 9-minute round, and does the 2-per-tick catch-up rule keep up?
5. **Wi-Fi spikes:** a client on Wi-Fi with background traffic; watch snap sizes
   and stale-state counts.

### Two-network tests: how to run

The host runs on this PC (home network). The clients run on a second PC on
another network, such as a phone hotspot. Do not host from the hotspot side:
mobile carriers put phones behind CGNAT, so nothing can reach a host there.

1. Host: `bash run_remote.sh pack`. This builds `dist/spike-client.zip` (about
   86 MB, includes Godot). Copy it to the client PC.
2. Host: allow inbound UDP 24680 through Windows Firewall (admin PowerShell):
   `New-NetFirewallRule -DisplayName "dead-signal-spike" -Direction Inbound -Protocol UDP -LocalPort 24680 -Action Allow`
3. Host: `bash run_remote.sh move` (60 s, tests 1, 2, 5) or `drift` (540 s, test 4).
   The server first asks the router for a UPnP mapping of UDP 24680 and prints
   the result and the external IP (test 3). If UPnP fails, forward UDP 24680
   manually to the host's LAN IP. `UPNP=0` skips the attempt. `N` and `TICK`
   set the client count and tick rate.
4. Client PC (PowerShell, in the unzipped folder):
   `.\client.bat <host-external-ip> move` (or `drift`). It needs no Git Bash.
5. The result is written to `results/wan-<test>-t<tick>.json` on the host.

`main.gd` takes `--host=<ip>` (client), plus `--upnp=1` and `--wait=<s>`
(server; the wait extends the hard timeout while clients join).
Probe 2026-10-13 (host network): router answers no UPnP discovery, so the
mapping attempt fails here; manual UDP 24680 forward works, shown by a client on
the host connecting via the public IP (NAT hairpin). Public IP is not CGNAT.
A friend's router without UPnP would need the same manual forward (test 3).
Verified on one LAN on 2026-10-13: 2 clients via `10.0.0.73`, RTT p50 7 ms
(`results/lan-verify-2026-10-13.json`). Not yet run across two networks.
