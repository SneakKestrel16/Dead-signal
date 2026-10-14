# Manual test cases: NA-V, network authority on a real network

> **Runnable since NH-1 (2026-10-14)**: the harness below exists as `tests/manual/net_check.tscn`. Checked on one machine with two to four local instances: join, `version_mismatch`, `bad_name`, `bad_payload`, `round_in_progress` after `L`, `--count=2`, `R` rejoin with the same player IDs, and `--mode=route` (host and client ended at identical server positions, 0 snaps). No token-shaped string appeared in any log. Evidence: `production/qa/evidence/net-harness-1-evidence.md`.
>
> Two harness behaviours to know when reading results:
> - `R` closes the connection before rejoining, so the host prints `player_dropped` and then `player_rejoined` through the grace stub. NAV-14 outcome (ii) without a drop needs a network outage, not `R`.
> - The grace stub admits any known token for 60 s after the latest drop. Mark a grace rejoin "via stub" until NA-3 lands.
> - NAV-08 stays BLOCKED until EX-1 (export preset).

**Scope**: Sprint 1 sign-off condition 1 (`production/sprints/sprint-002.md`, row NA-V). It covers:
- NA-1: `story-001-host-join-auth.md`
- NA-2: `story-002-tokens-reconnect.md`
- NA-6: the two-PC rows of `story-006-snapshots-prediction.md`
- DC-5: AC3 of `production/epics/data-config/story-005-digest-version-check.md`

**Story type**: Integration (documented playtest).

**Evidence**:
- Results go in `prototypes/networking-spike/README.md`, and the ADR-0001 verification rows are updated (qa-plan-sprint-002 NA-V checklist).
- The NA-6 and DC-5 two-PC results are documented in `production/qa/evidence/na-v-<date>.md`, with screenshots or console logs alongside.

**Gate level**: BLOCKING for Sprint 1 condition 1. NA-V itself is a Sprint 2 Should Have.

**Tester**: designer. PC-A is the host and PC-B the client, both on the Tailscale network used in Sprint 1.

## Required harness (to be built before any case runs)

**Files**: `tests/manual/net_check.tscn` + `net_check.gd`, in the same style as `tests/manual/mouse_look_check.tscn`. Arguments come from `OS.get_cmdline_user_args()`.

**Launch**:
```
<godot> --path <repo> res://tests/manual/net_check.tscn -- --role=host [--port=24690] [--local-player=0|1] [--build=0.1.0]
<godot> --path <repo> res://tests/manual/net_check.tscn -- --role=client --host=<ip or [ipv6]> [--port=24690] [--name=<name>] [--count=N] [--raw=oversized|garbage] [--build=0.1.0] [--mode=idle|route|bots]
```

**Both roles must**:
- Load `Knobs.load_all()` and refuse to start if it reports any problem.
- Show and print `knobs.join_version(build)` as `VERSION <string>`.

**The host must**:
- Use a stub lobby provider, `state()` and `player_count()`, like the integration tests.
- On key `L`, cycle the lobby state Waiting → Countdown → In Match.
- Print each `player_joined`, `player_dropped` and `player_rejoined` with its player ID and peer ID.
- Print each reject it sends, with its reason.
- Set `known_token_in_grace` to a stub that returns true for `match_flow.reconnect_grace_s` (60 s) after `player_dropped`, until NA-3 (story 003, status Ready) supplies the real one.

**The client must print**:
- `PLAYER_ID <n>` on success.
- `REJECT <reason>` plus `last_reject_details` (both version strings) on reject.
- The milliseconds from connect to `join_rejected`.
- The ENet RTT (`ENetPacketPeer.get_statistic(PEER_ROUND_TRIP_TIME)`) once per second.
- `--count=N` starts N clients in one process, for `lobby_full`.

**The client must**:
- Keep `local_token` in memory only. Never print, log or display it (control manifest, NA-2).
- On `server_disconnected`, or on key `R`, call `join()` again with the stored token, and print `REJOIN <player_id>`.

**Raw payloads**: `--raw=oversized|garbage` sends a payload over `auth_payload_cap_bytes`, or a non-dictionary, through a raw SceneMultiplayer, as in `host_join_auth_test.gd`.

**NA-6 modes**: `--mode=route` and `--mode=bots` reuse the scripted route and bot movement of `tests/integration/network/prediction_reconcile_test.gd`, with no link simulator. At the end the harness prints:
- the number of corrections and the number of states
- the snap p95 and maximum (m)
- the final server-side position of the host's local player and of the remote client

