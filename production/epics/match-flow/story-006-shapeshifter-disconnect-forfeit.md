# Story 006: Shapeshifter disconnect and forfeit

> **Epic**: Match Flow & Win Conditions
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

If the shapeshifter drops, the round keeps running; if it does not come back within grace the survivors win by forfeit, unless an earned result comes first.

**GDD**: `design/gdd/match-flow.md`
**Requirement**: `TR-matchflow-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Hosting, session join and reconnect; secondary: ADR-0005
**ADR Decision Summary**: Listen server; session tokens; a dropped peer has a reconnect grace and resumes its player; host leaving ends the session with no result.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Real ENet on loopback in tests.

**Control Manifest Rules (this layer)**:
- Required: implement `server_tick(tick)` and register with `TickRunner` in the `MATCH_FLOW_BEGIN` / `MATCH_FLOW_RESOLVE` slots; never rely on `_physics_process` (ADR-0002, ADR-0005)
- Forbidden: never emit an event from a client (ADR-0005); never let Match Flow tally other systems' stats or call into their modules (ADR-0011, Proposed)
- Guardrail: every tuning value comes from `MatchFlowKnobs` (`data/knobs/match_flow.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/match-flow.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] Disconnecting the shapeshifter for more than 60 s ends the round as a survivor win, reason "Shapeshifter forfeited", on all clients; one that reconnects within 60 s appears at its disconnect position in true form (rule 20).
- [ ] Disconnecting the shapeshifter at 8:30 with no drives out ends the round at 9:00 as a monster win, reason "Evacuation deadline expired", not a forfeit.
- [ ] If the evidence escapes in the same tick the shapeshifter's grace expires, the survivors win by "Evidence escaped", not by forfeit (rule 16 order, outcome lock).

---

## Implementation Notes

- The forfeit is check (5) in story 002's order; this story supplies its input (grace expired).
- Cooldown, stun and immunity timers keep running while away (rule 20): those timers belong to Monster Abilities and Survivor Defense; their part of the GDD AC (stunned at 8:00.0, back at 8:10 with nothing left) is verified in their epics.
- True form on return: Borrowed Face owns the disguise reset; Match Flow only respawns.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Survivor Defense and Monster Abilities epics: timers running during the disconnect

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/match-flow/shapeshifter-disconnect-forfeit_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 002, 004
- Unlocks: None
