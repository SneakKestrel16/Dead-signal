# Story 005: Input frames and the server input queue

> **Epic**: Network Authority & Replication
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-12
> **Last Updated**: [set by /dev-story when implementation begins]

BLOCKED: ADR-0002 is Proposed — accept with `/architecture-decision accept` once the two-PC real-network test passes.

## Context

Clients send intent, never position. Each tick a client sends its last 3 input frames unreliably; the server validates them and feeds one (sometimes two) per tick from an adaptive queue.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-index-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Authoritative Simulation, Tick and Input
**ADR Decision Summary**: Unreliable RPC with packed arrays `seq`, `move`, flags, `yaw`, `pitch` (+ ADR-0003 `view_tick`, `ack_snapshot_tick`; ADR-0008 `interact`, target); discrete intents go reliably with their frame's `seq`; three transfer channels; the queue drops invalid packets, clamps, adapts target depth 1–2, repeats the last frame on starvation, releases input after `intent_timeout_ms`, and caps at `input_queue_cap`; the host enqueues at depth 0.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification results (1): a lost reliable packet held back no unreliable traffic; three channels stay as isolation. Packed arrays over unreliable RPC exercised by the spike.

**Control Manifest Rules (this layer)**:
- Required: validate lengths, the 3-frame limit and finiteness before reading; separate channels; queue values from data
- Forbidden: client-sent position, velocity, speed or progress [client_sent_position]; reading the host's input directly [host_input_shortcut]
- Guardrail: client upload about 40 kbps

---

## Acceptance Criteria

*From ADR-0002 §3–4 and Validation Criteria, scoped to this story:*

- [ ] A malformed packet (mismatched lengths, more than 3 frames, NaN, `seq` beyond `max_seq_ahead`) changes nothing and is logged.
- [ ] Duplicate and out-of-order `seq` values are dropped; `move` is clamped to length 1 and pitch to ±85°.
- [ ] Under starvation the last frame repeats; after `intent_timeout_ms` input is treated as released (counted in ticks via `Knobs.ticks`).
- [ ] Backlog above target + 1 consumes two frames per tick; target depth rises and falls with the starvation thresholds; the cap drops the oldest.

---

## Implementation Notes

*Derived from ADR-0002 Decision and Implementation Guidelines:*

- `InputQueue.push(frames)`, `next(tick) -> InputFrame`; `InputFrame` fields per ADR-0002 Key Interfaces.
- Pack the flags byte whole each frame (4.7 packed-array setter change).
- The host's player uses the same queue at depth 0 with no prediction.

---

## Out of Scope

- Story 006: movement and reconciliation

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/network/input_queue_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004
- Unlocks: Story 006