## Common preconditions (every case)

- Both PCs are on the same commit (`git log -1` hash recorded) with an unmodified `data/knobs/` (`git status` clean), unless the case says otherwise.
- Both PCs have Godot 4.7.2. PC-A's path is in `project.yaml` `engine.path`.
- Tailscale is up on both PCs. Record PC-A's Tailscale IPv4 (100.x) and IPv6 (fd7a:…) addresses. Allow UDP 24690 through the Windows firewall on PC-A.
- Knobs as shipped: `net.port` 24690, `reject_close_delay_s` 0.2, `auth_timeout_s` 3.0, `max_clients_headroom` 2, `lobby.max_players` 6, `match_flow.reconnect_grace_s` 60.
- **Any knob edit changes the digest.** Change a knob on both PCs, or the case turns into a `version_mismatch` test.

---

## (a) NA-1: host, join and auth across two machines

### Test Case: NAV-01: A valid join over LAN or Tailscale gets a player ID

**Preconditions**: common preconditions.

**Steps**:
1. On PC-A, start the host with `--role=host --local-player=0`. Record the VERSION line.
2. On PC-B, start the client with `--role=client --host=<PC-A Tailscale IPv4> --name=Tester`. Record the VERSION line.
3. Wait 5 s.

**Expected Result**:
- PC-B prints `PLAYER_ID <n>` with n ≥ 0.
- PC-A prints `player_joined <n>` with the same n.
- Both VERSION lines are identical.

**Pass Criteria**: PASS if both IDs match and are printed within 5 s.

**Actual Result**:
**Pass/Fail**:

### Test Case: NAV-02: `version_mismatch` shows both version strings

**Preconditions**: common preconditions. The host is running on PC-A.

**Steps**:
1. On PC-B, run the client with `--build=0.0.9`.
2. Record PC-B's REJECT line and `last_reject_details`.
3. Repeat 10 times.

**Expected Result**:
- `REJECT version_mismatch` every time.
- The details hold PC-A's string and PC-B's string, and the two differ.

**Pass Criteria**: PASS if the reason arrives in 10 of 10 attempts and both strings are present each time.

**Actual Result**:
**Pass/Fail**:

### Test Case: NAV-03: `lobby_full` at the cap

**Preconditions**: the host runs on PC-A with `--local-player=0`, so the cap is 6 remote players.

**Steps**:
1. On PC-B, run `--count=6`. Confirm 6 `PLAYER_ID` lines.
2. On PC-B, start one more client with `--count=1`.
3. Repeat Step 2 10 times.

**Expected Result**:
- The 7th client gets `REJECT lobby_full` every time.
- The 6 admitted clients stay connected, and PC-A prints no `player_dropped`.

**Pass Criteria**: PASS if 10 of 10 attempts show `lobby_full` and there are 0 drops among the six.

**Actual Result**:
**Pass/Fail**:

### Test Case: NAV-04: `round_in_progress`, `bad_name` and `bad_payload` over the network

**Preconditions**: the host is running on PC-A in the Waiting state.

**Steps**:
1. On PC-A, press `L` until the host prints In Match. On PC-B, join with a new process (so no token). Repeat 10 times.
2. On PC-A, press `L` to cycle back to Waiting. On PC-B, join with `--name=` (empty), then with `--name=ABCDEFGHIJKLMNOPQ` (17 characters). Repeat each 10 times.
3. On PC-B, join with `--raw=oversized`, then with `--raw=garbage`. Repeat each 10 times.

**Expected Result**:
- Step 1: `round_in_progress`.
- Step 2: `bad_name`.
- Step 3: `bad_payload`, and the host log shows no decode of objects.

**Pass Criteria**: PASS if every reason arrives in 10 of 10 attempts.

**Actual Result**:
**Pass/Fail**:

### Test Case: NAV-05: Reject delay under real latency, 0.2 s and 0 s (settles AD-64)

**Preconditions**: the host is running on PC-A. Record the RTT the client prints.

**Steps**:
1. With `reject_close_delay_s` 0.2, run NAV-02 10 times. Record how many attempts showed the reason, and the connect-to-reject time.
2. On BOTH PCs, set `reject_close_delay_s = 0.0` in `data/knobs/net.tres` (both, so the digests still match).
3. Restart the host. Repeat Step 1 using `--build=0.0.9` (10 attempts).
4. Revert `net.tres` on both PCs (`git checkout data/knobs/net.tres`).

