# Story 004: Ping recipients and per-peer delivery

> **Epic**: Pings & Callouts
> **Status**: Ready
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

- [ ] With 5 clients, a survivor's item ping appears on the 3 other survivor clients, and on the monster's client only when the object is in the monster's line of sight, at the same object with the same sender name within 250 ms of acceptance (LAN or simulated 100 ms round trip).
- [ ] A survivor's ping on a point outside the monster's line of sight reaches the 4 survivors' clients and not the monster's, including when the sender is Downed.
- [ ] A ping rejected by the server removes the sender's pending marker, and no other client receives it.
- [ ] An item ping on an occupied hiding spot contains no occupant identity on any client; an Eliminated or Escaped player's client receives exactly the pings delivered to the survivor it watches.

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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: Stories 005, 007, 008
