# ADR-0004: Replication Scope and Information Hiding

## Status
Proposed

## Date
2026-10-12

## Last Verified
2026-10-12

## Decision Makers
SneakKestrel16 (designer), with `godot-specialist` engine validation. TD-ADR skipped — Lean mode.

## Summary
The GDDs require that no client learns what its player could not perceive, and above all that a survivor client cannot tell which in-world body is the shapeshifter. The decision: player bodies reach each peer only through ADR-0002's per-peer snapshots, filtered by an authored room PVS and named by per-peer opaque handles that are re-issued whenever a body re-enters a peer's relevance; every client-bound event is projected per recipient; sounds travel as positional events with no body reference; and non-body hidden entities use `MultiplayerSynchronizer` per-peer visibility.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 |
| **Domain** | Networking |
| **Knowledge Risk** | HIGH (post-cutoff version; `modules/networking.md` is a 4.6 snapshot; the 4.7 migration guide lists no multiplayer changes) |
| **References Consulted** | `docs/engine-reference/godot/modules/networking.md`, `breaking-changes.md`, `deprecated-apis.md`; `prototypes/networking-spike/README.md` (H4) and `main.gd` |
| **Post-Cutoff APIs Used** | None introduced after 4.3 |
| **Verification Required** | (1) **Blocking for acceptance:** a spike case that spawns a hidden entity through `MultiplayerSpawner` and confirms a never-granted peer receives neither the node nor any traffic for it. (2) `set_visibility_for` on a node not yet spawned for that peer. (3) `MultiplayerSynchronizer.add_visibility_filter` and `update_visibility` timing (training data only). (4) Snapshot size with real body state against the estimate below. (5) A packet capture of the first RPC to each fixed-name node shows no player or peer ID in any node path |

**API coverage.** In the repo reference: `rpc_id`, `@rpc` modes, `SceneMultiplayer.server_relay`. Spike-verified on 4.7.2: `MultiplayerSynchronizer.public_visibility = false`, `set_visibility_for` grant and revoke (revoke despawns on that peer), `update_visibility`, `MultiplayerSpawner.spawn_function` / `spawn_path` / `spawn()`. Training data only: `add_visibility_filter`, spawner-level visibility rules, exact `update_visibility` timing.

**Verification results (2026-10-12, single machine, [`prototypes/adr-verification/README.md`](../../prototypes/adr-verification/README.md)).** (1) **PASS**: a hidden spawn granted to one client only never reaches the other (no node, no `spawned` signal, idle-level traffic while the entity moves). (2) PASS: `set_visibility_for` right after `spawn()` in the same frame delivers. (3) filters re-run every frame by default; a flipped filter takes effect in 1 frame. (4) see ADR-0002 (6). (5) the first RPC to a node named `Player_4242` carries that name in clear, confirming Decision 7a.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Proposed): player IDs, `server_relay = false`, reconnect rebind. ADR-0002 (Proposed): custom per-peer snapshots, TickRunner send phase, reliable event channel |
| **Enables** | ADR-0005 (event catalog): every catalog event declares its projection. Should-have ADRs on Borrowed Face rendering, objective discovery and scare scoping |
| **Blocks** | Borrowed Face, Survivor Defense presentation, Scare Events delivery, Survivor Objectives discovery, Pings & Callouts delivery, spectator view |
| **Ordering Note** | Acceptance waits on Verification Required item 1 and on the Facility Map visibility table (`design/levels/research-facility.md`, Visibility Sets) |

## Context

### Problem Statement
Roles are public: the lobby shows the rotation queue and results name the shapeshifter (`lobby-role-assignment.md` rule 11). What must stay secret is **which body in the world is the monster**. `borrowed-face.md` names two leaks: `FormChanged` names the shapeshifter, and the Transforming flag sits on its entity. Beyond those, a stable network ID for the monster's body would let a modified client follow it through every disguise. The GDDs add more per-role secrets, each with a packet-capture acceptance criterion: identical shock payloads (`survivor-defense.md`), no `AbilityUsed` on survivor clients (`monster-abilities.md`), no source or identity in scares (`scare-events.md`), no undiscovered objective points (`survivor-objectives.md`), no bleed-out state on the monster's client (`downing-and-rescue.md`), and no real/fake field in callouts (`pings-and-callouts.md`).

