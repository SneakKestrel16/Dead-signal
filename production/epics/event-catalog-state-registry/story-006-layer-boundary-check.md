# Story 006: Layer boundary check

> **Epic**: Event Catalog & State Registry
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

Unblocked 2026-10-13: ADR-0001..0008 Accepted. 

## Context

Dependencies must point down the layer map: Foundation and Core never reference Feature code. ADR-0005's composition root makes that possible but nothing enforces it yet ("no build check" in the traceability index). This story adds the check so a wrong reference fails a test instead of a review.

**GDD**: none
**Requirement**: `TR-index-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event Catalog, State Registry and Tick Order
**ADR Decision Summary**: The catalog lives in Foundation so Core modules (e.g. the Controller consuming `RoundEnded`, `PlayerConnectionChanged`) subscribe to the bus and never import Feature modules.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: None.

**Control Manifest Rules (this layer)**:
- Required: readers hold no reference to another module
- Forbidden: direct cross-system state writes [direct_cross_system_state_write]
- Guardrail: none specific

---

## Acceptance Criteria

*From `docs/architecture/architecture.md` dependency direction and TR-index-010, scoped to this story:*

- [ ] A test scans `src/` and fails when a Foundation or Core script references a Feature or Presentation class name or path.
- [ ] The check is shown to fail: a deliberate upward reference in a fixture makes it fail, and removing it makes it pass.
- [ ] The test runs in the CI workflow `.github/workflows/tests.yml`.

---

## Implementation Notes

*Derived from ADR-0005 and `architecture.md`:*

- Map layers to `src/` folders (e.g. `src/foundation/`, `src/core/`, `src/feature/`, `src/presentation/`); the check reads the map, not a hand list of classes.
- Match distinctive tokens (`class_name` identifiers, `res://src/feature/` paths), not substrings of common words.

---

## Out of Scope

- Moving existing code: there is none yet

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/event_catalog/layer_boundary_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (folder layout set by the composition root)
- Unlocks: None