**Expected Result**:
- Step 1: the reason arrives in 10 of 10 attempts.
- Step 3: record the count only. The single-machine finding was 20 of 20 with a 0 s delay, because the timer waits one frame. This step settles whether real latency changes that.

**Pass Criteria**:
- PASS if Step 1 is 10 of 10.
- Step 3 is a measurement, not a pass/fail: record N of 10 and the RTT in the README and in the ADR-0001 verification row.

**Actual Result**:
**Pass/Fail**:

### Test Case: NAV-06: IPv6 join over Tailscale

**Preconditions**: NAV-01 has passed.

**Steps**:
1. On PC-B, join with `--host=[<PC-A Tailscale IPv6>]`.

**Expected Result**: `PLAYER_ID` is printed.

**Pass Criteria**: PASS if a player ID is received within 5 s.

**Note**: this exercises ENet's IPv6 bind and connect over the tunnel's ULA address, not native internet IPv6. Record it that way.

**Actual Result**:
**Pass/Fail**:

### Test Case: NAV-07: WAN without Tailscale (port forward, NAT) (SKIPPED by designer decision 2026-10-13)

Players connect over Tailscale. The NAT and raw-WAN rows are skipped (`sprint-002.md` NA-V row). This case is kept so the skip is on record. Mark it N/A and do not run it.

**Actual Result**: N/A
**Pass/Fail**: N/A

### Test Case: NAV-08: An exported headless server accepts a join (BLOCKED: no export preset, TD-004)

**Preconditions**:
- `export_presets.cfg` exists. It does not today, and `commands.build` is unset.
- A Windows export of the harness exists.

**Steps**:
1. On PC-A, run the exported binary with `--headless -- --role=host --local-player=0`.
2. On PC-B, join as in NAV-01.

**Expected Result**: `PLAYER_ID` is printed. The exported server's VERSION line equals the editor run's VERSION line. This also covers DC-5 AC1's "exported binary gives the same digest".

**Pass Criteria**: PASS if the join succeeds and the VERSION strings are identical.

**Actual Result**:
**Pass/Fail**:

---

## (b) NA-6: two-PC rows (story-006 Test Evidence: "two-PC results documented in `production/qa/evidence/`")

### Test Case: NAV-09: Host's local player and remote client run the same route to identical server positions

**Preconditions**:
- The host is running on PC-A with `--local-player=1`.
- PC-B is ready to run `--mode=route`.

**Steps**:
1. On PC-B, run `--mode=route`. The host's local player runs the same route.
2. When it finishes, record both final server-side positions and the RTT.
3. Repeat 3 times.

**Expected Result**: on every run, the two final positions agree within 0.001 m in x and z (`HORIZONTAL_TOLERANCE_M`) and within 2 × safe_margin in y, as in AC3 of the integration test.

**Pass Criteria**: PASS if 3 of 3 runs are within tolerance.

**Actual Result**:
**Pass/Fail**:

### Test Case: NAV-10: Corrections and snaps under real latency

**Preconditions**: the host is running on PC-A with `--local-player=0`.

**Steps**:
1. On PC-B, run `--mode=bots --count=5` for at least 1600 ticks (about 27 s).
2. Record the corrections, states, snap p95 and maximum, RTT p50, and the host's upload rate (from Task Manager or the harness).

**Expected Result**:
- Corrections ≤ 53 per 5022 states, and snap p95 < 0.35 m (story-006 AC1 budget).
- Host upload is about 87 kbps per client at 60 Hz (guardrail).

**Pass Criteria**: PASS if both AC1 budget values hold. Upload is recorded, not gated.

**Actual Result**:
**Pass/Fail**:

### Test Case: NAV-11: Clean route over step and ramp, and cross-machine Jolt drift (ADR-0002 verification 5)

**Preconditions**: as NAV-09, on the step and ramp route from the integration test.

**Steps**:
1. Run `--mode=route` from PC-B 3 times.
2. Record the snaps and the largest correction.

**Expected Result**:
- 0 snaps.
- Smooth corrections under 0.01 m (the clean-link test tolerance).
- Any larger value is cross-machine drift. Record its size.

**Pass Criteria**: PASS if there are 0 snaps on 3 of 3 runs. The drift values go into the ADR verification row either way.

