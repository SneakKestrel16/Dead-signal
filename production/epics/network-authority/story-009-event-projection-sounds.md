# Story 009: Event projection batches and positional sounds

> **Epic**: Network Authority & Replication
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

Unblocked 2026-10-13: ADR-0001..0008 Accepted. 

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

- [x] For each row of the ADR-0004 projection table, a survivor client and the shapeshifter client receive exactly the projected payload (`SurvivorHit`, `AbilityUsed` never reach survivors; bleed-out state never reaches the shapeshifter).
- [x] `PlayerShocked` is byte-identical for every case to a survivor client.
- [x] A footstep 1 m outside its radius reaches no peer; inside it carries position and sound set and no handle.

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

*From `production/qa/qa-plan-sprint-004-2026-10-14.md` (/qa-plan, 2026-10-14). Implement against these and the Acceptance Criteria above.*

**Test file path**: `tests/integration/network/event_projection_test.gd`
**What to test**:
- Every row of the ADR-0004 projection table: survivor and shapeshifter clients receive exactly the projected payload; `SurvivorHit` and `AbilityUsed` never reach survivors; bleed-out state never reaches the shapeshifter.
- `PlayerShocked` byte-identical for every case to a survivor client.
- A footstep 1 m outside its radius reaches no peer; inside it carries position and sound set, no handle.

**Edge cases to cover**:
- An event whose `project()` returns `{}` for every peer sends nothing (no empty batch).
- The NA-8 survivor capture test, extended to decode event batches, still finds no shapeshifter player ID.

**Estimated test count**: ~10 integration tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/network/event_projection_test.gd` — must exist and pass

**Status**: [x] Created, 20 tests passing; NA-8 capture test extended (suite 408/408)

---

## Dependencies

- Depends on: Story 008; event-catalog Stories 001, 002
- Unlocks: event-catalog Story 005

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: 3/3 passing.
- `tests/integration/network/event_projection_test.gd`: 20 tests.
- The NA-8 real-ENet survivor capture now emits monster events and sounds every tick, and decodes every event batch. It checks that no payload carries the monster's player ID, and that PlayerShocked and MonsterStunned do arrive.
- 19 mutations, each caught by a named test (run with gdUnit `-c`).

**Deviations and inferences** (AD-107):
- `ServerEvent.project(peer, handles, monster)`: the third argument is the shapeshifter's player ID, which is public. The ADR-0005 §1 and ADR-0004 §5 text is amended.
- SurvivorHit and AbilityUsed reach no client, the shapeshifter included. The table's shapeshifter column lists only FormChanged.
- BarricadeBroken is not sent as an event. The door state rides the PVS door, and the bang rides a positional sound.
- The shocked player gets `{own: true}`. Everyone else gets `{body: handle}`, the same shape whoever was shocked.
- `SurvivorDowned.bleed_out_s` is a new field (an inference: the table says "bleed-out state"). Nobody gets it before roles are dealt.
- `ObjectiveProgressChanged.discovered` defaults to false, so the point stays hidden if an owner forgets to set it.
- SurvivorRescued drops `rescuer`, because the table row allows only the survivor and life state.
- A sound skips its emitter, which plays its own steps locally. A sound exactly at its radius is heard.
- `EventBus.emit` stamps `tick` and `server_time` while a TickRunner drives the bus, unless the emitter set a tick (SR-1 deferred item).

**Deferred**:
- Spectators getting their watched survivor's batch: NA-10.
- The Borrowed Face footstep set: the caller passes the set, and the owner epic picks the target's set.
- Events that fire while a viewer is disconnected are lost. The rejoin resync of phase, roster and life states needs a story.
- Batches and snapshots on different channels are not ordered against each other. Client routing (event-catalog story 005) must tolerate a payload that names a handle with no puppet yet.
- `prediction_reconcile_test` (5 clients) failed once in a full run under load and passed alone and in the next two full runs.
