# Story 003: Scoped delivery: shared relevance and single-client hallucinations

> **Epic**: Scare Events
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Shared scares go to every relevant client: within the sound's audible range or with line of sight to the effect. A hallucination goes only to its target; no other peer, the monster included, gets any data about it.

**GDD**: `design/gdd/scare-events.md` rules 19-21
**Requirement**: `TR-scare-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding; secondary: ADR-0005
**ADR Decision Summary**: Delivery is per peer; a shared scare emits one event per recipient.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: per-peer projection only
- Forbidden: never broadcast a single-client scare

---

## Acceptance Criteria

*From GDD `design/gdd/scare-events.md`, scoped to this story:*

- [ ] With 5 clients, a shared scare (for example a door burst) is received by every relevant client with the same scare_id and origin, and by no irrelevant client.
- [ ] A hallucination is received only by its target; a capture on the other 4 clients shows no data for it.
- [ ] A hallucination never shows a fake teammate, ping, callout or pickup, never misrepresents objective state or the round timer, and never shows the monster's real position.

---

## Implementation Notes

- Relevance test: straight-line distance against the entry's audible range, or the shared `SightTest` for line of sight.
- Use real ENet for the 5-client case (see `client_round_scene_test.gd`).

---

## Out of Scope

- Story 006: RoundScript triggers.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scare-events/scoped_delivery_hallucinations_test.gd` (real ENet where the AC names clients)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: Story 009
