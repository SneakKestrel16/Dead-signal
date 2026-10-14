# Story 003: StateRegistry and typed views

> **Epic**: Event Catalog & State Registry
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-13

Unblocked 2026-10-13: ADR-0001..0008 Accepted. 

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

- [x] A registered view is returned by `view(key, ViewClass)`; asking with the wrong class asserts; registering the same key twice asserts.
- [x] A view reflects its owner's state after the owner replaces a collection whole.
- [x] A test fails if any `*View` class declares a setter or a public writable property.

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

*From `production/qa/qa-plan-sprint-001-2026-10-12.md` (/qa-plan, 2026-10-12). Implement against these and the Acceptance Criteria above.*

**What to test**:
- `view(key, ViewClass)` returns the registered view.
- Wrong class → assert; second registration of a key → assert.
- Owner replaces a collection whole → view getter returns the new value.

**Edge cases to cover**:
- Unregistered key → assert with the key name.
- A `*View` class with a setter fails the reflection test.

**Estimated test count**: ~5 unit tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/event_catalog/state_registry_test.gd` — must exist and pass

**Status**: [x] `tests/unit/event_catalog/state_registry_test.gd` — 11 tests; suite 57/57 pass (2026-10-13)

---

## Dependencies

- Depends on: None
- Unlocks: Story 004

---

## Completion Notes
**Completed**: 2026-10-13
**Criteria**: 3/3 passing, each covered by a gdUnit4 test (11 tests, 0 failures, 0 orphans)
**Deviations** (advisory):
- Violations (second registration, wrong class, unregistered key) are recorded in `violations`, `push_error`'d, and `assert(false)` only when `fail_hard` (default `OS.is_debug_build()`), same pattern as `EventBus`; `view()` returns null after recording.
- `StateKeys` has 22 constants, one per state-table row; the key names are the implementer's choice (e.g. `PLAYER_POSITIONS_LIFE_STATES`) and are not yet reviewed.
- The "no setter / no public writable property" check is a reflection scan over `*_view.gd` under `src/`. It found 0 real view files (none exist until the Feature epics). It was proved on a BadView fixture, but a real view class has never run through it. GDScript has no read-only var, so every public `var` and every public method not starting `get_`/`is_`/`has_` is flagged.
- The `set(v):` property-setter scan runs only on scripts with source text (real files); inner-class fixtures are covered by the `set_` method rule, and the property-setter case is tested with a runtime-built script.
**Test Evidence**: Logic: `tests/unit/event_catalog/state_registry_test.gd`; mutation-checked (silent overwrite on register; `is_instance_of` removed: each failed a test; the second run aborted early, so only that one failure was confirmed).
**Code Review**: Skipped (lean mode). The registry was read in full by the orchestrator; no specialist or QA review ran.
