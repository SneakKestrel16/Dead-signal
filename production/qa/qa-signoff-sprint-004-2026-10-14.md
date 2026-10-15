## QA Sign-Off Report: Sprint 004
**Date**: 2026-10-14
**QA level**: standard. **Config**: team.size individual, automation autonomous (AD-117). qa-lead drafted this report and applied the /team-qa verdict rules from scratch; it did not reuse the Phase 2 recommendation. The orchestrator checked the verdict against the same rules and agrees with it.
**Strategy**: `production/qa/qa-strategy-sprint-004-2026-10-14.md`. **Plan**: `production/qa/qa-plan-sprint-004-2026-10-14.md`.
**Smoke**: PASS (`production/qa/smoke-2026-10-14-sprint-004.md`).
- 484/484 tests in 41 suites pass, exit 0, with 0 orphans and 0 flaky.
- The build booted headless and windowed. The boot screen is kept at `production/qa/evidence/boot-sprint-004-2026-10-14.png`.
- The exported build booted headless, and its `join_version` matched the editor's.
- A local host and client joined, and the client got PLAYER_ID 0.
- Menu, save and performance are N/A, each with its reason.

**Scope decision**: NA-V is out of scope. The designer waived it and removed it from the sprint (AD-103); it still gets a row below. No manual QA cases were in scope, so Phases 4 and 5 ran nothing manual. Every result below comes from the automated run in the smoke check.

### Test Coverage Summary
| Story | Type | Auto Test | Manual QA | Result |
|---|---|---|---|---|
| SR-1 Sprint 1 retroactive review | Review task | Regression tests in the touched suites (`input_queue_test`, `server_event_catalog_test`, `knob_section_validation_test`, `host_join_auth_test`, `tick_runner_test`, `round_teardown_test`, event bus) PASS in the smoke run | Record `sr-1-sprint-1-review-2026-10-14.md` desk-checked: it lists the files reviewed, the findings and their dispositions | PASS WITH NOTES: BUG-0002 was filed from it. The S4 deferrals are listed with owners. The event-catalog AC1 still says 15 events, not 17 |
| CI-3 speed modifiers | Logic | `speed_modifiers_test.gd` (14) PASS | — | PASS |
| CI-8 hold start/complete | Integration | `hold_service_start_test.gd` (23) PASS | — | PASS WITH NOTES: the smoke path "hold on a greybox interactable" ran only on stand-ins, because `research_facility.tres` places no interactables |
| NA-9 event projection | Integration | `event_projection_test.gd` (20) PASS. The NA-8 capture test was extended | — | PASS WITH NOTES: AD-107 amends the text of ADR-0004 and ADR-0005. Rejoin resync of phase and life states is deferred to event-catalog 005 |
| LB-2 roster lock | Integration | `roster_lock_test.gd` (15) PASS, plus 2 tests in `host_join_auth_test` | — | PASS WITH NOTES: AC2 "loading begins on every peer" is narrowed to the hand-off (AD-108). Match Flow owns the loading part |
| FM-5 visibility table | Integration | `visibility_table_test.gd` (14) PASS | — | PASS |
| NA-10 hidden entities | Integration | `hidden_entities_test.gd` (7) PASS, real ENet on loopback | — | PASS WITH NOTES: the spectator UI is deferred to the HUD epic. The suite uses real ENet, so watch it for flakes alongside BUG-0003 |
| CI-4 steps/stand-up | Integration | `steps_stand_up_test.gd` (10) PASS. AC4 is covered by `view_direction_test.gd` | — | PASS WITH NOTES: AC2 and AC3 are proven on a test loop. Nothing in production calls `set_low` each tick yet (AD-111) |
| CI-9 hold continue/cancel | Integration | `hold_service_continue_test.gd` (16) PASS | — | PASS WITH NOTES: nothing in production copies the hold state into `MoveState` yet (AD-112), so AC3 "from the next tick" is not enforced in production |
| LB-7 rotation queue | Logic | `rotation_queue_test.gd` (8) PASS | — | PASS |
| EX-1 export preset | Config/Data | `export_preset_test.gd` (5) PASS | Manual export check in the smoke run PASS: the build boots, holds 13 knob files, has no tests or gdUnit4 in the pck, and `join_version` matches | PASS |
| NA-V verify NA-1 on a real network | Integration | — | `na-v-real-network-cases.md`, not walked | OUT OF SCOPE: waived by the designer and removed from the sprint (AD-103) |

