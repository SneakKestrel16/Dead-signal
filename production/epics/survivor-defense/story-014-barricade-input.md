# Story 014: Barricade input distinct from the door toggle

> **Epic**: Survivor Defense
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Since AD-217 a client's hold Start names the map interactable it aims at, and the server picks the first hold at that object the actor is eligible for. At a barricadable door the instant door toggle is registered first and is eligible for everyone, so a client can never start Barricade, Remove Barricade or Break: the toggle always wins. Found while merging the hold-target fix (2026-10-15).

The GDD does not name the input. `design/gdd/first-person-controller.md` rule 18 makes doors instant toggles shown locally within 100 ms. `design/gdd/survivor-defense.md` rules 25-27 make Barricade a 3 s hold, Remove a 1 s hold and Break a monster hold. A tap-versus-hold split on one key would delay every door toggle past the 100 ms target, so this story uses a second input (AD-219, orchestrator recommendation, pending designer review).

**GDD**: `design/gdd/survivor-defense.md` rules 24-27; `design/gdd/first-person-controller.md` rule 18
**ADR Governing Implementation**: ADR-0008 (hold service); ADR-0002 (input frame)

## Acceptance Criteria

- [ ] A secondary interact action (input map `interact_alt`, default key F; inference, a controls pass settles the binding) sets a new `InputFrame` bit. A Start with that bit at a barricadable door resolves to the first eligible hold among Barricade, Remove and Break; without it, to the door toggle.
- [ ] A survivor client starts and completes Barricade on a closed barricadable door, removes it, and the shapeshifter breaks one, over real ENet (extend `tests/integration/match-flow/client_round_scene_test.gd` or a sibling test).
- [ ] The door toggle still shows locally within one tick of the press (no added delay).
- [ ] The input frame stays within its byte cap; the new bit is validated like the others.

## Out of Scope

- Rebinding UI (Accessibility Options).

## Test Evidence

**Story Type**: Integration
**Required evidence**: real-ENet test above
**Status**: [ ] Not yet created

## Dependencies

- Depends on: AD-217 hold-target fix (merged e71e40d)