### Constraints
- ADR-0002 already replicates player movement through custom per-peer snapshots, so bodies need no `MultiplayerSpawner`.
- 17 lighting volumes, about 26 doors, glass partitions (`research-facility.md`).
- One developer: relevance must be cheap and data-driven.

### Requirements
- A client receives only what its player could perceive.
- A survivor client can never link a body to the shapeshifter except by what its player saw.
- Every GDD packet-capture criterion above passes.
- Spectators receive exactly what the survivor they watch receives (`pings-and-callouts.md`).
- A reconnecting client is rebuilt to current state with no extra knowledge.

## Decision

**1. Principle.** A client receives only what its player could perceive. No client-bound payload during a round contains the shapeshifter's player ID or anything that links a body to it. The source peer of every packet is the server (`server_relay = false`, ADR-0001), so transport metadata carries no identity.

**2. Bodies through snapshots only.** Player bodies are never spawned by `MultiplayerSpawner` or replicated by `MultiplayerSynchronizer`. Each client builds local puppet nodes from ADR-0002's per-peer snapshot.

A body entry in a snapshot carries:
- handle, appearance (survivor character or true form), position (quantized), yaw and gait;
- presentation state: Seized, Downed, stagger, Transforming warp, flashlight on;
- visible carried items, following Borrowed Face's rules (a disguise shows no drive or fuse).

**3. Per-peer opaque handles.**
- **Issue.** The server issues each body a random 32-bit handle per peer, rejecting duplicates for that peer; 0 is reserved.
- **Introduce and retire.** A reliable *introduce* message on the event channel precedes any event or snapshot use of a new handle. A reliable *retire* message ends it. The client ignores snapshot entries whose handle has not been introduced.
- **Re-entry.** When a body leaves a peer's relevance and later re-enters, it gets a fresh handle.
- **Form change in view.** A form change while the body is relevant keeps the handle and updates its appearance: the player saw it happen.
- **Form change during linger.** A form change, or the start of a transformation, while the body is only lingering (rule 4) ends the linger and retires the handle at once.

**4. Relevance: authored room PVS.**
- **Visibility sets.** The Facility Map authors, for each lighting volume, its visible-volume set: itself, volumes seen through open doorways and archways, and volumes seen through glass.
- **Relevance test.** A body is relevant to a viewer if its volume is in the viewer's volume's set, or it is within `relevance_near_m` = 6 m.
- **Linger.** A body stays relevant for `relevance_linger_s` = 0.5 after it stops qualifying.
- **Doors.** A door that is closed or barricaded removes the volumes behind it from the set.
- **Map state.** Door and barricade state is replicated under the same rule, with current state re-sent on re-entry. Lighting state follows the same rule (amended by ADR-0009).
- **Surveillance.** While a peer views a surveillance camera, its relevance set also includes that camera's authored visibility set (amended by ADR-0009).
- **Timing.** Relevance is computed in the TickRunner send phase.
- **Hidden survivors.** They are never relevant to the monster's client. Their relevance to other survivors follows Survivor Defense's occupancy rules.

**5. Event projection.** Each event's emitter supplies `project(event, peer) -> Dictionary`, where `{}` means the peer receives nothing (signature amended by ADR-0005; was `Dictionary or null`). Network batches the tick's projected events into one reliable message per peer, on the event channel. Client-facing payloads refer to bodies by that peer's handle and to players by player ID only for public facts: names, roster, survivors' life states, escapes, connections, results.

