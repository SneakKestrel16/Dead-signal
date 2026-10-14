# Story 002: Session tokens and reconnect rebinding

> **Epic**: Network Authority & Replication
> **Status**: In Progress
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

Unblocked 2026-10-13: ADR-0001..0008 Accepted. 

## Context

Identity in a round is a server-assigned player ID, bound to a secret token. A player who drops and returns inside the grace window rebinds to the same ID, even if the old connection has not timed out yet.

**GDD**: `design/gdd/lobby-role-assignment.md`, `design/gdd/match-flow.md`
**Requirement**: `TR-lobby-002`, `TR-index-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Hosting, Session Join and Reconnect
**ADR Decision Summary**: First join issues a 16-byte hex token, sent only to its owner, mapping to a stable player ID; all state is keyed by player ID; a known token in grace rebinds to the new peer, evicting a still-connected old peer without a dropped notification, then re-applies per-peer visibility and sends a full snapshot before any delta.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification results (4) `Crypto.generate_random_bytes` PASS.

**Control Manifest Rules (this layer)**:
- Required: key all state by player ID; on rebind re-apply visibility and send a full snapshot before any delta
- Forbidden: peer ID as identity outside `NetAuthority` [peer_id_as_identity]; sending, logging or showing a token
- Guardrail: one full snapshot burst per reconnect

---

## Acceptance Criteria

*From ADR-0001 §4–5 and Validation Criteria; `lobby-role-assignment.md` AC-LB-18, AC-LB-28, scoped to this story:*

- [ ] A reconnect while the old peer is still connected evicts the old peer, raises no dropped notification, and leaves the queue position unchanged.
- [ ] After rebind the new peer gets a full snapshot before any delta, and visibility-filtered entities reappear on it.
- [ ] A packet capture on a non-owner client contains no other player's token.

---

## Implementation Notes

*Derived from ADR-0001 Decision and Implementation Guidelines:*

- `player_id_of(peer_id)` and `peer_id_of(player_id)` return -1 when unbound.
- Signals `player_joined`, `player_dropped` (never for an evicted stale peer), `player_rejoined(player_id, new_peer_id)`.
- Re-applying visibility uses `MultiplayerSynchronizer.set_visibility_for` with the new peer ID; handle re-issue is story 010.

---

## Out of Scope

- Story 003: drop detection and grace timing
- Story 010: handle re-issue on reconnect

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-002-2026-10-13.md` (/qa-plan, 2026-10-13). Implement against these and the Acceptance Criteria above.*

**What to test**:
- Reconnect with a known token while the old peer is still connected: the old peer is evicted with `disconnect_peer`, `player_dropped` is not raised for it, `player_rejoined(player_id, new_peer)` is raised once, and the queue position is unchanged.
- After the rebind, the new peer gets a full snapshot before any delta (record the message order at the peer), and entities filtered by visibility reappear on it.
- Token secrecy: record every byte sent to a non-owner peer (raw SceneMultiplayer client, as in `host_join_auth_test.gd`) and assert that no other player's token string appears in it.

**Edge cases to cover**:
- Reconnect after the grace period: rejected with `round_in_progress`.
- Reconnect with an unknown token: treated as a new join, so Countdown and In Match reject it.
- Two reconnects with the same token at once: one wins and the other is rejected.
- The old peer drops in the same frame the new one authenticates.

**Estimated test count**: ~8 integration tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/network/tokens_reconnect_test.gd` — must exist and pass

**Status**: [x] `tests/integration/network/tokens_reconnect_test.gd` passes (9 tests, 3 runs); full suite 150/150, 0 orphans (2026-10-14)

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 003
