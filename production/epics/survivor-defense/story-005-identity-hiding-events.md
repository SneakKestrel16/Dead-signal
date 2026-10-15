# Story 005: Identity-hiding stun and shock events

> **Epic**: Survivor Defense
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Chooses and emits the right event for every hit: true form gets `MonsterStunned`; a disguised monster, an immune disguised monster and a survivor all get the same `PlayerShocked`; while Transforming the body shown at that moment decides. `MonsterStunned` still reaches server-side consumers and the monster's own client.

**GDD**: `design/gdd/survivor-defense.md`
**Requirement**: `TR-defense-003, TR-defense-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding; secondary: ADR-0005
**ADR Decision Summary**: Clients receive only what the viewer may know: one identical `PlayerShocked` for a hit on a survivor or a disguised monster, and `MonsterStunned` only for a true-form monster.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Uses `EvPlayerShocked.project` and `EvMonsterStunned.project` with `HandleTable`; the form comes from `BorrowedFace.appearance_of` and `transforming_of`.

**Control Manifest Rules (this layer)**:
- Required: projection per viewer; the event shape must not depend on who was hit (ADR-0004 section 5)
- Forbidden: never send `MonsterStunned` or immunity data to a survivor while the monster is disguised; never leak a player id (use the handle)
- Guardrail: Every value is read from `DefenseKnobs` (`data/knobs/defense.tres`), none hardcoded.

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md` (Detailed Design and Acceptance Criteria), scoped to this story:*

- [x] While the monster is disguised, a captured survivor-client stream shows one identical `PlayerShocked` for a hit on a survivor, a stunned monster and an immune monster, and no `MonsterStunned` (acceptance 15).
- [x] A true-form stun reaches every client as `MonsterStunned`; a resisted true-form hit is distinguishable as resisted to all clients (rule 10).
- [x] A hit while Transforming follows the body shown that moment: out of a disguise counts as disguised (rule 1).
- [x] The shocked player's own client gets `{own: true}`; others get `{body: handle}` only if the body is relevant to them.

---

## Implementation Notes

- Reuse the existing `project()` methods; the work is the decision of which event to emit and the tests proving the capture is identical.
- Replaces `StubDefense` in `stun_projection_test.gd`; keep its Borrowed Face assertions and point them at the real module.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: how each form looks
- Story 012: five-client agreement

---

## QA Test Cases

*Test specs from `/qa-plan sprint` (`production/qa/qa-plan-sprint-006-2026-10-15.md`). Tests emit the other epic's events directly until MA-6 and SD-12 re-run against both real modules.*

**Test file path**: `tests/integration/survivor-defense/identity_hiding_events_test.gd`

- **AC-1**: Disguised monster is indistinguishable
  - Given: a disguised monster; captured survivor-client streams
  - When: a hit on a survivor, on a stunned monster, on an immune monster
  - Then: three identical `PlayerShocked` payloads; no `MonsterStunned`
  - Edge cases: byte-compare the three packets
- **AC-2**: True form
  - Given: a true-form monster
  - When: a stun, then a resisted hit
  - Then: `MonsterStunned` to all; the resisted hit is distinguishable as resisted to all
  - Edge cases: resisted hit on the last immunity tick
- **AC-3**: Transforming
  - Given: a hit while Transforming
  - When: out of a disguise, into a disguise
  - Then: follows the body shown that moment: out of a disguise counts as disguised
  - Edge cases: hit on the change-complete tick
- **AC-4**: Per-peer payload
  - Given: the shocked player and others
  - When: events are captured
  - Then: own client gets `{own: true}`; others get `{body: handle}` only if the body is relevant
  - Edge cases: body not relevant to a peer: field absent

**Re-run against the real module**: `tests/integration/borrowed-face/stun_projection_test.gd`

**Estimated test count**: ~6 tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration: `tests/integration/survivor-defense/identity_hiding_events_test.gd`. Re-run: `tests/integration/borrowed-face/stun_projection_test.gd`.

**Status**: [x] `tests/integration/survivor-defense/identity_hiding_events_test.gd` (5 tests)

---

## Dependencies

- Depends on: Stories 003, 004
- Unlocks: Stories 011, 012

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-189):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 1040/1040 after the wave merge, no leak warnings.
- Resisted true-form hit sent as PlayerShocked (no resisted event in the catalog); clients tell it from a stun by event type. Leaks nothing: true form is already visible. A designer ruling on a dedicated StunResisted event settles it; story 011 would read that.
- systems-index.md PlayerShocked row still says survivor or disguised hits only; not updated pending that ruling.
- AC-1 byte-identity uses a fresh seeded handle table per case so handle values match.
- tests/integration/borrowed-face/stun_projection_test.gd StubDefense replaced by the real SurvivorDefense plus a Hitter module.
- Targeted run hit the BUG-0003-class flake in transforming_visibility_test under parallel load; passes alone.
**Test Evidence**: 5 tests; 4 failed before the change. Mutations caught: no PlayerShocked when resisted, true_form always true, no PlayerShocked on resisted true-form hit.
**Code Review**: Complete (orchestrator review at merge)
