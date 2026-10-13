# ADR-0001: Hosting Model, Session, Join Auth and Reconnect

## Status
Proposed

## Date
2026-10-12

## Last Verified
2026-10-12

## Decision Makers
SneakKestrel16 (designer), with `godot-specialist` engine validation. TD-ADR skipped — Lean mode.

## Summary
Dead Signal needs a hosting topology, a join path that validates players before they enter the lobby, and a way for a dropped player to reclaim their seat. The decision: a listen server over direct ENet for MVP, with the server role kept separate from the host's local player so a headless dedicated build stays possible; joins are validated in `SceneMultiplayer.auth_callback`; a server-issued session token rebinds a reconnecting player to their stable player ID, evicting any stale peer.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Networking |
| **Knowledge Risk** | HIGH (post-cutoff version). `modules/networking.md` is a 4.6 snapshot; the 4.7 migration guide lists no multiplayer changes |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/networking.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`; `prototypes/networking-spike/README.md` and `main.gd` (run on 4.7.2) |
| **Post-Cutoff APIs Used** | None introduced after 4.3. All APIs below exist in the 4.6 reference or were exercised by the spike on 4.7.2 |
| **Verification Required** | (1) ENet dead-peer timeout defaults and `ENetPacketPeer.set_timeout` behaviour on 4.7.2 (training data only). (2) `SceneMultiplayer.auth_timeout` default and scope (training data only). (3) `SceneMultiplayer.server_relay` default (training data says `true`; this ADR sets `false` regardless). (4) `Crypto.generate_random_bytes` (training data only). (5) `create_server` bind address and IPv6 behaviour. (6) Whether a reject reason survives a back-to-back `send_auth` + `disconnect_peer` (the spike delays 0.2 s; untested without the delay) |

**API coverage.** In the reference: `ENetMultiplayerPeer.create_server` / `create_client`, `SceneMultiplayer.auth_callback`, `server_relay`, `peer_connected` / `peer_disconnected`. Verified only by the spike on 4.7.2: `send_auth`, `complete_auth`, `peer_authenticating`, `disconnect_peer`, `var_to_bytes` / `bytes_to_var`, token rebinding. Training data only: the items under Verification Required.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002 (authoritative simulation, tick and input handling), ADR-0004 (replication scope and information hiding) |
| **Blocks** | Lobby & Role Assignment implementation; Match Flow disconnect and reconnect rules (19–22); any multiplayer story |
| **Ordering Note** | May be drafted now. Acceptance waits on the networking spike's deferred real-network tests (WAN latency, home upload, NAT reachability, clock drift, Wi-Fi), which need a second PC on another network |

## Context

### Problem Statement
Every gameplay rule in the GDDs assumes a server that owns the truth, but no document says which process is that server, how players reach it, how it refuses bad joins, or how a dropped player gets their seat back. Lobby & Role Assignment rule 1 defers dedicated-server support to this ADR, and Match Flow rules 19–21 need a reconnect mechanism that survives a new peer ID. This must be settled before any multiplayer code is written.

### Constraints
- Small, shippable scope (Pillar 5): no matchmaking, no accounts, no paid infrastructure for MVP.
- 4–6 players, one shapeshifter (`lobby-role-assignment.md` rules 1–4).
- Server authority for every rule (systems index, architecture principle 1).
- One developer; PC first.

### Requirements
- Host a lobby on a configurable port; others join by address and port (lobby rule 1).
- Reject a join with a reason when the lobby is full, a round is in progress (except a valid reconnect), or the version differs (lobby rule 2).
- Enforce display names of 1–16 characters, unique case-insensitively with suffixes (lobby rule 3).
- Remove a non-host lobby leaver at once (lobby rule 18); close the session for everyone when the host leaves (lobby rule 19, Match Flow "Host leaves").
- Restore a disconnected player's seat, state and queue position within `reconnect_grace_s` = 60 (Match Flow rules 19–20; AC-LB-03, AC-LB-18).

## Decision

**1. Topology: listen server for MVP, with a separable server role.** The host's process runs the authoritative server and a local client. The local client is the player on peer 1 and submits intent through the same queue as remote players; the server never reads the host's input directly. The server role must start and run with no local player, so a headless dedicated build stays possible later without restructuring. Dedicated hosting is not built for MVP.

**2. Transport: ENet, direct IP.** The host calls `ENetMultiplayerPeer.create_server(port, max_clients)` on a data-configured port; clients call `create_client(address, port)`. ENet `max_clients` is set above `max_players` so a reconnect can arrive while the stale peer still exists; `auth_callback` enforces the real cap. `SceneMultiplayer.server_relay` is set to `false`, so clients never reach each other. If `create_server` returns an error (for example, the port is in use), the host UI shows it and nothing is left half-initialised. NAT traversal is the host forwarding the port; UPnP or a relay waits for the real-network tests.

**3. Join validation in `auth_callback`, on both sides.**
- **Client** sends `var_to_bytes({"version": String, "display_name": String, "token": String})` with `send_auth(1, ...)`. On a first join `token` is `""`. `version` is `"<build_version>+<first 8 hex of Knobs.digest()>"`, so a knob mismatch is a `version_mismatch` (amended by ADR-0006). Its own auth callback reads the server's reply: on `ok` it stores the token and calls `complete_auth(1)`; on a reject it shows the reason. A rejected client never sees `connected_to_server`, so the auth reply is the only place the reason arrives.
- **Server** checks the payload size against a data cap before decoding, decodes with `bytes_to_var` (never `bytes_to_var_with_objects`), and type-checks every field. It then validates, in order: exact version match; `display_name` length 1–16 after stripping control and bidirectional-override characters; lobby state (Waiting accepts new joins; Countdown and In Match accept only a known token inside its grace); the `max_players` cap. On success it replies `{ok: true, player_id, token}` and calls `complete_auth`. On failure it replies `{ok: false, reason}` and calls `disconnect_peer` after `reject_close_delay_s` (0.2 s, the spike's value).
- `auth_timeout` is set from data.

**4. Session token and player identity.** On a first join the server issues a token of 16 random bytes, hex-encoded. It is sent only to its owner, held in client memory for the session, and never broadcast. The token maps to a stable, server-assigned **player ID**. All gameplay and lobby state (roster, rotation queue, preferences, life state, carried items) is keyed by player ID, never by peer ID. Peer IDs are transport addresses only.

**5. Reconnect rebinding, with eviction.** A join carrying a known token inside its grace rebinds that player ID to the new peer ID. If the old peer is still connected, the server evicts it with `disconnect_peer(old)` first, and the old peer's `peer_disconnected` must not raise a "dropped" notification for a player who has already rejoined. After rebinding, the server re-applies every per-peer visibility rule for that player (`MultiplayerSynchronizer.set_visibility_for` takes peer IDs) and sends a full state snapshot and spawn set to the new peer.

**6. Disconnect detection and routing.** Dead peers are detected by the ENet timeout, configured per peer with `ENetPacketPeer.set_timeout` from data: on the server in `peer_connected`, on the client after connecting. On `peer_disconnected`, Network looks up the player ID and notifies the owner of that phase: Lobby removes the player at once in Waiting and Countdown (lobby rule 18); Match Flow starts `reconnect_grace_s` and emits `PlayerConnectionChanged` in a round (Match Flow rules 19–22). The grace clock starts at detection, so real time from drop to forfeit is the ENet timeout plus 60 s.

**7. Host leaves.** Clients receive `multiplayer.server_disconnected`, return to the main menu with "Host left", and record no result. There is no host migration (lobby rule 19).

### Architecture Diagram

```
 Host process                                      Remote client
