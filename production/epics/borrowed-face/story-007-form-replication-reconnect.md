# Story 007: Form replication and reconnect

> **Epic**: Borrowed Face
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] With 5 clients, after each of 10 form changes all 5 render the shapeshifter's body in the same form within 250 ms of `FormChanged`, including a client that reconnects mid-disguise.
- [ ] A survivor client's payloads for the shapeshifter's body carry appearance (character id or true form) and no player ID, role or observed list.
- [ ] A shapeshifter that disconnects while disguised and reconnects within grace returns in true form with its observed list unchanged; the capsule is the same in every form.

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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003; network-authority stories 002, 008
- Unlocks: Story 009
