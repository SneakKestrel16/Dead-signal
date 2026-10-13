# Story 001: ServerEvent base and the 15-event catalog

> **Epic**: Event Catalog & State Registry
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-12
> **Last Updated**: [set by /dev-story when implementation begins]

BLOCKED: ADR-0005 is Proposed — accept it with `/architecture-decision accept ADR-0005` once decided.

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

- [ ] All 15 events in the `systems-index.md` table exist as `Ev<EventName>` subclasses with names unchanged, each file header naming its emitter.
- [ ] A test fails if any catalog subclass lacks `type()` or `project()`, or if the set of `type()` values differs from the 15 names.
- [ ] `ServerEvent` cannot be constructed by class name (parse-time), and each override restates its return type.

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

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/event_catalog/server_event_catalog_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Stories 002, 005
