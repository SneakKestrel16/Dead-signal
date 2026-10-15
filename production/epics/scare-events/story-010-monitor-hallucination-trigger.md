# Story 010: Server trigger for the impossible surveillance frame

> **Epic**: Scare Events
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Story 009 built the client half of the `surveillance_image` hallucination (red static on the target's monitor feed), but only a manual `round_host --force` fires it. The GDD lists it as a single-client scare when a player views a monitor (Survivor + RoundScript select, proposed). Surveillance viewing exists from facility-map story 011.

**GDD**: `design/gdd/scare-events.md` rules 2, 6, 12, 20, 21
**Requirement**: `TR-scare-012`, `TR-scare-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding; secondary: ADR-0015
**ADR Decision Summary**: A single-client scare goes to its target only; gating applies per recipient.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: single-client scope, one recipient
- Forbidden: a hallucination that shows the monster's real position

---

## Acceptance Criteria

*From GDD `design/gdd/scare-events.md`, scoped to this story:*

- [x] When a player starts viewing the C1 monitor in an eligible phase, the server may fire `surveillance_image` to that player only, through `ScareEvents.fire` and its gating (`hallucination_max_per_client`, cooldowns).
- [x] No other peer receives any data about it (reuse story 003's per-peer capture).
- [x] The frame never shows the monster's real position or real camera content.

---

## Implementation Notes

- Find where surveillance viewing is decided on the server (facility-map story 011) and subscribe or poll there; keep the hook one line in the composer.
- Which phases and how often is not in the GDD: pick a conservative default from the catalogue entry and mark it as inference.

---

## Out of Scope

- Client presentation (story 009).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scare-events/monitor_hallucination_trigger_test.gd` (real ENet where the AC names clients)

**Status**: [x] tests/integration/scare-events/monitor_hallucination_trigger_test.gd (4 cases); full suite 1403/1403

---

## Dependencies

- Depends on: Stories 003, 009
- Unlocks: None

## Progress Notes (2026-10-15)

Merged 0c7eb61. MonitorHallucination (TickOrder.SCARE_EVENTS + 3) fires surveillance_image to the viewer only, at the monitor point, on each feed view start in an eligible phase, through ScareEvents.fire gating (hallucination_max_per_client 2, cooldowns, repeat block). Catalogue entry gains phases Rising and Emergency. INFERENCE: GDD names neither phases nor frequency; Rising+Emergency and every view start capped by gating; designer ruling on RoundScript selection settles it. Eligibility reads FacilityScareState.state(). 4 cases (1 real-ENet 5-client with per-peer byte capture); 4 mutations caught. Full suite 1403/1403, no leak lines.
