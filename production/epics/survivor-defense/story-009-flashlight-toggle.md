# Story 009: Flashlight toggle and replicated cone

> **Epic**: Survivor Defense
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Every survivor owns a flashlight toggle, replicated so all clients see the cone and the holder's position. It has no battery and no effect on the monster; it keeps working inside Blackout and does not end it.

**GDD**: `design/gdd/survivor-defense.md`
**Requirement**: `TR-defense-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding
**ADR Decision Summary**: Public per-player state replicates to every client the viewer can see; nothing about it changes the monster.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff APIs; light nodes are presentation only.

**Control Manifest Rules (this layer)**:
- Required: server holds the toggle state, clients predict locally and take the server's value (ADR-0002, ADR-0004)
- Forbidden: never affect the monster's state, form or stun from the light
- Guardrail: this story adds no knob; local toggle response within 50 ms (Game Feel)

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md` (Detailed Design and Acceptance Criteria), scoped to this story:*

- [ ] Toggling flips the server state and every client sees the same cone state; local toggle responds within 50 ms (Game Feel).
- [ ] The flashlight has no battery limit and no effect on the monster: no stun, slow or disguise reveal (rules 2, 5).
- [ ] The flashlight still works while Blackout is active and does not end it early (rule 4).

---

## Implementation Notes

- Toggle state is a single bool per survivor in the replicated state; no flashlight item object.
- Blackout itself is Monster Abilities; test with a lighting-state flag fixture until it lands.
- The cosmetic copy on a disguised monster is story 011.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: cosmetic copy on a disguised monster

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration: `tests/integration/survivor-defense/flashlight_toggle_test.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 011