┌──────────────────────────────────────┐          ┌──────────────────────┐
│ Server role (authoritative)          │          │ Client role          │
│  NetAuthority ── auth_callback       │◀──ENet──▶│  NetAuthority        │
│   token → player_id map              │  direct  │   token (memory)     │
│   peer_id ⇄ player_id binding        │  IP:port │                      │
│  Lobby / Match Flow (by player_id)   │          │  Presentation        │
├──────────────────────────────────────┤          └──────────────────────┘
│ Local client role (peer 1)           │
│  intent ─▶ same queue as remotes     │
└──────────────────────────────────────┘
 The server role must also run alone (headless) — dedicated build is a later option.
```

### Key Interfaces

```gdscript
class_name NetAuthority extends Node

signal player_joined(player_id: int)
signal player_dropped(player_id: int)                    # not raised for an evicted stale peer
signal player_rejoined(player_id: int, new_peer_id: int)
signal join_rejected(reason: StringName)                 # client side
signal host_failed(error: Error)                         # create_server failed

func host(port: int) -> Error
func join(address: String, port: int, display_name: String) -> Error
func player_id_of(peer_id: int) -> int                   # -1 if unbound
func peer_id_of(player_id: int) -> int                   # -1 if disconnected
```

Reject reasons are `StringName` codes (`&"lobby_full"`, `&"round_in_progress"`, `&"version_mismatch"`, `&"bad_name"`, `&"bad_payload"`). The UI maps each to the player-facing text in `lobby-role-assignment.md` (AC-LB-03); for `version_mismatch` the reply also carries both version strings.

### Implementation Guidelines
- Gameplay and lobby state **must** be keyed by player ID. Code **must never** store a peer ID as identity outside `NetAuthority`.
- The server **must** decode auth payloads with `bytes_to_var`, **must never** use `bytes_to_var_with_objects`, and **must** check size and field types before use.
- The host's local player **must** submit intent through the same path as remote players.
- The server role **must** run with no local player.
- `server_relay` **must** be `false`.
- On rebind, the server **must** re-apply per-peer visibility and send a full snapshot before any delta.
- A token **must never** be sent to any peer but its owner, logged in telemetry or shown in UI.
- Port, `max_clients` headroom, `auth_timeout`, ENet timeout, `reject_close_delay_s` and the payload cap **must** come from data, not literals.

## Alternatives Considered

### Alternative 1: Listen server only, with no separable server role
- **Description**: Host process is server and player, with server code free to reach the host's player directly.
- **Pros**: Least code; fastest first build.
- **Cons**: Host shortcuts leak into rules; a dedicated server later means a rewrite.
- **Rejection Reason**: Keeping the role separable costs little now (the spike already ran a headless server) and keeps fairness rules honest.

### Alternative 2: Dedicated server only
- **Description**: A headless server process hosts every match; all players are remote clients.
- **Pros**: No host advantage; host leaving no longer ends the match.
- **Cons**: Needs hosting infrastructure and cost; dedicated-server export is not covered by the engine reference.
- **Rejection Reason**: Pillar 5. Revisit after the first map and round are fun.

### Alternative 3: Platform relay networking (for example, Steam)
- **Description**: Join through a platform service with built-in NAT traversal.
- **Pros**: No port forwarding.
- **Cons**: New dependency and platform lock-in; outside the engine reference.
- **Rejection Reason**: Deferred until the real-network tests show whether port forwarding is a real barrier.

### Alternative 4 (sub-decision): Reject a reconnect while the old peer lives
- **Description**: Refuse with `token_in_use` until ENet times out the stale peer (the spike's behaviour).
- **Pros**: A stolen token cannot kick the real player.
- **Cons**: The player waits out the ENet timeout inside their grace.
- **Rejection Reason**: Designer decision 2026-10-12: the valid token evicts the old peer; the hijack risk is recorded below.

## Consequences

### Positive
- No servers to run or pay for in MVP.
- The same server code can later run headless.
- Reconnect survives a new peer ID by design, matching Match Flow rules 19–20.
- Join failures always carry a reason the UI can show.

### Negative
- The host has zero latency to the server; remote players do not.
- The host leaving ends the session for everyone.
- Players behind NAT need the host to forward a port until a traversal option exists.
- Real time from a drop to a forfeit is the ENet timeout plus 60 s.

## Risks
- **Token hijack.** ENet traffic is not encrypted, so anyone who can sniff the path can take a token and, under the eviction rule, kick the real player. Accepted for MVP (friends' sessions, direct IP). Mitigation later: DTLS or a per-round secret.
- **NAT reachability.** Port forwarding may block casual groups. Mitigation: the deferred reachability test decides whether UPnP or a relay is needed before Alpha.
- **ENet timeout defaults.** Unverified; a long default delays grace. Mitigation: set the timeout explicitly from data and verify on 4.7.2.
- **Lost reject reason.** A disconnect too soon after `send_auth` may drop the reason. Mitigation: the 0.2 s delay, verified in a test.
- **4.7 networking unverified by docs.** Mitigation: the spike ran on 4.7.2; refresh `modules/networking.md` for 4.7.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| lobby-role-assignment.md | Rule 1: host on a configurable port, join by address and port; dedicated server deferred here | Decision 1–2: listen server, direct ENet, data-configured port; dedicated kept possible, not built |
| lobby-role-assignment.md | Rule 2 / AC-LB-03: reject full lobby, round in progress (except valid reconnect) and version mismatch with a reason | Decision 3: ordered checks in `auth_callback`, reason codes, both versions on mismatch |
| lobby-role-assignment.md | Rule 3 / AC-LB-04: names 1–16 characters | Decision 3: length check after sanitising; uniqueness suffixing stays in Lobby |
| lobby-role-assignment.md | Rule 18 / AC-LB-28: non-host lobby leaver removed at once | Decision 6: Network routes the disconnect to Lobby, which removes the player on that tick |
| lobby-role-assignment.md | Rule 19 / AC-LB-29: host leaving closes the session, no result | Decision 7 |
| lobby-role-assignment.md | AC-LB-18: same token under a new peer ID keeps queue position | Decisions 4–5: state keyed by player ID; token rebinds the new peer |
| match-flow.md | Rules 19–21: 60 s grace, same state on reconnect, forfeit or elimination on expiry | Decisions 5–6: rebind plus full snapshot; Match Flow owns grace and emits `PlayerConnectionChanged` |
| match-flow.md | Rule 22: every disconnect and reconnect logged | Decision 6: Network notifies the phase owner by player ID; tokens are never logged |
| match-flow.md | Host leaves: session closes, no result, no forfeit | Decision 7 |
| systems-index.md | `PlayerConnectionChanged` emitted by Match Flow | Decision 6 keeps Match Flow as the emitter; Network only notifies it |

## Performance Implications
- **CPU**: Negligible. Auth runs once per join.
- **Memory**: One token and player-ID map entry per player per session.
- **Load Time**: None.
- **Network**: Auth is a single round trip per join. A full snapshot on rebind is a one-off burst per reconnect. Steady-state bandwidth is ADR-0002's concern (spike: about 87 kbps host upload per client at 60 Hz).

## Migration Plan
No production code exists. The spike (`prototypes/networking-spike/`) is reference only and is rewritten, not imported (`.claude/rules/prototype-code.md`).

## Validation Criteria
- AC-LB-02, AC-LB-03, AC-LB-04, AC-LB-18, AC-LB-28 and AC-LB-29 pass.
- Match Flow's reconnect criteria pass: a survivor back within 60 s has the same position, state and down count; a shapeshifter back within grace returns in true form.
- An integration test reconnects a player while the old peer is still connected: the old peer is evicted, no "dropped" notification fires, visibility-filtered entities reappear on the new peer, and the queue position is unchanged.
- A rejected client shows the reason text in at least 20 of 20 attempts with the 0.2 s delay.
- A packet capture on a non-owner client contains no other player's token.
- Real-network tests (spike's deferred list) run before this ADR is Accepted.

## Related
- `docs/architecture/architecture.md` — Required ADR 1; principles 1 and 4
- `design/gdd/lobby-role-assignment.md`, `design/gdd/match-flow.md`, `design/gdd/systems-index.md`
- `prototypes/networking-spike/README.md` (H5)
- Enables ADR-0002 and ADR-0004 (not yet written)