Test counts come from the story files and the strategy. All 132 in-scope tests are part of the 484 that passed.

### Bugs Found
| ID | Story | Severity | Status |
|---|---|---|---|
| BUG-0001 | NH-1 (net harness) | S4-Low, P3-Backlog | Open. It affects the test tool only, not shipped code. |
| BUG-0002 | SR-1 (data-config) | S3-Medium, P2 | Open. Int and alpha knobs that have no range accept any finite value, and refuse-to-host trusts `errors()`. It is not scheduled in Sprint 4. |
| BUG-0003 | network-authority | S3-Medium, P2 | Open. The killed-server detection test is flaky (4.3 s against a 3.0 s bound). It passed in this smoke run. |

No bugs were filed in Phase 5.

### Verdict: APPROVED WITH CONDITIONS
NOT APPROVED was checked first. No S1 or S2 bug is open, and no story failed. The precondition holds: all 11 in-scope stories have executed evidence. Each has a test that ran and passed in the smoke run, and SR-1 also has its review record. The smoke check passed.

The verdict carries conditions for three reasons. Two S3 bugs and one S4 bug are open. Six stories pass with documented notes. Carried conditions are still open.

CI-4 and CI-9 are not held back as unexecuted. Their required Integration tests ran. The gap is production wiring that no story has built yet, so it is recorded as a condition.

### Conditions
1. **NA-V waiver is an accepted risk.** NA-1 has no verification on a real network. Real-network checks that depended on NA-V now have no owner: the NA-6 two-PC AC, the DC-5 cross-machine half, NA-3's dead-peer timing and NAV-08. Record that in the risk register, and revisit it before any external playtest.
2. **Schedule BUG-0002 in Sprint 5.** It needs sourced ranges for the knobs. The producer owns the slot.
3. **BUG-0003 flake watch.** Do not widen the bound or skip the test until the cause is known. `prediction_reconcile_test` has also failed once under load. If a third real-ENet flake appears, raise a test-stability story.
4. **Re-verify CI-4 AC2/AC3 and CI-9 AC3 against production.** Do this when the first story drives PlayerBody from ServerMovement (AD-111, AD-112).
5. **Re-run the CI-8 greybox hold path.** Do this once an owner epic places an interactable in `research_facility.tres`.
6. **Walk the carried designer checks:** the CI-6 mouse-look cases (`tests/manual/mouse_look_check.tscn`) and the FM-2 greybox sign-off (every room has two exits and no doorway snags).
7. **Document consistency.** Confirm that the AD-107 amendments to the ADR-0004 and ADR-0005 text landed, and fix the event-catalog AC1 count (15 vs 17). Both belong in the designer's review of AD-01 to AD-114.
8. **Track each deferred acceptance criterion against the story that owns it:**
   - LB-2 AC2 loading on every peer goes to Match Flow.
   - The NA-9 rejoin resync goes to event-catalog 005.
   - The NA-10 spectator UI goes to the HUD epic.
   - Sprint 3 items carry on: NA-3 AC3 and DC-4 host UI wait for the menu story. NA-8 AC4 waits for the round flow (AD-95/96). CI-7 stays an inference (AD-93).
9. **Smoke coverage gaps.** Add menu, save and performance to the smoke check as each system lands. `commands.build` is still unset; the designer sets it via `/settings`.
10. **Triage BUG-0001.** It is S4-Low and may be deferred to polish.

### Next Step
Resolve the conditions before advancing. S3/S4 bugs may be deferred to polish. Condition 2 (scheduling BUG-0002) belongs in Sprint 005 planning, before any other carried work.
