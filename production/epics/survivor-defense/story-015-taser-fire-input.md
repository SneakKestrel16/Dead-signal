# Story 015: Shipped client fires the taser on use_item

> **Epic**: Survivor Defense
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

The `use_item` action is bound in `project.godot` but nothing reads it, and `SurvivorDefense.fire_packet()` has no shipped caller. A survivor holding the taser in the shipped build cannot fire it.

**GDD**: `design/gdd/survivor-defense.md` taser rules
**Requirement**: `TR-defense-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus; secondary: ADR-0002
**ADR Decision Summary**: Input passes through the InputContextStack mask; the client sends intent and the server decides hits.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: gated by contexts.allows_actions()
- Forbidden: client-side hit decisions

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md`, scoped to this story:*

- [ ] A survivor holding the taser presses use_item and the server receives one fire request per press; cartridges and stun follow the server rules (real ENet, at least 2 clients).
- [ ] With the callout wheel or an overlay open, use_item sends nothing.
- [ ] A survivor without the taser sends nothing.

---

## Implementation Notes

- Check the TR id against docs/architecture/tr-registry.yaml and correct it in this story if it differs.

---

## Out of Scope

- Taser presentation beyond what exists.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/survivor-defense/taser_fire_input_test.gd` (real ENet where the AC names clients)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: match-flow 013
- Unlocks: None
