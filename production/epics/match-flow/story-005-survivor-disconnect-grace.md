# Story 005: Survivor disconnect, grace and reconnect

> **Epic**: Match Flow & Win Conditions
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

A survivor who drops keeps their place for `reconnect_grace_s`: their carried items drop at once, their character leaves the world, and they come back where they were, in the same state.

**GDD**: `design/gdd/match-flow.md`
**Requirement**: `TR-matchflow-005`, `TR-matchflow-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Hosting, session join and reconnect; secondary: ADR-0005
**ADR Decision Summary**: Listen server; session tokens; a dropped peer has a reconnect grace and resumes its player; host leaving ends the session with no result.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Builds on NA-3 disconnect detection and the session-token reconnect (ADR-0001); real ENet on loopback in tests.

**Control Manifest Rules (this layer)**:
- Required: implement `server_tick(tick)` and register with `TickRunner` in the `MATCH_FLOW_BEGIN` / `MATCH_FLOW_RESOLVE` slots; never rely on `_physics_process` (ADR-0002, ADR-0005)
- Forbidden: never emit an event from a client (ADR-0005); never let Match Flow tally other systems' stats or call into their modules (ADR-0011, Proposed)
- Guardrail: every tuning value comes from `MatchFlowKnobs` (`data/knobs/match_flow.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/match-flow.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] Disconnecting a survivor drops their carried items at once and removes their character; `PlayerConnectionChanged` (disconnect) is emitted (rule 19).
- [ ] Reconnecting within 60 s restores their position, Healthy/Downed state and down count; staying away 60 s counts them as eliminated for the win check and lists them "Disconnected".
- [ ] A Downed survivor who disconnects with 20 s of bleed-out left is Eliminated ("Bled out") 20 s later, while still disconnected; no reconnect is accepted after grace expires.

---

## Implementation Notes

- Match Flow owns the grace timer and `PlayerConnectionChanged`; Downing keeps the bleed-out running (Downing epic) — tests stand in for Downing by emitting `SurvivorEliminated`.
- Item drop is Survivor Objectives' rule; Match Flow only emits the disconnect event it reacts to.
- Every disconnect and reconnect is logged (rule 22) through the existing log path; telemetry is a later epic.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: the shapeshifter's disconnect
- Story 007: the full state a reconnecting client receives

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/match-flow/survivor-disconnect-grace_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004
- Unlocks: Story 007
