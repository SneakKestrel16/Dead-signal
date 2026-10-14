## QA Sign-Off Report: Sprint 002
**Date**: 2026-10-14
**QA level**: standard. **Config**: team.size individual, automation autonomous. qa-lead drafted this report. The orchestrator checked the verdict against the /team-qa rules and agrees.
**Plan**: `production/qa/qa-plan-sprint-002-2026-10-13.md`, the pre-sprint plan, reused; no new plan was written.
**Smoke**: PASS (`production/qa/smoke-2026-10-14.md`).
- 230/230 tests pass, exit 0, 0 orphans.
- The build was launched windowed, and the boot screen is kept at `production/qa/evidence/boot-2026-10-14.png`.
- Menu, save and performance are N/A, each with its reason.

**Scope decision, NA-V**: NA-V is left out of the sign-off scope. It is a Should Have story that was never started (status backlog), so no work was delivered for QA to run against. Holding the verdict on it would record a scope slip, which belongs to production, as "QA did not happen". It still gets a row below. Its real-network goal is carried as Condition 1, for two reasons: it was already Sprint 1 condition 1, and the two-PC and cross-machine acceptance criteria of NA-6 and DC-5 depend on it.

### Test Coverage Summary
| Story | Type | Auto Test | Manual QA | Result |
|---|---|---|---|---|
| NA-2 tokens/reconnect | Integration | `tokens_reconnect_test.gd` (12) PASS | — | PASS |
| NA-6 snapshots/prediction/reconciliation | Integration | `prediction_reconcile_test.gd` PASS | Two-PC evidence AC open (owned by NA-V) | PASS WITH NOTES: one AC is deferred to NA-V |
| DC-3 cross-knob rules | Logic | `cross_knob_rules_test.gd` (10) PASS | — | PASS |
| CI-1 body/collision | Integration | `body_collision_test.gd` (11) PASS | — | PASS WITH NOTES: deferrals are recorded as TD-007 |
| CI-6 view direction/mouse look | Logic | `view_direction_test.gd` (10) PASS | `controller-006-mouse-look-cases.md` written, not walked (needs the designer) | PASS WITH NOTES: the required unit evidence ran, but the designer check is still outstanding. CI-6-01 needs a temporary canvas_items stretch mode to catch its target bug |
| DC-5 knob digest in join version | Integration | `digest_version_test.gd` (7) PASS | Cross-machine half owned by NA-V | PASS WITH NOTES: the export-build digest check is blocked until an export preset exists (TD-004) |
| EC-6 layer boundary | Logic | `layer_boundary_test.gd` (10) PASS, runs in CI | — | PASS |
| LB-1 ready/countdown | Logic | `lobby_state_test.gd` (13) PASS | — | PASS |
| FM-1 facility map data | Integration | `map_data_test.gd` (16) PASS | — | PASS WITH NOTES: AC2's geometry half waits on facility-map story 002, and AC4's full sightline check on story 005. Nothing refuses a broken map yet (TD-008) |
| NA-V verify NA-1 on a real network | Integration | — | `na-v-real-network-cases.md`, every case BLOCKED-UNTIL-HARNESS | OUT OF SCOPE: never started (Should Have, backlog), and no scene lets a person host or join yet. NAV-08 also needs TD-004; NAV-15/16 depend on NA-3 |

Every done story went through /code-review (the Godot specialists and qa-tester) with mutation checks.

### Bugs Found
| ID | Story | Severity | Status |
|---|---|---|---|
| — | — | — | None. `production/qa/bugs/` does not exist, so nothing was on file and nothing was filed this cycle. |

### Verdict: APPROVED WITH CONDITIONS
NOT APPROVED was checked first: there are no open S1 or S2 bugs, and no story failed. The precondition holds: all nine in-scope stories have a test that ran, and the smoke check passed. The verdict is "with conditions" because five stories pass with documented notes, and Sprint 1 conditions are still open.

**Conditions**
1. **Real-network verification of NA-1.** This is Sprint 1 condition 1, now carried into a second sprint.
   - Build the proposed `tests/manual/net_check.tscn` harness, then walk `production/qa/test-cases/na-v-real-network-cases.md`.
   - The walk also closes the NA-6 two-PC AC and the DC-5 cross-machine half.
   - NAV-15/16 follow NA-3.
2. **Retroactive Sprint 1 code review.** This is Sprint 1 condition 2, neither done nor waived, now carried into a second sprint. The producer must schedule it or waive it explicitly.
3. **Smoke coverage for menu, session, save and performance.** This is Sprint 1 condition 3; no such items were added this sprint. Add each one when its system lands.
4. **Walk the CI-6 mouse-look cases** with the designer. CI-6-01 needs a temporary canvas_items stretch mode, because `project.godot` sets none.
5. **Add an export preset (TD-004).** It unblocks the DC-5 export-build digest check and NAV-08.
6. **Track each deferred acceptance criterion against the story that owns it:**
   - FM-1 AC2 goes to facility-map story 002.
   - FM-1 AC4 goes to facility-map story 005.
   - CI-1's deferrals stay in TD-007.
   - Map validation is TD-008.
   - TD-006 stays on the debt register.
7. Sprint 1 condition 4 (file defects with /bug-report) is met for this sprint: no defects were found.

### Next Step
Resolve the conditions before advancing. Conditions 1 and 2 are in their second sprint, so Sprint 003 planning must schedule or waive each one explicitly.
