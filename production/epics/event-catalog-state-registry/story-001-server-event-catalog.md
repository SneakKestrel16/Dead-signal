# Story 001: ServerEvent base and the 15-event catalog

> **Epic**: Event Catalog & State Registry
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-13

Unblocked 2026-10-13: ADR-0001..0008 Accepted. 

## Context

Every cross-system fact in a round is one of 15 named events. This story builds the abstract base and one typed subclass per catalog event, each naming its single emitter, with a `project()` that for now returns the full payload or `{}`; per-event projection rules arrive with the network-authority epic (ADR-0004).

**GDD**: none (catalog in `design/gdd/systems-index.md` event table)
**Requirement**: `TR-index-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event Catalog, State Registry and Tick Order
**ADR Decision Summary**: `ServerEvent` is `@abstract`, extends `RefCounted`, carries `tick` and `server_time`, and declares `type() -> StringName` and `project(peer, handles) -> Dictionary`; each catalog event is `Ev<EventName>` with typed fields and its emitter named in the file header.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `@abstract` is 4.5+; put it on its own line above `class_name`. Verification results (1): constructing an abstract class by name is a parse error, but `load(path).new()` still instantiates at runtime, so construct only by class name. (2): a typed override missing a branch `return` fails to compile.

**Control Manifest Rules (this layer)**:
- Required: events are `ServerEvent` subclasses named `Ev<EventName>`, restating each parent return type, with a `return` on every branch
- Forbidden: broadcasting a raw payload [unprojected_client_event]; clients emitting events
- Guardrail: none specific

---

## Acceptance Criteria

*From ADR-0005 §1 and Validation Criteria, scoped to this story:*

- [x] All 15 events in the `systems-index.md` table exist as `Ev<EventName>` subclasses with names unchanged, each file header naming its emitter.
- [x] A test fails if any catalog subclass lacks `type()` or `project()`, or if the set of `type()` values differs from the 15 names.
- [x] `ServerEvent` cannot be constructed by class name (parse-time), and each override restates its return type.

---

## Implementation Notes

*Derived from ADR-0005 Decision and Implementation Guidelines:*

- `@abstract` on its own line above `class_name ServerEvent extends RefCounted`.
- Signature: `@abstract func project(peer: int, handles: HandleTable) -> Dictionary`; `{}` means the peer gets nothing. `HandleTable` is ADR-0004's; stub it with a minimal class until the network epic lands.
- A new event needs a `systems-index.md` row first.

---

## Out of Scope

- Story 002: the bus
- network-authority epic: real per-event projection rules (ADR-0004 projection table)

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-001-2026-10-12.md` (/qa-plan, 2026-10-12). Implement against these and the Acceptance Criteria above.*

**What to test**:
- The set of `type()` values over all `Ev*` classes equals the 15 names in the `systems-index.md` table.
- Each subclass implements `type()` and `project()`; each file header names an emitter.
- `project()` returns a `Dictionary` on every branch.

**Edge cases to cover**:
- A 16th or missing event fails the test (mutation check: add or remove a class in a fixture).

**Estimated test count**: ~4 unit tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/event_catalog/server_event_catalog_test.gd` — must exist and pass

**Status**: [x] `tests/unit/event_catalog/server_event_catalog_test.gd` — 12 tests; suite 37/37 pass (2026-10-13)

---

## Dependencies

- Depends on: None
- Unlocks: Stories 002, 005

---

## Completion Notes
**Completed**: 2026-10-13
**Criteria**: 3/3 met, one half not re-verified
- AC1: the catalog is 17 events, not 15 (`systems-index.md` has 17 rows; `FlinchRequested` and `ViewOffsetChanged` come from Proposed ADR-0015). All 17 exist as `Ev<EventName>` with the emitter in the header. ADR-0005 note, architecture.md, TR registry and traceability updated (AD-60).
- AC3 parse-time half: NOT re-verified this run (a scratch-script probe was declined). Evidence on file: ADR-0005 Verification result (1), `prototypes/adr-verification/README.md`. The runtime test checks that `@abstract` sits on its own line above `class_name`, and that every override restates its return type.
**Deviations** (advisory): event field names and types are inferred from the systems-index Meaning column (each header says so); `FormChanged` and `MonsterStunned` project `{}` (fail closed) until ADR-0004 projection is built; `ScareTriggered` reaches only its recipient; `HandleTable` is a placeholder; `FlinchRequested` and `ViewOffsetChanged` may change when ADR-0015 is accepted.
**Test Evidence**: Logic: `tests/unit/event_catalog/server_event_catalog_test.gd`; mutation-checked (renamed a `type()`, moved a file out, removed the `results` copy: each failed the suite).
**Code Review**: Complete (godot-gdscript-specialist and qa-tester, 2026-10-13); fixes in ceb840a.
