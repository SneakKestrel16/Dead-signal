# Story 003: Scoped delivery: shared relevance and single-client hallucinations

> **Epic**: Scare Events
> **Status**: Complete
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

- [x] With 5 clients, a shared scare (for example a door burst) is received by every relevant client with the same scare_id and origin, and by no irrelevant client.
- [x] A hallucination is received only by its target; a capture on the other 4 clients shows no data for it.
- [x] A hallucination never shows a fake teammate, ping, callout or pickup, never misrepresents objective state or the round timer, and never shows the monster's real position.

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

**Status**: [x] `tests/integration/scare-events/scoped_delivery_hallucinations_test.gd` (6 cases, 2 over real ENet)

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: Story 009

## Progress Notes (2026-10-15)

Merged from wt-se3. Full suite 1368/1368, no leak lines. Mutations caught: sight clause removed, audible range shrunk 0.5 m, rule-21 check disabled, RoundScript bypassing relevance.

Notes:
- `ScareRelevance.recipients(entry, origin, candidates)`: within the entry's `audible_range_m` (boundary counts) or the shared `SightTest` sees the origin; facing and sight range ignored (rule 19 names neither). `RoundScript` uses it; nothing fires when no one is relevant.
- Hallucination over real ENet: one recipient only; a raw-packet capture on the other 4 peers holds no batch and no bytes of the scare id or origin.
- Rule 21 as data: the catalogue refuses a single-client entry with Monster source (it would show the monster's real position). No entry field can hold a fake teammate, ping, callout, pickup, objective or timer; the payload carries only scare, scope, origin, intensity.

Deviations (inference):
- The ambush lunge is not routed through relevance: rule 5a sends it within `lunge_cue_radius_m` (20 m) to survivors who have not seen the monster, and the catalogue gives `ambush_lunge` 15 m. Routing it would drop unseen survivors at 15-20 m.
- Follow-up: `MonsterScares.recipients` (story 004) is still distance-only; swap to `ScareRelevance`.
- "Inside the affected room/zone" is treated as covered by the range test; the listener point is standing eye height.