| Event | Survivor clients (and their spectators) | Shapeshifter client |
|---|---|---|
| `RoundPhaseChanged`, `RoundEnded`, `SurvivorEscaped`, `PlayerConnectionChanged` | Full | Full |
| `SurvivorDowned`, `SurvivorRescued`, `SurvivorEliminated` | Survivor player ID and life state; bleed-out state to survivors only | Same, never bleed-out state |
| `SurvivorHit`, `AbilityUsed`, `FormChanged` | Never sent; effects appear as body presentation on relevant handles | `FormChanged`: own form only |
| `MonsterStunned` | Only while the monster is in true form, by handle, if relevant | Own stun |
| `PlayerShocked` | `{handle}` only, identical for every case; if relevant | Same rule |
| `ObjectiveProgressChanged` | Undiscovered drive rooms and fuse spawns omitted | All active points |
| `ScareTriggered` | Recipients only; `source` and player identity stripped | Recipients only |
| `BarricadeBroken` | Door state under the PVS rule; break sound as a positional event | Same |

**6. Sounds.** Footsteps, the transformation distortion, lunge cues, barricade bangs and callouts are positional audio events: position, sound or voice set, and no handle. They go to peers within the sound's radius. A disguised monster's footsteps use the target's footstep set (Borrowed Face). The callout's displayed identity follows `pings-and-callouts.md`.

**7. Non-body hidden entities.** Undiscovered drive rooms and fuse spawns, single-client hallucinations and monster-only markers are spawned through `MultiplayerSpawner` with a `MultiplayerSynchronizer` whose `public_visibility` is `false`. They are granted per peer with `set_visibility_for(peer, true)`. Spawned node names are opaque counters (`E%d`), and spawn payloads carry no identity.

Spawn order (amended after the 2026-10-12 architecture review): the `spawn_function` returns the node with its synchronizer's `public_visibility = false` already set, and the server calls `set_visibility_for` for each granted peer right after `spawn()`, in the same frame, before the next network poll. Whether that order keeps a never-granted peer from receiving the spawn is what Verification Required item 1 tests; until it passes, this decision is not acceptable.

**7a. RPC paths.** The first RPC to a node sends its node path to the peer, so a node name is a payload. Every per-peer RPC (introduce, retire, event batches, snapshots, positional sounds) targets one fixed-name node on the round-server root. Client puppet nodes carry no RPCs and are named by a client-local counter, never by player ID, peer ID or handle. No node anywhere is named after a player or peer ID during a round. (`godot-specialist`, 2026-10-12 review; path-on-first-RPC is NOT SOURCEABLE from `modules/networking.md`, so Verification Required item 5 checks it.)

**8. Spectators.** An Eliminated or Escaped player's client receives the stream projected for the survivor it watches. Switching the watched survivor discards the spectator's puppet map; every handle is re-issued and a full snapshot is sent.

**9. Reconnect.** On ADR-0001's rebind, the client discards its puppet map. The server re-issues every handle for the new peer, re-applies `set_visibility_for` for the new peer ID, and sends a full snapshot before any delta.

### Architecture Diagram

```
SERVER send phase, per peer P
  viewer volume V = volume of P's body (or watched survivor's, for spectators)
  relevant = { bodies in PVS(V) or within 6 m } + linger 0.5 s
  for each relevant body: handle = handles[P][body]  (introduce if new)
  for each body leaving relevance: retire handle (after linger)
  snapshot(P) = [ {handle, appearance, pos, yaw, gait, presentation} ... ]
  events(P)   = [ project(e, P) for e in tick_events if not null ]   (reliable, batched)
  sounds(P)   = [ positional events within radius ]

CLIENT
  introduce/retire (reliable) ─▶ puppet map {handle → puppet node}
  snapshot (unreliable)       ─▶ update puppets with known handles; ignore unknown
```

### Key Interfaces

