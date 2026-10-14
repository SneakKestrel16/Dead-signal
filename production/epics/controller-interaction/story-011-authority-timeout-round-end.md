# Story 011: Server authority, input timeout and round-end freeze

> **Epic**: First-Person Controller & Interaction
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Clients send intent, nothing else. A stalled connection must not keep a player moving or holding, and the round end stops everything on one tick.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-001`, `TR-controller-008`, `TR-controller-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Authoritative simulation, tick and input (primary); ADR-0008: Hold-to-interact protocol
**ADR Decision Summary**: The server owns positions and progress; after `intent_timeout_ms` (500) without frames input is released, holds cancel, movement stops; a player found inside geometry is restored to the last valid position. ADR-0008 §3: release cancels the hold.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Timeouts are counted in ticks via `Knobs.ticks` (data-config story 001).

**Control Manifest Rules (this layer)**:
- Required: restore a player found inside geometry to the last valid position
- Forbidden: client-sent position, velocity, speed or progress [client_sent_position]; client hold completion [client_hold_complete]

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (Authority; RoundEnded), scoped to this story:*

- [ ] A modified client sending a position, a speed above 5.75 m/s, a hold-progress value or a "done" message leaves server position, speed and hold progress unchanged, and no completion fires.
- [ ] A player moving and Holding with no intent for 500 ms stops and has the hold cancelled under the owner's cancel rule on the first tick after 500 ms (±1 tick); at 450 ms neither has happened.
- [ ] A player found inside geometry is at their last valid position on the next tick.
- [ ] On `RoundEnded` all movement stops, every hold cancels and further intent is ignored on that tick; `PlayerConnectionChanged` (dropped) cancels that player's hold.

---

## Implementation Notes

*Derived from ADR-0002 §4–6 and ADR-0008 §3:*

- The input queue already releases input after the timeout (network-authority story 005); this story asserts the controller and hold consequences.
- Out-state body removal and the spectator view belong to Match Flow; assert only the collision and movement part (Story 001).

---

## Out of Scope

- Spectator view (Match Flow epic)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/first-person-controller/controller_authority_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 002, 008; network-authority story 005
- Unlocks: Match Flow epic
