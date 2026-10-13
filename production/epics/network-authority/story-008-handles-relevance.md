# Story 008: Per-peer handles and relevance

> **Epic**: Network Authority & Replication
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

Unblocked 2026-10-13: ADR-0001..0008 Accepted. 

## Context

A survivor's client must never be able to tell which body is the monster. Bodies reach each peer under random per-peer handles, only while relevant by the authored room visibility sets, and a disguise that leaves and returns comes back as a stranger.

**GDD**: `design/gdd/borrowed-face.md`, research facility visibility sets
**Requirement**: `TR-index-003`, `TR-index-005`, `TR-index-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication Scope and Information Hiding
**ADR Decision Summary**: Bodies only through per-peer snapshots; random 32-bit handles per peer (0 reserved) introduced and retired reliably; fresh handle on re-entry; kept on an in-view form change; retired on a form change during linger; relevance = authored PVS of the viewer's volume or within 6 m, with 0.5 s linger, doors pruning sets; hidden survivors never relevant to the monster.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Snapshot packet sizes per ADR-0002 Verification (6). Relevance computed in the TickRunner send phase.

**Control Manifest Rules (this layer)**:
- Required: introduce a handle before any use; relevance values and visibility sets from data
- Forbidden: shapeshifter player ID or stable body ID in client payloads [shapeshifter_id_in_client_payload]; stable per-round handles
- Guardrail: about 200 bytes per peer per snapshot (estimate)

---

## Acceptance Criteria

*From ADR-0004 §2–4 and Validation Criteria, scoped to this story:*

- [ ] A disguised monster out of a survivor's PVS for 1 s, then back in view, arrives under a handle the client has never seen.
- [ ] A form change during linger retires the handle on that peer; a form change in view keeps it.
- [ ] A snapshot entry with an unintroduced handle is ignored by the client.
- [ ] A survivor's capture over a full scripted round contains no shapeshifter player ID outside roster, feed and results messages.

---

## Implementation Notes

*Derived from ADR-0004 Decision and Implementation Guidelines:*

- Per-peer handle table owned by Network; ADR-0008 body targets resolve through it.
- Closed or barricaded doors remove the volumes behind them; door and barricade state replicates under the same rule.
- Visibility sets are Facility Map data; use a test map until the facility exists.

---

## Out of Scope

- Story 009: event projection
- Story 010: spectators and reconnect re-issue

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/network/handles_relevance_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006
- Unlocks: Stories 009, 010
