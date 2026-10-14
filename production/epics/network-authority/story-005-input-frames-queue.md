# Story 005: Input frames and the server input queue

> **Epic**: Network Authority & Replication
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-13

Unblocked 2026-10-13: ADR-0001..0008 Accepted. 

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

- [x] A malformed packet (mismatched lengths, more than 3 frames, NaN, `seq` beyond `max_seq_ahead`) changes nothing and is logged.
- [x] Duplicate and out-of-order `seq` values are dropped; `move` is clamped to length 1 and pitch to ±85°.
- [x] Under starvation the last frame repeats; after `intent_timeout_ms` input is treated as released (counted in ticks via `Knobs.ticks`).
- [x] Backlog above target + 1 consumes two frames per tick; target depth rises and falls with the starvation thresholds; the cap drops the oldest.

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

*From `production/qa/qa-plan-sprint-001-2026-10-12.md` (/qa-plan, 2026-10-12). Implement against these and the Acceptance Criteria above.*

**What to test**:
- Valid packet of 3 frames enqueues new `seq` values only.
- Clamp `move` to length 1 and pitch to ±85°.
- Starvation repeats the last frame; after `intent_timeout_ms` (in ticks) input is released.
- Backlog > target + 1 consumes two per tick; target rises above `starvation_high`, falls below `starvation_low`; cap drops oldest.

**Edge cases to cover**:
- Mismatched array lengths, 4 frames, NaN or Inf in any float, `seq` beyond `max_seq_ahead` → packet dropped and logged, queue unchanged.
- Duplicate and out-of-order `seq`.
- Empty packet.

**Estimated test count**: ~10 unit tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/network/input_queue_test.gd` — must exist and pass

**Status**: [x] `tests/unit/network/input_queue_test.gd` — 28 tests; suite 97/97 pass (2026-10-13)

---

## Dependencies

- Depends on: Story 004
- Unlocks: Story 006

---

## Completion Notes
**Completed**: 2026-10-13
**Criteria**: 4/4 passing, each covered by gdUnit4 tests (28 tests, 0 failures, 0 orphans)
**Deviations** (advisory):
- Four knobs had no number anywhere and were added as inferences (AD-61): `input_queue_cap` 8, `max_seq_ahead` 16, `starvation_high` 0.10, `starvation_low` 0.02. To retune in the real-network list.
- Seq window grows by the queue's empty ticks (AD-62), so a stall longer than `max_seq_ahead` ticks recovers; ADR-0002 §4 states the strict rule and needs an amendment note.
- The queue never asserts or `push_error`s on bad input (remote peers must not trip asserts); it counts drops and keeps the first 32 violation messages.
- Double-consume returns the later frame; a one-frame edge only in the earlier frame is lost (`ponytail:` comment).
- One `InputQueue` per player; the per-player map and RPC wiring are later stories. `ack_snapshot_tick`, `view_epoch`, `offset_tick`, `record_id` fields not implemented yet.
**Test Evidence**: Logic: `tests/unit/network/input_queue_test.gd`; mutation-checked (finite check removed; cap drops newest; always consume one: each failed).
**Code Review**: Skipped (lean mode). The seq-window code was read by the orchestrator; the rest of the queue was not reviewed line by line, and no specialist or QA review ran.
