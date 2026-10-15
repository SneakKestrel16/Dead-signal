# Story 015: Shipped client fires the taser on use_item

> **Epic**: Survivor Defense
> **Status**: In Review
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

- [x] A survivor holding the taser presses use_item and the server receives one fire request per press; cartridges and stun follow the server rules (real ENet, at least 2 clients).
- [x] With the callout wheel or an overlay open, use_item sends nothing.
- [x] A survivor without the taser sends nothing.

---

## Implementation Notes

- Check the TR id against docs/architecture/tr-registry.yaml and correct it in this story if it differs.
  Checked 2026-10-15: TR-defense-001 (client intent only, server owns charges) matches; unchanged.
- Implemented: `RoundClient.fire_taser()` / `may_fire()`; charges come from a `DefenseDisplay` on the
  client's router. "Without the taser" is read as no cartridge count (-1, the shapeshifter) or 0 (the
  GDD's "input ignored" edge case): inference, a designer call would settle whether 0 should still send.

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

**Status**: [x] `tests/integration/survivor-defense/taser_fire_input_test.gd` (real ENet, 5 clients);
wheel/overlay gate in `tests/unit/survivor-defense/taser_fire_gate_test.gd`

---

## Dependencies

- Depends on: match-flow 013
- Unlocks: None

## Progress Notes (2026-10-15)

Merged 6a68101..69eba8d. RoundClient reads use_item next to the flashlight check and sends SurvivorDefense.fire_packet() reliably when may_fire(contexts, charges) holds (charges > 0 and contexts.allows_actions(); null contexts on UI-less clients not gated). DefenseDisplay built on the router for every client. INFERENCE: "without the taser" read as count -1 (shapeshifter) or 0, per the GDD edge case "Taser used with 0 cartridges: input ignored"; a designer call on whether a press at 0 still sends settles it. Wheel/overlay gating proven by unit test (UI-less test clients have no stack). Flashlight press still not context-gated (pre-existing). TaserCount (HUD-5) and DefenseDisplay both track CHARGES. Tests: integration taser_fire_input_test (real ENet, 5 clients) + unit taser_fire_gate_test; 3 mutations caught. Full suite 1474/1474.
