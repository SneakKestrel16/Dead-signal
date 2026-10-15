# Story 007: Barricade build and remove, closed doors block the dash

> **Epic**: Survivor Defense
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Barricadable doors can be barricaded by a Healthy survivor in `barricade_duration_s` and removed by a survivor in `barricade_remove_s`; a barricaded door cannot be opened by anyone. A closed door blocks a lunge's path so it resolves as a miss. Barricade, remove and break share the door's one exclusive lock.

**GDD**: `design/gdd/survivor-defense.md`
**Requirement**: `TR-defense-007, TR-defense-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Hold-to-interact protocol; secondary: ADR-0007
**ADR Decision Summary**: Barricade and remove are holds on one exclusive per-door lock; door state is server-owned, and closed doors block the dash and line of sight through collision layers.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Builds on `Doors` (instant toggle, `closed_states`) and `DoorBlockers`; the barricade extends door state, not a second door system.

**Control Manifest Rules (this layer)**:
- Required: door and barricade state on the server; the interactable table in GDD rule 28a feeds `HoldService` (ADR-0008)
- Forbidden: never complete a barricade from a client message; never create a second door state
- Guardrail: Every value is read from `DefenseKnobs` (`data/knobs/defense.tres`), none hardcoded.

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md` (Detailed Design and Acceptance Criteria), scoped to this story:*

- [ ] Barricading takes `barricade_duration_s` (3 s), is not rooting, resets on cancel, and removing takes `barricade_remove_s` (1 s) (rules 25, 26, 28a).
- [ ] A barricaded door cannot be opened by anyone until broken or removed; it fails to complete while the monster is in the doorway (rule 26, edge case).
- [ ] A lunge whose path crosses a closed door stops at the door and resolves as a miss (rule 24).
- [ ] Only one of barricade, remove and break runs on a door at a time; a forged 'barricade complete' message changes nothing.

---

## Implementation Notes

- Doors have `can_use(actor)` and a `holds` link today; extend rather than duplicate.
- The lunge side lives in Monster Abilities (built in parallel): test the block with a fixture dash against the real door layers and re-test when the lunge lands.
- Lockout after a break is story 008.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: break, lockout, `BarricadeBroken`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration: `tests/integration/survivor-defense/barricade_doors_test.gd`. Re-run: `tests/integration/borrowed-face/disguise_gates_test.gd` (barricade and remove rows) and the Facility Map door tests.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 008
