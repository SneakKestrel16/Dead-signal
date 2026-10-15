# Story 001: Ping module, request validation and token bucket

> **Epic**: Pings & Callouts
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Creates the server-side Pings & Callouts module at TickOrder.PINGS_CALLOUTS (700) and its ping request path. A ping arrives as a client intent; the server checks range and line of sight from the sender's view, the target's validity and the token bucket, then accepts or drops it. Knobs already exist in `src/foundation/data_config/ping_knobs.gd`.

**GDD**: `design/gdd/pings-and-callouts.md` rules 1, 5, 6, 7a, 15; Formulas: ping rate limit
**Requirement**: `TR-pings-001`, `TR-pings-003`, `TR-pings-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Authoritative simulation, tick rate and input; secondary: ADR-0005, ADR-0006, ADR-0012 (SightTest)
**ADR Decision Summary**: Pings are client intents validated on the server tick; the server owns all state. Line of sight uses the shared server `SightTest`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: implement `server_tick(tick)` and register with `TickRunner` at `TickOrder.PINGS_CALLOUTS`
- Required: every range and duration comes from `PingKnobs`
- Forbidden: never emit an event from a client

---

## Acceptance Criteria

*From GDD `design/gdd/pings-and-callouts.md`, scoped to this story:*

- [ ] A ping at a point outside the sender's line of sight, or beyond `ping_max_range_m`, is rejected; no other client receives it.
- [ ] A client with a full bucket (3 tokens) sending 10 pings in 1 s has exactly 3 accepted; a fourth at t=1 is rejected and one at t=2 accepted (Formulas example). A reconnecting player keeps its token and timestamp state.
- [ ] A warning ping on a survivor inside a hiding spot is rejected; an item ping names only pingable types (drive, fuse, fuse box, terminal, hiding spot, barricadable door, backup switch) and a taser is never a target.
- [ ] A warning ping on a monster in True Form is accepted and labelled "Monster"; a player warning ping stores the target's position at ping time and its displayed identity.

---

## Implementation Notes

- Ping types: location, item, warning (point or player). Item targets come from the map interactable registry; add a pingable type field only if one does not exist.
- Line of sight: reuse `SightTest` (ADR-0012) from the sender's eye; a hidden survivor's eye is its peek view (rule 14a).
- Token bucket: `tokens = min(size, tokens + elapsed / refill)`; a rejected ping spends nothing.
- Keep per-player limit state keyed by player id, not by connection, so a reconnect keeps it.

---

## Out of Scope

- Story 002: sender-state gating (Downed, Seized, true form, shock lock).
- Story 004: recipients and delivery.
- Story 005: marker lifetime and max active.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/pings-and-callouts/ping_validation_token_bucket_test.gd` must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (Foundation, Core and the Feature modules it reads are merged)
- Unlocks: Stories 002, 003, 004
