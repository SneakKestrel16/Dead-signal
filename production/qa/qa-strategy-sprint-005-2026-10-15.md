# QA Strategy: sprint-005 (team-qa Phase 2)

**Date**: 2026-10-15
**Engine / runner**: Godot 4.7.2, gdUnit4
**qa.level**: standard (Logic and Integration need a passing automated test; UI and Visual/Feel need retained screenshots)
**Scope**: the 13 `done` entries in `production/sprint-status.yaml`

## Method

For each story I read the declared Type, the Acceptance Criteria and the Test Evidence block. I confirmed the test file exists on disk and compared its `test_` function names with each AC (spot-check by name, not a re-run). Pass status comes from the smoke check, not from a re-run here.

No story has a UI or Visual/Feel AC. The only mentions of HUD or presentation (MF-4 "Results", MF-9 clock and phase widgets, DR-3 HUD ring) are explicit out-of-scope notes that point to later UI or HUD stories. So no screenshot evidence is required for this sprint.

## Strategy table

| Story | Type | Automated Required | Manual Required | Blocker? |
|---|---|---|---|---|
| BUG-0002 Unranged int and alpha knobs (S3) | Logic (regression) | `tests/unit/data_config/knob_ranges_test.gd`, 5 tests: exists | None | No |
| match-flow 001 Round clock and phases | Logic | `tests/unit/match-flow/round_clock_phases_test.gd`, 14 tests: exists, covers AC1-4 | None | No |
| match-flow 002 Win evaluation | Logic | `tests/unit/match-flow/win_evaluation_test.gd`, 25 tests: exists, covers AC1-4 | None | No |
| match-flow 004 Round lifecycle | Integration | `tests/integration/match-flow/round_lifecycle_test.gd`, 6 tests: exists, covers AC1-3; AC4 partial (see Concerns) | None | No |
| survivor-objectives 001 Drive extract and carry | Integration | `tests/integration/survivor-objectives/drive_extract_and_carry_test.gd`, 18 tests: exists, covers AC1-5 | None | No |
| survivor-objectives 003 Fuses and power | Integration | `tests/integration/survivor-objectives/fuses_and_power_test.gd`, 15 tests: exists, covers AC1-4 | None | No |
| survivor-objectives 005 Docking and terminal | Integration per the brief; the story file says Logic (see Concerns) | `tests/integration/survivor-objectives/docking_and_terminal_test.gd`, 16 tests: exists, covers AC1-4 | None | No |
| match-flow 003 Escape and outcome lock | Logic | `tests/unit/match-flow/escape_and_outcome_lock_test.gd`, 12 tests: exists, covers AC1-3 | None | No |
| survivor-objectives 006 Extraction | Integration | `tests/integration/survivor-objectives/extraction_test.gd`, 6 tests: exists, covers AC1-4 | None | No |
| downing-and-rescue 001 Takedown commit | Logic | `tests/unit/downing-and-rescue/takedown_commit_test.gd`, 17 tests: exists, covers AC1-4 | None | No |
| survivor-objectives 002 Drops and pickups | Integration | `tests/integration/survivor-objectives/drops_and_pickups_test.gd`, 18 tests: exists, covers AC1-4 | None | No |
| downing-and-rescue 003 Bleed-out | Logic | `tests/unit/downing-and-rescue/bleed_out_test.gd`, 13 tests: exists, covers AC1-4 | None | No |
| match-flow 009 Client display authority | Integration (story Type line confirms) | `tests/integration/match-flow/client_display_authority_test.gd`, 5 tests: exists, covers AC1-3 | None | No |

Notes on coverage:
- The "Covers" judgement is by test name. `test_*_come_from_the_knobs` tests cover each "read from knobs, not hardcoded" AC.
- MF-9 AC1 (200 ms): the test asserts `LOOPBACK_BOUND_MS := 200` for phase changes and round end.
- MF-4 AC3 includes the clean second round, covered at `round_lifecycle_test.gd:253`.
- Every story's Test Evidence block names its test file and records it as created and passing.
- Every test file exists.

**Manual QA**: none required.
**Missing ACs or evidence**: none missing. Two concerns are listed below.

## BUG-0002: can it be marked Verified Fixed?

**Yes, once `/bug-report verify BUG-0002` records it.** It is not marked here.

- The related test is `tests/unit/data_config/knob_ranges_test.gd`. Its five tests are:
  - `test_ranges_every_int_and_alpha_mult_field_has_a_range_hint`
  - `test_ranges_shipped_knobs_load_with_no_errors`
  - `test_ranges_port_zero_is_reported_by_errors`
  - `test_ranges_alpha_above_one_is_reported_by_errors`
  - `test_ranges_every_ranged_field_rejects_just_outside_and_accepts_both_bounds`
- The test case maps to the repro: `port` out of range and an alpha above 1 now produce an `errors()` entry (repro steps 1-2, expected result).
- The BUG-0002 Resolution section records that 3 of the 5 tests failed before the fix and pass after it. That is a genuine red-to-green regression.
- The smoke check at `72a2e69` lists the file as COVERED, and the full suite passed 898/898 with no failures.
- The Bug Category is Data/Config, so the verify skill's manual step (Visual/UI only) does not apply.
- The `**Verified by**:` line should read `tests/unit/data_config/knob_ranges_test.gd — ran and passed`.
- Close with `/bug-report close BUG-0002` only after the Verified Fixed write.

## Smoke Check

**Smoke Check**: PASS (`production/qa/smoke-2026-10-15.md`). The full suite passed 898/898 at `72a2e69` with exit 0. The boot, host/client join and round-to-deadline paths passed. Used directly; not re-run.

## Open bugs in scope

**Open bugs in scope**:
- BUG-0002, S3, data-config: Fixed (pending verification). It is part of this sprint, and the regression test above supports Verified Fixed.
- BUG-0003, S3, network-authority: open. The intermittent ENet timeout bound fails `disconnect_host_left_test.gd`. The system is outside this sprint; it is listed because the full suite runs it.
- BUG-0004, S3, first-person-controller: open. `chase_closing_tick_budget_test.gd` is a host-dependent tick-budget test. Outside this sprint.
- BUG-0001, S4: test tooling only.
- No S1 or S2 on file. At `qa.level: standard` only S1 blocks, so nothing here blocks sign-off.

## Concerns

1. **survivor-objectives 005 type mismatch**. The story file declares `Story Type: Logic`, and its Test Evidence block says "Logic: `tests/integration/...`". The test sits in `tests/integration/`, but the Logic convention is `tests/unit/`. The brief classes it as Integration. The test exists and passes, so the gate is met either way. Recommend the story author correct the Type line to Integration, or move the test under `tests/unit/survivor-objectives/`. This is a paperwork fix and not a blocker.
2. **match-flow 004 AC4 partial**. AC4 says "if the host leaves, the session closes for every player and the round ends with no result recorded and no forfeit". The only test, `test_map_loaded_arrives_over_enet_and_host_quitting_in_loading_records_nothing`, covers the host quitting during Loading. The host leaving mid-round or during Results is not asserted. Recommend a follow-up test, or confirm that the Loading case is accepted as sufficient (a game-designer or lead-programmer decision). Not blocking at standard rigor.
3. **BUG-0003 and BUG-0004 flakiness**. Both timing tests failed in the two full runs before the passing one. A pass on one run is not proof that either is fixed. Neither belongs to this sprint, so neither blocks it.
