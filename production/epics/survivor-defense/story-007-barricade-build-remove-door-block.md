# Story 007: Barricade build and remove, closed doors block the dash

> **Epic**: Survivor Defense
> **Status**: Complete
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

- [x] Barricading takes `barricade_duration_s` (3 s), is not rooting, resets on cancel, and removing takes `barricade_remove_s` (1 s) (rules 25, 26, 28a).
- [x] A barricaded door cannot be opened by anyone until broken or removed; it fails to complete while the monster is in the doorway (rule 26, edge case).
- [x] A lunge whose path crosses a closed door stops at the door and resolves as a miss (rule 24).
- [x] Only one of barricade, remove and break runs on a door at a time; a forged 'barricade complete' message changes nothing.

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

*Test specs from `/qa-plan sprint` (`production/qa/qa-plan-sprint-006-2026-10-15.md`). Tests emit the other epic's events directly until MA-6 and SD-12 re-run against both real modules.*

**Test file path**: `tests/integration/survivor-defense/barricade_doors_test.gd`

- **AC-1**: Build and remove timing
  - Given: a door
  - When: build `barricade_duration_s` (3 s), cancel, remove `barricade_remove_s` (1 s)
  - Then: not rooting; resets on cancel; remove takes 1 s
  - Edge cases: cancel 1 tick before completion
- **AC-2**: Barricaded door
  - Given: a barricaded door; the monster in the doorway
  - When: anyone opens it; a build is completed
  - Then: cannot open until broken or removed; build fails to complete with the monster in the doorway
  - Edge cases: monster leaves the doorway on the final tick
- **AC-3**: Lunge blocked
  - Given: a lunge path crossing a closed door
  - When: the dash runs
  - Then: stops at the door, resolves as a miss
  - Edge cases: door closed the same tick
- **AC-4**: One action at a time
  - Given: build, remove and break on one door; a forged 'barricade complete'
  - When: started together
  - Then: only one runs; the forgery changes nothing
  - Edge cases: same-tick start from two players

**Re-run against the real module**: `tests/integration/borrowed-face/disguise_gates_test.gd` (barricade and remove rows); the Facility Map door tests named in the story

**Estimated test count**: ~8 tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration: `tests/integration/survivor-defense/barricade_doors_test.gd`. Re-run: `tests/integration/borrowed-face/disguise_gates_test.gd` (barricade and remove rows) and the Facility Map door tests.

**Status**: [x] `tests/integration/survivor-defense/barricade_doors_test.gd` (12 tests)

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 008

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-181):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 954/954 after the wave merge, no leak warnings.
- Holds have their own net ids; the client input that picks Barricade over the door toggle is not wired (designer or controller decision).
- Remove uses the Healthy-survivor rule like Barricade (rule 28a says only 'Survivor'; inference).
- Stand-in Break interactable and stub dash on the real Jolt doors layer, replaced at MA-6/SD-12.
- Nothing builds Barricades or Doors in a round yet (composer); must be set up after Doors.setup.
**Test Evidence**: 12 tests. Mutations caught: held-shut ignored, no monster-in-doorway check, no shared lock key, progress kept on cancel.
**Code Review**: Complete (orchestrator review at merge)
