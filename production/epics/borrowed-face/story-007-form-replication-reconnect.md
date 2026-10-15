# Story 007: Form replication and reconnect

> **Epic**: Borrowed Face
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Every client must see the same form at the same time, carrying only what rendering needs, and a reconnecting client must see the current form before the body appears.

**GDD**: `design/gdd/borrowed-face.md`
**Requirement**: `TR-borrowedface-001`, `TR-borrowedface-002`, `TR-borrowedface-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding (primary); ADR-0005: Event catalog, state registry and tick order
**ADR Decision Summary**: Appearance travels in the handle introduce and the snapshot; a form change during linger retires the handle on that peer, one in view keeps it; no player ID or role in any payload; the true-form body keeps the same capsule.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `modules/networking.md` is a 4.6 snapshot; 4.7 migration lists no multiplayer changes.

**Control Manifest Rules (this layer)**:
- Forbidden: identity or role in body payloads (ADR-0004)

---

## Acceptance Criteria

*From `borrowed-face.md` Acceptance Criteria (multi-client, reconnect), scoped to this story:*

- [x] With 5 clients, after each of 10 form changes all 5 render the shapeshifter's body in the same form within 250 ms of `FormChanged`, including a client that reconnects mid-disguise.
- [x] A survivor client's payloads for the shapeshifter's body carry appearance (character id or true form) and no player ID, role or observed list.
- [x] A shapeshifter that disconnects while disguised and reconnects within grace returns in true form with its observed list unchanged; the capsule is the same in every form.

---

## Implementation Notes

*Derived from ADR-0004 and network-authority story 008:*

- Rendering is a stub that records the appearance id per body; the visual swap is Story 009.

---

## Out of Scope

- Story 009: rendering

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/borrowed-face/form_replication_test.gd` — must exist and pass

**Status**: [x] `tests/integration/borrowed-face/form_replication_test.gd` (2 tests)

---

## Dependencies

- Depends on: Story 003; network-authority stories 002, 008
- Unlocks: Story 009

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-165):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 895/895 after the wave merge, no leak warnings.
- Appearance travels in the snapshot only, not also in the handle introduce (ADR-0004 says both); a client has no body state before the first snapshot, so the form is still known first.
- Disguise lost at the disconnect, not the reconnect; cooldown not reset. Inference; a Borrowed Face designer ruling settles it.
- Composer must wire set_appearance_source, appearance_of, on_form_event and catch_up; until then every body sends appearance 255.
- ENet test uses a duplicated knob set at range minimums (observe 1 s, cooldown 6 s); shipped data untouched.
- Merge conflict with BF-5 in borrowed_face.gd (both additive) resolved by keeping both.
**Test Evidence**: 2 tests. Mutations caught: appearance never true form, every connection event dropping the disguise, shapeshifter shown as its own character.
**Code Review**: Complete (orchestrator review at merge)
