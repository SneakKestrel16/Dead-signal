# Story 004: Refuse to host on bad knobs; freeze per round

> **Epic**: Data/Config Loader
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-12
> **Last Updated**: [set by /dev-story when implementation begins]

BLOCKED: ADR-0006 is Proposed — accept it with `/architecture-decision accept ADR-0006` once decided. Also needs `NetAuthority.host()` from the network-authority epic.

## Context

A validation error must be visible at once: the game refuses to host and lists every error. Once a round starts, its knobs never change; a debug reload applies at the next round start.

**GDD**: none
**Requirement**: `TR-config-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Data-Driven Configuration (Knobs); secondary ADR-0005 (composition root passes knobs through `setup()`)
**ADR Decision Summary**: Any error means the game refuses to host and shows the list; debug builds also assert. The composition root takes the loaded `Knobs` at round start and passes it to every module's `setup()`; modules never write it; debug `reload` applies at the next round start.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: None beyond story 001.

**Control Manifest Rules (this layer)**:
- Required: a validation error refuses to host; modules receive services through `setup()`
- Forbidden: runtime knob writes [knob_write]; gameplay autoload services [gameplay_autoload_service]
- Guardrail: none specific

---

## Acceptance Criteria

*From ADR-0006 §4, §5 and Validation Criteria, scoped to this story:*

- [ ] An out-of-range value, a missing value and a broken cross-knob rule each block hosting and show the error by name in the host UI.
- [ ] A debug `reload` during a round changes nothing in that round; the next round uses the reloaded values.
- [ ] Modules hold the round's `Knobs` from `setup()`; no gameplay code writes a knob field (test greps for assignments to `knobs.`).

---

## Implementation Notes

*Derived from ADR-0006 Decision and Implementation Guidelines:*

- Host flow: `Knobs.load_all()` → if `errors()` non-empty, show the list and do not call `create_server`.
- Debug builds also `assert` on errors; release builds only refuse.
- The composition root (ADR-0005) owns the frozen reference for the round.

---

## Out of Scope

- Story 005: the digest and version string

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/data_config/refuse_to_host_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001, Story 003; network-authority host story
- Unlocks: None
