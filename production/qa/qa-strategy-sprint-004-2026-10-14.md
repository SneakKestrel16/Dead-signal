# QA Strategy: Sprint 004
**Date**: 2026-10-14
**Phase**: /team-qa Phase 2 (strategy). qa.level standard, automation autonomous.
**Inputs**: `production/sprints/sprint-004.md`, the nine story files, `production/qa/sr-1-sprint-1-review-2026-10-14.md`, `production/qa/smoke-2026-10-14-sprint-004.md`, BUG-0001..0003, `qa-plan-sprint-004-2026-10-14.md` (exists). I confirmed each test file exists on disk and read each story's Test Evidence status. I did not re-run the suite; counts below are the story files' and the smoke report's.
**Out of scope**: NA-V (waived by the designer, AD-103).

## Smoke verdict
**PASS** (`production/qa/smoke-2026-10-14-sprint-004.md`): 484/484 tests in 41 suites, exit 0, 0 orphans, 0 flaky. Headless and windowed boot (`evidence/boot-sprint-004-2026-10-14.png`, file present), local host/client join with PLAYER_ID 0, headless export boot with matching `join_version`. Menu, save and performance are N/A with stated reasons. The build may go to manual QA.
**Advisories carried from smoke**: `commands.build` still unset (designer, `/settings`); AD-111 and AD-112 production wiring gaps (see Blockers and concerns).

## Open bugs in scope
3 open, 0 S1, 0 S2, 2 S3, 1 S4. At `standard`, only an open S1 blocks, so none blocks sign-off.
- BUG-0001 S4-Low / P3: harness only, no shipped code.
- BUG-0002 S3-Medium / P2 "fix next sprint": unranged int and alpha knobs load any finite value. Not scheduled in Sprint 4; needs sourced ranges. Risk: refuse-to-host trusts `errors()`.
- BUG-0003 S3-Medium / P2: killed-server detection flaky (4.3 s vs 3.0 s bound). Passed in the smoke run. Rule: do not widen the bound or skip the test until the cause is known; a failure of this one test in a CI run is a known flake to record, not a regression to chase.

## Strategy table

| Story | Type | Automated Required | Manual Required | Blocker? |
|---|---|---|---|---|
| SR-1 Sprint 1 retroactive review | Review task (Logic regressions) | Regression tests in touched suites (`input_queue_test`, `server_event_catalog_test`, `knob_section_validation_test`, `host_join_auth_test`, `tick_runner_test`, `round_teardown_test`, event bus test); each watched failing. 351/351 at record time | Desk check: record exists with files reviewed, findings, dispositions | No. Record present; BUG-0002 filed; S4 deferrals listed with owners |
| CI-3 Speed modifiers | Logic | `tests/unit/first-person-controller/speed_modifiers_test.gd`, present, 14 passing | None | No |
| CI-8 Hold start and complete | Integration | `tests/integration/first-person-controller/hold_service_start_test.gd`, present, 23 passing | None for story. Smoke path 4 ran on stand-ins only: the map has no interactables | No. Concern: greybox hold unproven until an owner epic places one |
| NA-9 Event projection and sounds | Integration | `tests/integration/network/event_projection_test.gd`, present, 20 passing; NA-8 capture test extended | None | No. AD-107 amended ADR text (see concerns) |
| LB-2 Roster lock and hand-off | Integration | `tests/integration/lobby/roster_lock_test.gd`, present, 15 passing (+2 in `host_join_auth_test`) | None | No. AC2 "loading begins on every peer" narrowed to hand-off (AD-108), Match Flow owns it |
| FM-5 Visibility table | Integration | `tests/integration/facility-map/visibility_table_test.gd`, present, 14 passing | None. Sightline pass by the designer later edits the .tres; the table-pin test rereads the level doc | No |
| NA-10 Hidden entities and spectators | Integration | `tests/integration/network/hidden_entities_test.gd`, present, 7 passing (real ENet, 3 consecutive runs) | None | No. Real ENet on loopback; flake-watch alongside BUG-0003 |
| CI-4 Steps, slopes, stand-up | Integration | `tests/integration/first-person-controller/steps_stand_up_test.gd`, present, 10 passing; AC4 by `view_direction_test.gd` | None possible yet: nothing calls `set_low(crouch, others)` in production (AD-111) | No for Done. Deferred-AC row: AC2/AC3 on a test loop, not the production caller |
| CI-9 Hold continue and cancel | Integration | `tests/integration/first-person-controller/hold_service_continue_test.gd`, present, 16 passing | None possible yet: nothing copies `hold_of()` into `MoveState` (AD-112) | No for Done. Deferred-AC row: AC3 "from the next tick" unenforced in production |
| LB-7 Rotation queue | Logic | `tests/unit/lobby/rotation_queue_test.gd`, present, 8 passing (+ roster_lock_test) | None | No |
| EX-1 Export preset | Config/Data (no story file) | `tests/unit/data_config/export_preset_test.gd`, present, 5 tests; `export_presets.cfg` committed | Headless export build: done in smoke (boots, 13 knob files, no tests or gdUnit4 in pck, `join_version` matches) | No. Gate is advisory for Config/Data and is met |