**Actual Result**:
**Pass/Fail**:

---

## (c) DC-5: cross-machine digest

### Test Case: NAV-12: Same build gives the same join version on both PCs

**Preconditions**: common preconditions. Both PCs are on the same commit with clean knobs.

**Steps**:
1. Start the harness on PC-A and PC-B. Record each VERSION line.
2. Join PC-B to PC-A (NAV-01).

**Expected Result**:
- Both strings match `0.1.0+` followed by exactly 8 lowercase hex characters, and they are identical.
- The join succeeds.

**Pass Criteria**: PASS if the strings are byte-identical and `PLAYER_ID` is printed.

**Actual Result**:
**Pass/Fail**:

### Test Case: NAV-13: One knob changed on one PC is rejected with both versions

**Preconditions**: NAV-12 has passed.

**Steps**:
1. On PC-B only, change `walk_speed = 4.0` to `walk_speed = 4.1` in `data/knobs/controller.tres`. This is inside its range of 3.7–4.5, so the harness still loads with 0 problems.
2. Start the PC-B client. Record its VERSION line.
3. Join PC-A.
4. Revert the change (`git checkout data/knobs/controller.tres`). Rejoin.

**Expected Result**:
- Step 2: PC-B's suffix differs from PC-A's.
- Step 3: `REJECT version_mismatch`, with both strings in the details.
- Step 4: the join succeeds.

**Pass Criteria**: PASS if the reject happens with both differing strings shown, and the join succeeds after the revert.

**Actual Result**:
**Pass/Fail**:

---

## (d) NA-2: reconnect after a brief network loss

ENet keeps a peer through short outages; its default peer timeout is about 5–30 s. That figure is an inference from ENet's defaults; settle it by measuring in NAV-14. A short pull may therefore never cause a reconnect at all, and the cases record which path was taken.

### Test Case: NAV-14: A short outage within the ENet timeout keeps the same connection

**Preconditions**: PC-B has joined PC-A (NAV-01). Record the player ID and peer ID.

**Steps**:
1. On PC-B, disable Wi-Fi or pull the cable for 3 s, then restore it.
2. Wait 15 s, so Tailscale can re-establish.
3. Record the host and client logs.

**Expected Result**: one of two outcomes.
- (i) No `player_dropped` and no `REJOIN`, with the same peer ID. The connection survived.
- (ii) PC-B prints `REJOIN <same player_id>`, and PC-A prints `player_rejoined <same id> <new peer>` with no `player_dropped` for a still-bound peer.

**Pass Criteria**: PASS if the player ID after the outage equals the one before, in either outcome. FAIL if PC-B gets a new player ID or a reject. Record which outcome occurred.

**Actual Result**:
**Pass/Fail**:

### Test Case: NAV-15: A longer outage leads to a reconnect within grace with the same player ID (grace via the harness stub until NA-3)

**Preconditions**:
- As NAV-14.
- The host is in the In Match state (press `L`), so an unknown token would be rejected.

**Steps**:
1. On PC-B, take the network down. Keep it down until PC-B prints `server_disconnected` or 40 s pass.
2. Restore the network within 60 s of the start (`reconnect_grace_s`).
3. Let the harness rejoin automatically, or press `R`.
4. Record the logs and the time from restore to `REJOIN`.

**Expected Result**:
- PC-B prints `REJOIN <same player_id>`, and PC-A prints `player_rejoined`.
- If PC-A had printed `player_dropped` first, the rejoin is admitted only through the grace stub. Mark this result "via stub", because NA-3 (story 003) is not built.
- The token never appears in any log on either PC.

**Pass Criteria**: PASS if the player ID is unchanged, there is no `round_in_progress` reject, and a search of both logs for the token prefix finds nothing.

**Actual Result**:
**Pass/Fail**:

### Test Case: NAV-16: Reconnect after grace is rejected (grace via the harness stub until NA-3)

**Preconditions**: as NAV-15.

**Steps**:
1. Take PC-B's network down for 75 s, which is longer than the 60 s grace and long enough for PC-A to print `player_dropped`.
2. Restore the network and let the harness rejoin.

**Expected Result**: `REJECT round_in_progress`.

**Pass Criteria**: PASS if `round_in_progress` is shown and PC-A prints no `player_rejoined`.

**Actual Result**:
**Pass/Fail**:
