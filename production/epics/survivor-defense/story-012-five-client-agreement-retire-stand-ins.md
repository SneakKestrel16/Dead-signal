# Story 012: Five-client agreement and retiring the stand-ins

> **Epic**: Survivor Defense
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Closes the epic: with five clients connected, all five agree on stun state (as visible to their role), charges, hiding occupancy and barricade state after each event. The `StubDefense` classes and fixture hide/search/barricade interactables in Borrowed Face tests are replaced by the real module and those tests re-run green.

**GDD**: `design/gdd/survivor-defense.md`
**Requirement**: `TR-defense-001, TR-defense-003, TR-defense-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Authoritative simulation, tick rate and input; secondary: ADR-0004, ADR-0005
**ADR Decision Summary**: All five clients agree on every server-owned state as their role permits, and merged stories stop depending on stand-ins.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Uses the existing multi-client harness in `tests/integration/network/`.

**Control Manifest Rules (this layer)**:
- Required: every server-owned state replicates through the registry; role-based projection (ADR-0004, ADR-0005)
- Forbidden: never leave a copy of the stand-in behaviour in tests once the real module covers it
- Guardrail: the whole suite passes unchanged apart from the replaced stubs

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md` (Detailed Design and Acceptance Criteria), scoped to this story:*

- [ ] With 5 clients, all agree on stun state (as visible to their role), charges, hiding occupancy and barricade state after each event (acceptance 9).
- [ ] `StubDefense` in `transform_state_machine_test.gd`, `transform_immunity_test.gd` and `stun_projection_test.gd` is replaced by the real module and all three pass; `disguise_gates_test.gd` runs its hide, barricade and search rows against the real interactables.
- [ ] Every Tuning Knob is loaded from data; a test asserts no hardcoded value (acceptance 20).

---

## Implementation Notes

- Stand-in test files to re-run and edit: `tests/unit/borrowed-face/transform_state_machine_test.gd`, `tests/unit/borrowed-face/transform_immunity_test.gd`, `tests/integration/borrowed-face/stun_projection_test.gd`, `tests/integration/borrowed-face/disguise_gates_test.gd`.
- Run the whole suite before and after; only the stub removals should differ.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- None

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration: `tests/integration/survivor-defense/five_client_agreement_test.gd` plus the re-run list above

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 004, 005, 006, 008
- Unlocks: None
