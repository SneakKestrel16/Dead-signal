# Story 002: Form-change request validation and target persistence

> **Epic**: Borrowed Face
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

The server accepts a form change only into an observed survivor still in the round. Once worn, a disguise stays no matter what happens to the copied survivor.

**GDD**: `design/gdd/borrowed-face.md`
**Requirement**: `TR-borrowedface-001`, `TR-borrowedface-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order
**ADR Decision Summary**: Server-owned module state exposed through read-only views; requests are validated at the module's step in the tick order; owners emit their own catalog events.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: 4.7 typed-return override inheritance: restate return types.

**Control Manifest Rules (this layer)**:
- Required: owner emits its own catalog events (ADR-0005)
- Forbidden: client-decided form state

---

## Acceptance Criteria

*From `borrowed-face.md` Acceptance Criteria (requests, targets) and Edge Cases, scoped to this story:*

- [ ] A request into an unobserved, Eliminated, Escaped or disconnected survivor is rejected; one into an observed Downed survivor is accepted.
- [ ] The first request of a round into an observed survivor is accepted with no cooldown wait.
- [ ] While disguised as X, X being downed, eliminated, escaping or disconnecting leaves the disguise unchanged on the server.
- [ ] A target eliminated or disconnected mid-transformation still completes into X.

---

## Implementation Notes

*Derived from `borrowed-face.md` rules 5–6, 13 and Edge Cases:*

- Survivor status reads Downing and Match Flow views; stub them.

---

## Out of Scope

- Story 003: the transformation timer

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/borrowed-face/form_requests_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 003