```gdscript
class_name Relevance extends RefCounted
func visible_set(volume_id: StringName) -> PackedStringArray   # from Facility Map data, minus closed-door cuts
func relevant_bodies(viewer_peer: int) -> PackedInt32Array      # player IDs, server-side only

class_name HandleTable extends RefCounted
func handle_for(peer: int, player_id: int) -> int               # issues + queues introduce if new
func retire(peer: int, player_id: int) -> void                  # queues retire message
func reset_peer(peer: int) -> void                              # reconnect / spectator switch

# Each catalog event (ADR-0005) implements:
func project(peer: int, handles: HandleTable) -> Dictionary     # {} = not sent (amended by ADR-0005)
```

### Implementation Guidelines
- Player bodies **must** reach clients only through per-peer snapshots. They **must never** be spawned or synchronized by `MultiplayerSpawner` or `MultiplayerSynchronizer`.
- Client-bound payloads **must** name bodies by per-peer handle. They **must never** contain the shapeshifter's player ID or a stable body ID during a round.
- Every catalog event **must** implement `project`. An event with no projection **must never** be sent to clients.
- A handle **must** be introduced on the reliable event channel before any event or snapshot uses it.
- A form change or transformation start on a lingering body **must** retire its handle.
- Sounds **must** be positional events with no handle.
- Spawned non-body nodes **must** use opaque counter names and identity-free spawn payloads. Their synchronizer **must** have `public_visibility = false` before `spawn()` returns, and `set_visibility_for` grants **must** follow `spawn()` in the same frame.
- Per-peer RPCs **must** target fixed-name nodes. Puppet nodes **must never** carry RPCs. Nodes **must never** be named after a player ID, peer ID or handle.
- `relevance_near_m` and `relevance_linger_s` **must** come from data. The visibility sets **must** come from Facility Map data, not code.

## Alternatives Considered

### Alternative 1: Stable opaque handles per round
- **Description**: Each body gets one random handle per round.
- **Pros**: Simpler; no introduce/retire churn.
- **Cons**: A modified client that once saw the monster in true form can follow its handle into any later disguise.
- **Rejection Reason**: Reopens the exact leak `borrowed-face.md` names.

### Alternative 2: Handles equal player IDs, no relevance filtering
- **Description**: Replicate every body to every client under its player ID.
- **Pros**: Least code.
- **Cons**: Wallhack and identity leak by default; fails every packet-capture criterion.
- **Rejection Reason**: Contradicts the GDDs.

### Alternative 3: Runtime line-of-sight relevance
- **Description**: Server raycasts from each viewer to each body at 10–20 Hz.
- **Pros**: Tightest filter; no authored data.
- **Cons**: More CPU; pop-in at corners.
- **Rejection Reason**: Designer decision 2026-10-12: authored room PVS. A PVS-plus-ray refinement remains possible later.

### Alternative 4: New handle on every form change, even in view
- **Description**: Always swap handles when a transformation completes.
- **Pros**: Uniform rule.
- **Cons**: Hides nothing a watching player did not see; adds churn.
- **Rejection Reason**: Designer decision 2026-10-12: keep the handle when the change is in view.

## Consequences

### Positive
- A modified client knows what its player saw and little more.
- One projection hook per event makes each packet-capture criterion a unit test.
- PVS relevance also bounds snapshot size and blocks wallhacks.
- Spectators and reconnects reuse the same machinery.

### Negative
- Custom handle bookkeeping and an introduce/retire protocol to own.
- Relevance is room-coarse: a body behind cover in a visible room is still sent.
- The Facility Map must author and maintain a visibility table.
- A body that leaves and returns within 0.5 s keeps its handle, so a short gap can be bridged (bounded by the form-change retire rule).

