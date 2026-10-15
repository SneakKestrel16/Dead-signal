# Story 004: Ping recipients and per-peer delivery

> **Epic**: Pings & Callouts
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

An accepted ping goes to every living survivor, and to the monster only if the target is in the monster's line of sight (facing ignored). Spectators mirror the survivor they watch. Nothing about a rejection reaches anyone.

**GDD**: `design/gdd/pings-and-callouts.md` rules 2, 7, 7a, 8
**Requirement**: `TR-pings-002`, `TR-pings-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding; secondary: ADR-0005
**ADR Decision Summary**: Delivery is per peer; a peer never receives data it may not know. No real/fake tag on the wire.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: per-recipient presentation messages from the server only
- Forbidden: never send occupant identity for a hiding spot item ping

---

## Acceptance Criteria

*From GDD `design/gdd/pings-and-callouts.md`, scoped to this story:*

- [x] With 5 clients, a survivor's item ping appears on the 3 other survivor clients, and on the monster's client only when the object is in the monster's line of sight, at the same object with the same sender name within 250 ms of acceptance (LAN or simulated 100 ms round trip).
- [x] A survivor's ping on a point outside the monster's line of sight reaches the 4 survivors' clients and not the monster's, including when the sender is Downed.
- [x] A ping rejected by the server removes the sender's pending marker, and no other client receives it.
- [x] An item ping on an occupied hiding spot contains no occupant identity on any client; an Eliminated or Escaped player's client receives exactly the pings delivered to the survivor it watches.

---

## Implementation Notes

- Monster line of sight: an unobstructed server ray from the monster's eye to the target within `ping_max_range_m`; a warning ping on the monster's own body always reaches it.
- Reuse the existing per-peer channel used by presentation messages (see how lighting records or `PlayerShocked` are sent per peer).
- Spectator mapping: `round_lifecycle.gd` exposes the watched survivor.

---

## Out of Scope

- Story 005: client marker lifetime and display.
- Story 007: displayed identity and (not you).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/pings-and-callouts/ping_recipients_delivery_test.gd` (real ENet where the AC names clients)

**Status**: [x] `tests/integration/pings-and-callouts/ping_recipients_delivery_test.gd` (real ENet, 5 clients)

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: Stories 005, 007, 008

## Progress Notes (2026-10-15)

Merged from wt-pc4. Full suite 1345/1345 with no agents running, no leak lines (an earlier run during a parallel agent's ENet suite failed `round_composer_test` five-client case; it passed twice alone and in the clean full run). Mutations caught: monster always receives, rejection send removed, `monster_sees` always false.

Notes:
- `PingDelivery` (server, `ServerMovement.batch_extras`) sends `[EventBatch.PING, {kind, point, item, type, identity, from}]`; `from` is the sender's displayed appearance id, never a player id. A rejection goes to the sender's own peer only (`PING_REJECTED`). `PingReceiver` on the client keeps `pending` and `received`.
- The 5-client test adds one WORLD-layer wall (the greybox has none) and asserts sight is blocked through it first.

Deviations (inference):
- Story 001's `_sees` uses `SightTest` at 360 degrees and yaw 0, so a point exactly behind (+Z) can compute a hair over pi and be refused. `monster_sees` checks range and the ray directly. Fix: an epsilon in `SightTest` or a bypass at 360 (SE-5 used fov INF for the same reason).
- Requests beyond the per-tick queue cap get no rejection echo; their pending markers clear at lifetime (story 005).
- A rejoining client gets no pings (transient). Monster sight is judged in the send phase with that tick's positions.
- An own accepted copy clears the oldest pending request of the same kind (FIFO).