All 10 test files exist; every story file records `Status: [x] Created` with passing counts and Completion Notes. Logic and Integration BLOCKING gates are met for all 9 stories plus SR-1. No Visual/Feel or UI story is in scope, so no screenshot or lead sign-off gate applies beyond the boot screenshot. Tests in scope: 14+23+20+15+14+7+10+16+8+5 = 132, within the 484 total.

## Manual QA effort estimate
No mandatory manual session blocks sign-off.

| Session | Needed for sign-off? | Who | Effort |
|---|---|---|---|
| Desk check: SR-1 record vs sprint AC (all files reviewed, findings fixed or filed) | Yes | qa-lead | ~15 min |
| Desk check: each story's Completion Notes deviations (AD-107..AD-114) are logged and the GDD/ADR text is amended where claimed | Yes | qa-lead | ~30 min |
| Re-run smoke on the final merged build before hand-off, if anything lands after 2026-10-14 | Conditional | qa-tester | ~20 min plus 167 s suite |
| CI-6 mouse-look walk (`tests/manual/mouse_look_check.tscn`), carried | No (carried condition) | designer | ~15 to 20 min |
| FM-2 greybox sign-off (every room two exits, no snags), carried | No (carried condition) | designer | ~15 min |

Total: about 1 h 05 min of QA time required, plus about 35 min of designer time that I recommend but do not gate on.

## Blockers and concerns
**Blockers**: none. No missing acceptance criteria, no missing test files, no story without a recorded pass.

**Criteria whose manual verification no automated test covers (deferred, not blockers)**:
1. CI-4 AC2 ("stands within 1 tick") and AC3 (head room blocked by another capsule): proven on a test loop that imitates the missing caller (AD-111). Re-verify when the first story drives PlayerBody from ServerMovement.
2. CI-9 AC3 (sprint 4.0, root 0, crouch ignored "from the next tick"): the step is tested, the copy of hold state into `MoveState` is not built (AD-112). Same re-verify trigger.
3. CI-8 smoke path 4 ("a hold completes on a greybox interactable") cannot run; `research_facility.tres` has no interactables. Stand-ins cover the server rule.
4. CI-3 AC2 is verified as the step's target speed, not the ramped body speed. Covered separately by `movement_step_test`. Fine.
5. LB-2 AC2 loading on every peer, and the NA-9 / NA-10 deferrals (rejoin resync of phase and life states, spectator UI): belong to Match Flow, event-catalog 005 and the HUD epic. Track as deferred-AC rows in the sign-off.

**Concerns**:
- BUG-0002 (S3, P2) is a Sprint 1 foundation defect with no sprint slot. Ask the producer to schedule it in Sprint 5.
- BUG-0003 is a flaky test; `prediction_reconcile_test` also failed once under load (NA-9 notes). Two flakes in the real-ENet suites; if a third appears, raise a test-stability story.
- NA-9 amends ADR-0004 / ADR-0005 text (AD-107) and the SR-1 note says event-catalog AC1 still says 15 events vs 17. Confirm the ADR/story text edits actually landed; this is a document-consistency check for the designer's AD review (R6, AD-01..AD-114 unreviewed).
- Carried conditions from Sprint 3 sign-off: SR-1 is now closed; NA-V is waived (designer decision, AD-103); CI-6 walk, FM-2 sign-off, TD-004 export (now done), and menu/save/performance smoke N/A remain.

## Recommendation
Proceed to Phase 3 (sign-off) with APPROVED WITH CONDITIONS: conditions are the carried CI-6 and FM-2 designer checks, the CI-4 / CI-9 production wiring re-verification, BUG-0002 scheduling, and the waived NA-V recorded as an accepted risk.