## Risks
- **Spawner visibility leak.** Unverified whether a spawner reaches peers its synchronizer never granted. Mitigation: the spawn order in Decision 7; Verification Required item 1 before acceptance.
- **Node-path leak.** A node named by player or peer ID leaks it in the first RPC's path. Mitigation: Decision 7a; Verification Required item 5.
- **Timing correlation.** A cheater may correlate one body leaving and another appearing. Mitigation: accepted residual; it matches what an attentive player infers by ear.
- **PVS authoring errors.** A missing set entry hides a visible body (pop-in); an extra one leaks. Mitigation: a debug overlay listing relevant bodies per peer, and an integration test walking every volume.
- **Projection mistakes.** One event that forgets to project leaks. Mitigation: ADR-0005 makes `project` mandatory; a test fails on any event class without it.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| borrowed-face.md | Open Question: keep survivor clients from learning which entity is the monster (`FormChanged` names it; Transforming flag on its entity) | Decisions 2–5: no `FormChanged` to survivors; per-peer handles re-issued on re-entry; warp shown only on relevant handles |
| borrowed-face.md | AC: all 5 clients render the same form within 250 ms of `FormChanged`, including after reconnect | Decisions 2, 9: appearance in the next snapshot to every peer for which the body is relevant; full snapshot on reconnect |
| survivor-defense.md | Rule 1, AC: identical `PlayerShocked` for survivor, stunned and immune disguised monster; no `MonsterStunned` or immunity data while disguised | Decision 5 projection table |
| monster-abilities.md | AC: no `AbilityUsed` and no monster position from it on survivor clients | Decision 5 |
| scare-events.md | Rule 1a, AC: no source or player identity in `ScareTriggered`; hallucinations reach only their target | Decisions 5, 7 |
| survivor-objectives.md | Rule 5, AC: survivor clients receive no data for an undiscovered point | Decisions 5, 7 |
| downing-and-rescue.md | AC: the shapeshifter's client receives no bleed-out timer or ring state | Decision 5 |
| pings-and-callouts.md | AC: fake callouts indistinguishable from real ones; monster receives pings only in line of sight; spectators receive what the watched survivor receives | Decisions 6, 8; Pings & Callouts owns its own projection rules |
| research-facility.md | Server owns door, lighting and exit state; clients never change them | Decision 4: door state replicated under the PVS rule |

## Performance Implications
- **CPU**: Per tick, per peer: a set lookup per body and a distance check. Negligible.
- **Memory**: One handle table per peer (at most 6 entries).
- **Load Time**: Visibility table loads with the map.
- **Network**: Estimate (not measured): about 6 bodies × 30 bytes ≈ 200 bytes per peer per snapshot, about 12 KB/s per peer at 60 Hz, within the spike's 87 kbps envelope. Introduce and retire messages are rare. Remote bodies may drop to 30 Hz if measured upload pressure demands it.

## Migration Plan
No production code exists. GDDs updated alongside this ADR: `research-facility.md` (Visibility Sets section and Open Question), `borrowed-face.md` (Open Question resolved), `systems-index.md` (`FormChanged`, form, Transforming and `MonsterStunned` consumer wording).

## Validation Criteria
- Every packet-capture criterion in the GDDs listed above passes.
- With a disguised monster out of a survivor's PVS for 1 s, then back in view, the survivor client receives a handle it has never seen before.
- A form change during linger retires the handle on that peer.
- A survivor client's capture over a full round contains no shapeshifter player ID outside public roster, feed and results messages.
- After reconnect and after a spectator switch, the client's handle set is entirely new and its state matches the server's projection.
- The spawner leak case (Verification Required 1) passes.

## Related
- ADR-0001, ADR-0002 (depends on)
- ADR-0005 — event catalog; makes `project` mandatory
- `docs/architecture/architecture.md` — principle 2, Required ADR 4
- `design/gdd/borrowed-face.md`, `design/gdd/survivor-defense.md`, `design/gdd/scare-events.md`, `design/gdd/survivor-objectives.md`, `design/gdd/downing-and-rescue.md`, `design/gdd/pings-and-callouts.md`, `design/levels/research-facility.md`, `design/gdd/systems-index.md`
- `prototypes/networking-spike/README.md` (H4)
