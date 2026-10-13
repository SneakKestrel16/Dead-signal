# Story 001: Host, join and join validation

> **Epic**: Network Authority & Replication
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-12
> **Last Updated**: [set by /dev-story when implementation begins]

BLOCKED: ADR-0001 is Proposed — accept with `/architecture-decision accept` once the two-PC real-network test passes.

## Context

A player hosts a listen server on a data-configured port and others join by address. Every join is validated in `auth_callback` before the peer is admitted; a rejected client must see why.

**GDD**: `design/gdd/lobby-role-assignment.md`
**Requirement**: `TR-lobby-001`, `TR-lobby-002`, `TR-config-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Hosting, Session Join and Reconnect
**ADR Decision Summary**: Listen server with a separable server role over ENet direct IP; `server_relay = false`; the client sends `{version, display_name, token}` via `send_auth`; the server checks size, decodes with `bytes_to_var`, type-checks, then validates version, name, lobby state and cap; it replies `{ok, player_id, token}` or `{ok: false, reason}` and disconnects a rejected peer after `reject_close_delay_s`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification results (2) `auth_timeout` default 3.0 s; (3) `server_relay` default true, so set false; (5) default bind accepts IPv4 and IPv6 loopback; (6) a reason sent immediately before `disconnect_peer` is lost, so the 0.2 s delay is required. Set `auth_callback`, `auth_timeout`, `server_relay` before assigning `multiplayer_peer`.

**Control Manifest Rules (this layer)**:
- Required: decode auth payloads with `bytes_to_var` after size and type checks; network values from data
- Forbidden: `bytes_to_var_with_objects`; client-to-client relay [client_to_client_relay]
- Guardrail: auth is one round trip per join

---

## Acceptance Criteria

*From ADR-0001 §1–3, §7 and Validation Criteria; `lobby-role-assignment.md` AC-LB-02, AC-LB-03, AC-LB-04, AC-LB-29, scoped to this story:*

- [ ] Joins are rejected with `lobby_full` at the cap, `round_in_progress` during In Match (except a known token in grace), `version_mismatch` (both strings shown) and `bad_name`; a valid join receives a player ID.
- [ ] A rejected client shows the reason text in 20 of 20 attempts with the 0.2 s delay.
- [ ] A malformed or oversized auth payload is rejected with `bad_payload` without decoding objects.
- [ ] `create_server` failing (port in use) shows the error and leaves nothing half-initialised; the server role starts and runs with no local player (headless).

---

## Implementation Notes

*Derived from ADR-0001 Decision and Implementation Guidelines:*

- `NetAuthority` API: `host(port) -> Error`, `join(address, port, display_name) -> Error`, signals `join_rejected(reason)`, `host_failed(error)`.
- ENet `max_clients` above `max_players` so a reconnect can arrive while the stale peer exists; `auth_callback` enforces the real cap.
- `display_name` length 1–16 after stripping control and bidirectional-override characters.
- Port, headroom, `auth_timeout`, payload cap, `reject_close_delay_s` from `NetKnobs`.
- The version string includes the knob digest (data-config story 005).

---

## Out of Scope

- Story 002: tokens and reconnect
- data-config story 005: the digest itself

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-001-2026-10-12.md` (/qa-plan, 2026-10-12). Implement against these and the Acceptance Criteria above.*

**What to test**:
- Two local instances: valid join gets a player ID.
- Rejections with `lobby_full`, `round_in_progress`, `version_mismatch` (both strings), `bad_name`, `bad_payload`.
- Reason arrives in 20 of 20 rejects with the 0.2 s delay.
- `create_server` on a used port → error shown, nothing half-initialised.
- Server role runs headless with no local player.

**Edge cases to cover**:
- Name of 0 and 17 characters; name with control or bidi-override characters stripped to empty.
- Oversized auth payload rejected before decoding.

**Estimated test count**: ~8 integration tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/network/host_join_auth_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: data-config Story 001
- Unlocks: Stories 002, 003, 004
