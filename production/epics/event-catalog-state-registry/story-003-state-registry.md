# Story 003: StateRegistry and typed views

> **Epic**: Event Catalog & State Registry
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-12
> **Last Updated**: [set by /dev-story when implementation begins]

BLOCKED: ADR-0005 is Proposed — accept it with `/architecture-decision accept ADR-0005` once decided.

## Context

Systems read each other's state only through the rows of the `systems-index.md` state table. Each row has one owner that registers a getter-only view; readers ask for it by key and expected class.

**GDD**: none (state table in `design/gdd/systems-index.md`)
**Requirement**: `TR-index-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event Catalog, State Registry and Tick Order
**ADR Decision Summary**: `register_view(key, owner, view)` once per key (a second registration asserts); `view(key, ViewClass)` asserts `is_instance_of` and returns the getter-only view; owners replace collection values whole.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification results (5): `is_instance_of(view, ViewClass)` works with a `class_name` script. 4.7: writing a packed-array element no longer calls the property setter, hence whole replacement.

**Control Manifest Rules (this layer)**:
- Required: readers use `registry.view(key, ViewClass)`; view classes expose getters only; owners replace collection values whole
- Forbidden: writing another module's state [direct_cross_system_state_write]; in-place element writes [elementwise_collection_write]; a generic key-to-Variant registry
- Guardrail: none specific

---

## Acceptance Criteria

*From ADR-0005 §5 and Validation Criteria, scoped to this story:*

- [ ] A registered view is returned by `view(key, ViewClass)`; asking with the wrong class asserts; registering the same key twice asserts.
- [ ] A view reflects its owner's state after the owner replaces a collection whole.
- [ ] A test fails if any `*View` class declares a setter or a public writable property.

---

## Implementation Notes

*Derived from ADR-0005 Decision and Implementation Guidelines:*

- Keys are the rows of the `systems-index.md` state table; define them as `StringName` constants in one place.
- A view reads its owner's private state, which forms a module → registry → view → module cycle; `clear()` at round end breaks it (story 004).

---

## Out of Scope

- Feature epics: the real views for each state row

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/event_catalog/state_registry_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 004
