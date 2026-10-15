# Story 005: ClientEventRouter

> **Epic**: Event Catalog & State Registry
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

Unblocked 2026-10-13: ADR-0001..0008 Accepted. Also needs the network-authority projection story.

## Context

Clients never see `ServerEvent` objects: they receive projected per-peer batches and route each payload by type to presentation modules (HUD, audio, lighting).

**GDD**: none
**Requirement**: `TR-index-001`, `TR-index-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event Catalog, State Registry and Tick Order; secondary ADR-0004 (projection, per-peer batches)
**ADR Decision Summary**: A `ClientEventRouter` receives ADR-0004's projected per-peer batches and dispatches each payload by its type to client presentation modules; clients never construct `ServerEvent` objects.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Per-peer RPCs target fixed-name nodes (ADR-0004 §7a).

**Control Manifest Rules (this layer)**:
- Required: per-peer RPCs target fixed-name nodes; client-bound payloads name bodies by per-peer handle
- Forbidden: clients emitting events; identifying node names [identifying_node_names]
- Guardrail: none specific

---

## Acceptance Criteria

*From ADR-0005 §7, scoped to this story:*

- [x] A batch with payloads of three types reaches the presentation handlers subscribed to each type, in batch order.
- [x] A payload of an unknown type is dropped and logged; it does not stop the rest of the batch.
- [x] No client code path constructs a `ServerEvent` (test greps client scripts).

---

## Implementation Notes

*Derived from ADR-0005 Decision and ADR-0004 Implementation Guidelines:*

- The router lives on the fixed-name round root on the client; batches arrive on the reliable event channel (ADR-0002 §3).
- Handlers register by type `StringName`, the same names as the catalog.

---

## Out of Scope

- network-authority epic: building and sending the projected batches

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/unit/event_catalog/client_event_router_test.gd` — must exist and pass

**Status**: [x] `tests/unit/event_catalog/client_event_router_test.gd` (8 tests)

---

## Dependencies

- Depends on: Story 001; network-authority projection story
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: all passing (automated)
**Deviations** (AD-136):
- Implemented by network-programmer in a git worktree (parallel wave); squash-merged by the orchestrator.
- `ClientEventRouter` (`src/foundation/events/client_event_router.gd`) listens only to server-peer event batches; `subscribe(type, handler)` accepts catalog names or `EventBatch.SOUND`; unknown types are skipped, counted in `dropped` and warned once; undecodable batches count in `rejected`.
- `CATALOG` is a second hard-coded name list (client code may not construct event classes); a test checks it against every `ev_*.gd`.
- "Client scripts" for AC 3 is inference: any `src` script that decodes event batches or uses the router; a project-wide client/server marker would settle it.
- Test in `tests/unit/event_catalog/` (no ENet), not the story's integration path. Wiring the router into a client round root and replacing MatchDisplay's own decoding are later work.
**Test Evidence**: `tests/unit/event_catalog/client_event_router_test.gd`, 8 tests. Mutations caught: stop on unknown type, server-peer check removed, an Ev constructed in the router.
**Code Review**: Complete (orchestrator review)
