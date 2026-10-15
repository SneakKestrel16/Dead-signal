# Story 005: Identity-hiding stun and shock events

> **Epic**: Survivor Defense
> **Status**: Ready
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

- [ ] While the monster is disguised, a captured survivor-client stream shows one identical `PlayerShocked` for a hit on a survivor, a stunned monster and an immune monster, and no `MonsterStunned` (acceptance 15).
- [ ] A true-form stun reaches every client as `MonsterStunned`; a resisted true-form hit is distinguishable as resisted to all clients (rule 10).
- [ ] A hit while Transforming follows the body shown that moment: out of a disguise counts as disguised (rule 1).
- [ ] The shocked player's own client gets `{own: true}`; others get `{body: handle}` only if the body is relevant to them.

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

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration: `tests/integration/survivor-defense/identity_hiding_events_test.gd`. Re-run: `tests/integration/borrowed-face/stun_projection_test.gd`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 003, 004
- Unlocks: Stories 011, 012
