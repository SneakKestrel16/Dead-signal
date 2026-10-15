## QA Sign-Off Report: Sprint-005
**Date**: 2026-10-15
**Run**: /team-qa sprint-005, autonomous, team.size individual (qa-lead at Phases 2 and 6; no qa-tester spawn, because no story needed manual cases)
**Strategy**: `production/qa/qa-strategy-sprint-005-2026-10-15.md`
**QA plan**: `production/qa/qa-plan-sprint-005-2026-10-14.md`, reused for Phase 3 (same sprint, same scope)
**Smoke check**: PASS, `production/qa/smoke-2026-10-15.md`

### Test Coverage Summary
| Story | Type | Auto Test | Manual QA | Result |
|---|---|---|---|---|
| BUG-0002 Unranged int and alpha knobs (regression) | Logic | `tests/unit/data_config/knob_ranges_test.gd` (5): PASS | Not required | PASS |
| match-flow 001 Round clock and phases | Logic | `tests/unit/match-flow/round_clock_phases_test.gd` (14): PASS | Not required | PASS |
| match-flow 002 Win evaluation | Logic | `tests/unit/match-flow/win_evaluation_test.gd` (25): PASS | Not required | PASS |
| match-flow 003 Escape and outcome lock | Logic | `tests/unit/match-flow/escape_and_outcome_lock_test.gd` (12): PASS | Not required | PASS |
| match-flow 004 Round lifecycle | Integration | `tests/integration/match-flow/round_lifecycle_test.gd` (6): PASS | Not required | PASS WITH NOTES (AC4 is tested only for a host leaving during Loading) |
| match-flow 009 Client display authority | Integration | `tests/integration/match-flow/client_display_authority_test.gd` (5): PASS | Not required | PASS |
| survivor-objectives 001 Drive extract and carry | Integration | `tests/integration/survivor-objectives/drive_extract_and_carry_test.gd` (18): PASS | Not required | PASS |
| survivor-objectives 002 Drops and pickups | Integration | `tests/integration/survivor-objectives/drops_and_pickups_test.gd` (18): PASS | Not required | PASS |
| survivor-objectives 003 Fuses and power | Integration | `tests/integration/survivor-objectives/fuses_and_power_test.gd` (15): PASS | Not required | PASS |
| survivor-objectives 005 Docking and terminal | Integration (was declared Logic; corrected this cycle) | `tests/integration/survivor-objectives/docking_and_terminal_test.gd` (16): PASS | Not required | PASS |
| survivor-objectives 006 Extraction | Integration | `tests/integration/survivor-objectives/extraction_test.gd` (6): PASS | Not required | PASS |
| downing-and-rescue 001 Takedown commit | Logic | `tests/unit/downing-and-rescue/takedown_commit_test.gd` (17): PASS | Not required | PASS |
| downing-and-rescue 003 Bleed-out | Logic | `tests/unit/downing-and-rescue/bleed_out_test.gd` (13): PASS | Not required | PASS |

**Evidence**:
- The full gdUnit4 suite passed 898/898 at `72a2e69`, with 0 orphans and no leak lines. Every in-scope test file above ran in that run.
- No story has a UI or Visual/Feel AC, so no screenshots were needed.
- No bugs were filed this cycle.

### Bugs Found
| ID | Story | Severity | Status |
|---|---|---|---|
| BUG-0002 | data-config (sprint-005 regression item) | S3 | Verified Fixed this cycle (`knob_ranges_test.gd` 5/5 in the 898 run) |
| BUG-0003 | network-authority, outside this sprint (intermittent ENet timeout bound in `disconnect_host_left_test.gd`) | S3 | Open |
| BUG-0004 | first-person-controller, outside this sprint (`chase_closing_tick_budget_test.gd` depends on the host) | S3 | Open |
| BUG-0001 | net harness test tooling, outside this sprint | S4 | Open |

No S1 or S2 bugs are open.

### Verdict: APPROVED WITH CONDITIONS

The qa-lead checked NOT APPROVED first: no S1 or S2 bug is open and no story failed. The precondition holds, because all 13 items have executed automated evidence and the smoke check passed. The verdict is not plain APPROVED because S3 and S4 bugs are open and one story passed with notes. The orchestrator checked the verdict against the same rules and agrees.

**Conditions**:
1. **match-flow 004 AC4: resolved.** Two tests were added for the host leaving mid-round and during Results (`round_lifecycle_test.gd`, now 8 tests). Full suite 900/900. A mutation that has `NetAuthority.close()` emit `player_dropped` fails both tests.
2. **BUG-0003 and BUG-0004 stay open and triaged.** Both timing tests failed in the two full-suite runs before the passing one, so one pass does not show they are fixed. They are outside this sprint and may be deferred to polish, but CI stays flaky until they are fixed.
3. **BUG-0001 (S4)** may be deferred to polish.

Resolved during this cycle:
- **BUG-0002** is verified fixed.
- **survivor-objectives 005**: the Story Type is corrected from Logic to Integration, to match where its test lives.

### Next Step
Resolve conditions before advancing. S3 and S4 bugs may be deferred to polish. The match-flow 004 AC4 condition is resolved; the remaining conditions are S3 and S4 bugs that can be deferred.
