# Story 009: Event projection batches and positional sounds

> **Epic**: Network Authority & Replication
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-12
> **Last Updated**: [set by /dev-story when implementation begins]

BLOCKED: ADR-0004 and ADR-0005 are Proposed — accept with `/architecture-decision accept` once the two-PC real-network test passes.

## Context

Each tick's delivered events are projected per peer and sent as one reliable batch. Sounds travel as positional events with no handle, only to peers in range.

**GDD**: `design/gdd/systems-index.md` event table
**Requirement**: `TR-index-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication Scope and Information Hiding; secondary ADR-0005
**ADR Decision Summary**: Network batches the tick's projected events into one reliable message per peer on the event channel; payloads name bodies by handle and players by ID only for public facts; the projection table decides what each role gets; footsteps, distortion, lunge cues, bangs and callouts are positional events within their radius.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Per-peer RPCs target the fixed-name round root (ADR-0004 §7a).

**Control Manifest Rules (this layer)**:
- Required: every catalog event implements `project`; sounds are positional events with no handle
- Forbidden: broadcasting raw payloads [unprojected_client_event]
- Guardrail: none specific

---

## Acceptance Criteria

*From ADR-0004 §5–6, scoped to this story:*

- [ ] For each row of the ADR-0004 projection table, a survivor client and the shapeshifter client receive exactly the projected payload (`SurvivorHit`, `AbilityUsed` never reach survivors; bleed-out state never reaches the shapeshifter).
- [ ] `PlayerShocked` is byte-identical for every case to a survivor client.
- [ ] A footstep 1 m outside its radius reaches no peer; inside it carries position and sound set and no handle.

---

## Implementation Notes

*Derived from ADR-0004 Decision and Implementation Guidelines:*

- Collect events with `EventBus.take_tick_events()`, call `project(peer, handles)` per peer, drop `{}`.
- A disguised monster's footsteps use the target's footstep set (Borrowed Face).

---

## Out of Scope

- event-catalog Story 005: client routing

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/network/event_projection_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 008; event-catalog Stories 001, 002
- Unlocks: event-catalog Story 005
