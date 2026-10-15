# SR-1: Retroactive Sprint 1 Code Review

**Date**: 2026-10-14
**Task**: SR-1 (Sprint 4 Must Have; Sprint 1 QA condition 2, carried three sprints)
**Method**: `/code-review` pattern. Three reviewers read the Sprint 1 code:
- `godot-gdscript-specialist`, network files.
- `godot-gdscript-specialist`, foundation, events and data-config files.
- `qa-tester`, the tests of all 9 Sprint 1 stories.

The orchestrator checked every finding against the code. Each fixed finding has a regression test that was watched failing, either against the unfixed code or against a mutation that removed the fix.
**Result**: 351/351 tests pass (baseline 337). `src/main.tscn` boots headless with `boot ok: knob problems=0`.

## Files reviewed

| Area | Files |
|---|---|
| Network (NA-1, NA-4, NA-5) | `src/foundation/network/input_queue.gd`, `input_frame.gd`, `net_authority.gd`, `tick_runner.gd` |
| Events (EC-1 to EC-4) | `src/foundation/events/event_bus.gd`, `server_event.gd`, all `ev_*.gd`, `src/foundation/state_registry.gd`, `round_server.gd`, `tick_order.gd`, `feature_step.gd`, `state_keys.gd` |
| Data config (DC-1, DC-2) | `src/foundation/data_config/knob_validator.gd`, `knobs.gd`, `knob_unset.gd`, all `*_knobs.gd` sections |
| Tests | the test files of the 9 Sprint 1 stories (data-config 001-002, event-catalog 001-004, network 001, 004, 005) |

## Findings fixed

| Sev | Finding (verified) | Fix | Regression test |
|---|---|---|---|
| S2 | `InputQueue.next()` consumed 2 frames whenever the backlog exceeded target + 1. A client sending fresh seqs every tick moved at double speed, with no limit. | Catch-up credit: one credit per starved tick, capped at `input_queue_cap`. Each two-frame tick spends one credit. | `input_queue_test.gd` `test_flooding_two_frames_per_tick_never_runs_faster_than_the_clock` (the unfixed queue consumed 719 frames in 360 ticks), `test_catch_up_credit_is_capped_so_a_long_stall_buys_no_sprint` |
| S2 | `EvAbilityUsed` and `EvSurvivorHit` projected their fields to every peer. ADR-0004 §5 says they are never sent to survivors. `EvFlinchRequested` and `EvViewOffsetChanged` also went to every peer, though they are for one player only. All four were latent: nothing sends events yet. | All four fail closed (`{}`), as `FormChanged` already did. NA-9 adds per-role projection. | `server_event_catalog_test.gd` `test_secret_and_owner_only_events_reach_no_peer_yet` |
| S2 | `core.max_flush_rounds` had no range. A value of 0 loaded clean, and every flush then overflowed before delivering any event. | `@export_range(1, 64)`. The 1 follows from the code. The 64 is an inference: ADR-0005 names the value 8 but gives no range. | `knob_section_validation_test.gd` `test_max_flush_rounds_zero_is_rejected` |
| S3 | Unranged float knobs accepted INF. | `KnobValidator` rejects any non-finite float, ranged or not. | `test_infinite_float_without_a_range_is_rejected` |
| S3 | `_server_auth` ran again for a second auth packet from the same peer. It minted a second player ID and token and orphaned the first. The engine does deliver the second packet; it then refuses the second reply, so only the skipped ID shows the bug. | Ignore a peer that is pending or already joined. | `host_join_auth_test.gd` `test_second_auth_packet_from_a_pending_peer_is_ignored` |
| S3 | `TickRunner.step()` called `server_tick` on a freed module, which crashed the tick. A module that registered another module mid-loop also re-sorted the list (S4). | The loop iterates over a copy. A freed module is dropped and recorded as a violation. | `tick_runner_test.gd` `test_freed_module_is_dropped_with_a_violation_and_the_rest_still_run` |
| S3 | `RoundServer.end_round()` called `free()` on the TickRunner while it was mid-step, when a module ended the round. | `queue_free()`. | `round_teardown_test.gd` `test_end_round_from_inside_a_tick_does_not_free_the_running_runner` |
| S3 | `RoundServer.start_round()` never checked `knobs.errors()`. A missing `core.tres` crashed it. | Returns `knobs.errors()` and starts no round when the list is not empty. | `test_start_round_with_broken_knobs_refuses_and_starts_nothing` |
| S3 | A handler that called `bus.clear()` mid-flush did not stop the batch. The remaining events were still delivered and collected. | `clear()` sets a flag, and `flush()` stops when it is set. | `test_clear_inside_a_handler_stops_the_flush` |

The existing test `tick_order_test.gd` `test_end_round_leaves_nothing_alive_and_no_orphans` now awaits one frame, because the queued free completes at frame end. Its orphan check is now `<=` the baseline: during that frame, gdUnit also frees orphans that existed before the baseline was read. The count went from 4 to 1, so nothing leaked.

## Test gaps closed

| Gap (qa-tester) | Test added; watched failing against |
|---|---|
| `ticks()` at 0.5 s and 60 Hz is exactly 30, so truncation also passed | `test_ticks_rounds_half_a_tick_up_not_down`, against `int()` |
| The typed-return check accepted any function returning `Dictionary` | `test_each_override_restates_return_types` now matches `func project(...)`, against an untyped `project` |
| The intent timeout was tested only at 60 Hz | `test_timeout_follows_the_tick_rate` (30 Hz, 15 ticks), against a hard-coded 30 |
| Every test called `step()` directly, so `_physics_process` was never exercised | `test_physics_frames_drive_the_tick`, against a `_physics_process` that does not step |

## Filed

- **BUG-0002** (S3): unranged int and alpha knobs, for example `net.port = -1`, load clean. The fix needs sourced ranges.

## Deferred or not fixed (S4 and test gaps)

| Item | Disposition |
|---|---|
| `_empty_ticks` grows without bound and widens the seq window | Self-inflicted only: a client that jumps ahead drops its own frames. No fix. |
| An unbounded yaw (3e38) is accepted | Yaw is only used through sin and cos. Wrap it if a consumer ever stores it. |
| Names made only of invisible characters pass `sanitize_name` | Moved to the lobby name-display work. `sanitize_name` already strips control characters. |
| The stale-session guard compares the same SceneMultiplayer object | It works only through a peer-id collision. Revisit with NA-10 or the reconnect work. |
| `close()` keeps `_next_player_id`, `_join_token` and `_display_name` | Harmless for one session per process. Revisit if one process hosts twice. |
| `server_time()` before `boot()` divides by zero | Every caller boots first. |
| `EventBus.emit` never stamps `tick` or `server_time` (ADR-0005 §1) | NA-9 stamps them when events are first sent. |
| `_collected` grows without bound if nobody takes the events | `take_tick_events` is called every tick by the snapshot phase once NA-9 lands. |
| `ServerEvent.new()` is checked only by source text, not by compiling it | Still open; low value. |
| The fail_hard assert paths are never run (bus, registry) | By design: an assert in a test aborts the run. |
| The `*_view.gd` scan is vacuous: no view files exist yet | The check bites once the first view lands. |
| Event-catalog AC1 says 15 events; the test lists 17 | The two events were added by later accepted ADRs (ADR-0015). Update the story text when ADR-0015 is accepted. |
| The export preset is untested (data-config 002 AC3) | Sprint 4 EX-1. |
| UI half of "shows the error" (network 001 AC4) | Covered by the NH-1 manual harness. |
