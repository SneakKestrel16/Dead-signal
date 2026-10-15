# Story 013: Lobby countdown starts the composed round; round end returns to the lobby

> **Epic**: Match Flow & Win Conditions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

The lobby screen (lobby-role-assignment 005) stops at "Starting": its own header says the round start after the countdown is not wired. The composed round (story 010) and the client round scene (story 011) exist but only `tests/manual/round_host.gd` and `round_view` start them. A player cannot play a round from the shipped build. ADR-0001 picks a listen server with the server role kept separate from the host's local player.

**GDD**: `design/gdd/match-flow.md` rules 1, 2, 17, 27; lobby-role-assignment rules 9, 17, 19
**Requirement**: `TR-match-001`, `TR-lobby-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Network topology and session; secondary: ADR-0005, ADR-0011
**ADR Decision Summary**: Listen server, with the server role separate from the host's local player; joins validated in auth_callback; session token rebinds a reconnecting player.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: the server role stays separable from the host's local player (headless dedicated build stays possible)
- Required: clients decide nothing; the round starts only on the server's roster lock
- Forbidden: a second ENet session for the round when the lobby session can carry it, unless the ADR says otherwise

---

## Acceptance Criteria

*From GDD `design/gdd/match-flow.md`, scoped to this story:*

- [x] When the lobby countdown completes on the host, the host composes the round with `RoundComposer` over the locked roster, and every lobby client loads the client round scene and reports its map loaded, over real ENet with at least 3 clients.
- [x] When the round reaches Results and `results_duration_s` elapses, every client returns to the lobby with the same session (no re-join), Ready cleared, and the rotation queue advanced as the lobby rules say.
- [x] A host quit during the round returns every client to the boot scene with "Host left" (`Main.return_with`), and a cancelled round (load timeout) returns everyone to the lobby with the queue not advanced.
- [x] The shipped build can be played end to end: two windowed instances on one PC, one hosting and one joining, reach a round and come back to the lobby (retained screenshot of each step in `production/qa/evidence/lobby-to-round-wiring/`).

---

## Implementation Notes

- Read `tests/manual/round_host.gd` and `round_view.gd` first: they already compose and join a round; lift what they do into the shipped scenes rather than re-deriving it.
- Keep the server part a node the host adds beside its local player, so a dedicated build can run it alone.
- The Results screen itself is hud-results story 009; until it lands, the client shows the existing greybox results text, and this story only wires the transitions.
- Two-instance capture: use ports 31000-31099 and stop every process you start.

---

## Out of Scope

- The Results screen UI (hud-results 009).
- Matchmaking or a server browser.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/match-flow/lobby_to_round_wiring_test.gd` (real ENet where the AC names clients)

**Status**: [x] tests/integration/match-flow/lobby_to_round_wiring_test.gd (4); production/qa/evidence/lobby-to-round-wiring/ (8 png)

---

## Dependencies

- Depends on: Stories 010, 011; lobby-role-assignment 005
- Unlocks: hud-results 009, 010

## Progress Notes (2026-10-15)

Merged b911999+ecf416a. RoundHost (node "Round", no local player; dedicated-build ready) composes the round on roster lock in its own hidden physics world, hands disconnects to the round, signals round_over; finish() returns the lobby to Waiting and drops gone players (reading of lobby rule 18). RoundClient adopt(net) plays over the lobby connection; LobbyScreen starts the round view on In Match and returns to the room on Waiting; host quit leaves with "Host left". DEVIATIONS: the host player joins through a local "seat" client on 127.0.0.1 with its token (the one second ENet session; the lobby session cannot carry the host own player), kicked at round end; shipped code uses TestMoveStep until the real movement step ships; results line is MatchDisplay text until HUD-8. Previous composer kept alive until the next round (a mid-tick Cancel crashed otherwise). 4 integration tests (real ENet, host + 3 clients); 3 mutations caught. Full suite 1437/1437. AC-4: two windows + two headless joiners, shipped knobs, round to its 540 s deadline and back; host/ and client/ lobby, round, results, back png. Orchestrator note: the boot status label stays on top during the round (visible in client/round.png).
