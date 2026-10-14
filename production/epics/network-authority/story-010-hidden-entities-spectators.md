# Story 010: Hidden entities, RPC paths, spectators and reconnect re-issue

> **Epic**: Network Authority & Replication
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

Unblocked 2026-10-13: ADR-0001..0008 Accepted. 

## Context

Things only some players may know about (undiscovered objectives, hallucinations, monster-only markers) are spawned hidden and granted per peer. No node name leaks identity. Spectators and reconnecting players get an entirely fresh handle set.

**GDD**: `design/gdd/survivor-objectives.md`, `design/gdd/scare-events.md`
**Requirement**: `TR-index-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication Scope and Information Hiding
**ADR Decision Summary**: Non-body hidden entities use `MultiplayerSpawner` + `MultiplayerSynchronizer` with `public_visibility = false` set before `spawn()` returns and `set_visibility_for` grants in the same frame; nodes named `E%d`; per-peer RPCs target one fixed-name node; spectators mirror the watched survivor's stream; a switch or reconnect discards the puppet map and re-issues every handle with a full snapshot.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification results (1) and (2) PASS: a never-granted peer receives nothing; the same-frame grant delivers. (5) the first RPC to a node sends its path, so node names are payload.

**Control Manifest Rules (this layer)**:
- Required: opaque counter names and identity-free spawn payloads; fixed-name RPC targets
- Forbidden: identifying node names [identifying_node_names]; RPCs on puppet nodes
- Guardrail: none specific

---

## Acceptance Criteria

*From ADR-0004 §7–9 and Validation Criteria, scoped to this story:*

- [ ] A hidden spawn granted to one client never reaches another (no node, no `spawned` signal).
- [ ] No node path sent to any client contains a player ID, peer ID, handle, role or character name.
- [ ] After a spectator switch and after a reconnect, the client's handle set is entirely new and its state matches the server's projection.

---

## Implementation Notes

*Derived from ADR-0004 Decision and Implementation Guidelines:*

- Puppet nodes are named by a client-local counter.
- Spectators receive the stream projected for the survivor they watch.

---

## Out of Scope

- HUD epic: spectator UI

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-004-2026-10-14.md` (/qa-plan, 2026-10-14). Implement against these and the Acceptance Criteria above.*

**Test file path**: `tests/integration/network/hidden_entities_test.gd`
**What to test**:
- A hidden spawn granted to one client never reaches another (no node, no `spawned` signal).
- No node path sent to any client contains a player ID, peer ID, handle, role or character name.
- After a spectator switch and after a reconnect, the client's handle set is entirely new and its state matches the server's projection.

**Edge cases to cover**:
- Grant in the same frame as `spawn()` (ADR-0004 §7 spawn order).

**Estimated test count**: ~6 integration tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/network/hidden_entities_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 002, 008
- Unlocks: None
