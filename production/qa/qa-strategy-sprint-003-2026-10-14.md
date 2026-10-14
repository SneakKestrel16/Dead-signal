# QA Strategy: Sprint 003
**Date**: 2026-10-14
**Phase**: /team-qa Phase 2 (strategy). qa.level standard, team.size individual, automation autonomous.
**Inputs**: sprint-status.yaml (as distilled by the caller), `production/qa/qa-plan-sprint-003-2026-10-14.md`, `production/qa/smoke-2026-10-14-sprint-003.md`, Sprint 2 sign-off precedent. Test counts and file paths below are taken from the caller's distillation; I did not re-run the suite.

## Smoke verdict
**PASS** (`production/qa/smoke-2026-10-14-sprint-003.md`): 320/320 tests exit 0, 0 orphans; headless and windowed boot (evidence `boot-sprint-003-2026-10-14.png`); local harness host/client join, PLAYER_ID 0; greybox walk A1 to B1 35.6 m at 3.98 m/s average. Menu, save and performance are N/A with stated reasons (no such systems yet). The build may go to manual QA.
**Advisory carried from smoke**: the harness route mode keeps sending after HOST_LEFT. Not a gate failure; see Bugs.

## Open bugs in scope
None on file: `production/qa/bugs/` does not exist, so the release-checklist rule reads this as `NOT ASSESSED — no bug records`, not as zero. Recommend filing the smoke advisory with `/bug-report` (proposed S4-Low / P3, Network, harness tool only, no shipped code path) so the record exists and is triaged rather than living only in a smoke note. It is a harness defect, but NA-3 AC3 is the behaviour it brushes against, so triage should confirm the test still pins the real client path.

## Strategy table

| Story | Type | Automated Required | Manual Required | Blocker? |
|---|---|---|---|---|
| NH-1 host/join harness (Must, done) | Integration (manual tool) | None by design; the harness is the manual tool | Done: `net-harness-1-evidence.md` + `net-harness-1-host-route.png`. Re-check only that the plan's seven checklist lines (refusal, PLAYER_ID, REJECT version_mismatch, L, R/REJOIN, token not logged, NA-V cases unblocked) are each answered in that evidence file | No. Confirm checklist coverage; if a line is missing, record it, do not re-run |
| NA-3 disconnect and host left (Must, done) | Integration | `disconnect_host_left_test.gd`, 12 tests, present and green | Real-network dead-peer timing, folded into NA-V (NAV cases) | No for story Done. Real-network timing is a carried condition, not a blocker |
| CI-2 movement step and gaits (Must, done) | Logic | `movement_step_test.gd`, 12, green | None. Feel of movement belongs to CI-6, tracked separately | No |
| FM-2 greybox geometry and collision (Must, done) | Integration (+Visual secondary) | `greybox_geometry_test.gd`, 9, green | Retained screenshot `facility-map-002-greybox-top.png` exists. Visual/Feel is BLOCKING and wants lead sign-off | CONCERN: designer sign-off on the walk-through is not stated in the inputs. Verify it is recorded in the evidence doc; if not, it is a sign-off condition (level-designer review), not a re-test |
| DC-4 refuse to host and knobs frozen (Must, done) | Integration (+UI secondary) | `refuse_to_host_test.gd`, 9, green | Retained screenshot `data-config-004-refuse-to-host.png` exists. UI gate satisfied for the one screen touched | No |
| CI-7 interaction targeting (Should, done) | Logic | `interaction_targeting_test.gd`, 20, green | None | No |
| NA-8 per-peer handles and relevance (Should, done) | Integration | `handles_relevance_test.gd`, 18, green | None. AC4 ran as a scripted visibility/form-change sequence (AD-95) | No for Done. Carry a deferred-AC row: full-round AC4 re-run once a round flow exists |
| CI-5 controller load checks (Should, done) | Logic | `controller_load_checks_test.gd`, 10, green | None | No |
| NA-V verify NA-1 on a real network (Should, backlog, never started) | Integration (manual) | None | Two-PC session per `na-v-real-network-cases.md`; NAV-08 needs EX-1; NAV-07 skipped by design | Excluded from sign-off scope (Sprint 2 precedent); carried condition, second sprint running |
| FM-3 connectivity checks (Nice, backlog) | Logic | `connectivity_test.gd` planned, not written | None | Excluded; not started |
| LB-3 character data and M1 assignment (Nice, backlog) | Logic | `character_assignment_test.gd` planned, not written | None | Excluded; not started |
| EX-1 export preset (Nice, backlog) | Config/Data | Export check (DC-5 `join_version`), blocked on a preset | Headless export build | Excluded; blocked on designer decision (TD-004) |

Eight stories are in sign-off scope, all with their required evidence present: 4 Logic/Integration automated files for Must plus 3 Should files, 3 retained screenshots, 1 evidence doc. Logic and Integration BLOCKING gates are met for all eight. Total new tests in scope: 12+12+9+9+20+18+10 = 90 across seven files, within the 320 total.

## Does the pre-sprint plan suffice?
Yes, with no new plan. The classifications held: 5 Logic/Integration split matches, and the plan's findings (NA-3 AC3 main-menu, DC-4 host UI, NA-8 AC4 scripted round) were applied as written. Two small gaps to note, neither needing a new plan:
1. The plan's smoke list item 5 (regression: `prediction_reconcile_test.gd`, `host_join_auth_test.gd`, `tokens_reconnect_test.gd`) is covered by the 320/320 full-suite pass, but the smoke report as summarised does not name them. Accept the full pass.
2. The plan names FM-2 designer sign-off; the evidence status is the one thing I could not confirm from the inputs (see table).

Plan test counts were estimates and actuals are higher (e.g. CI-7 20 vs ~8); that is more coverage, not a gap.

## Manual cases needed this cycle
No new manual case blocks this sprint's sign-off. Estimated manual sessions:

| Session | Needed for sign-off? | Who walks it | Effort | Notes |
|---|---|---|---|---|
| NH-1 evidence checklist cross-check | Yes, desk check only | qa-lead (me, solo project) | ~15 min | Read the evidence file against the plan checklist; no re-run |
| FM-2 sign-off confirmation | Yes if absent | designer | ~15 min | Review the retained screenshot and walk A1 to B1 once |
| NA-V real network (NAV-01..06, 09..12) | No (carried condition) | designer + second PC, qa-lead runs the cases | ~1 session, 1.5 to 2 h | Also records NA-3 real-network timing. NAV-08 waits for EX-1 |
| CI-6 mouse-look walk (Sprint 2 condition 4) | No (carried condition) | designer | ~20 min | Combine with the NA-V session to save a scheduling round |

So: 0 mandatory full sessions, 2 short confirmations, and 1 combined optional designer session (NA-V + CI-6, ~2 h) that I recommend scheduling but not gating on.

## Carried conditions for sign-off (mirror of the Sprint 2 list)
1. NA-V real-network run: still open, second sprint carried. Now unblocked by NH-1 except NAV-08 (needs EX-1). Escalation: a third carry should be made an explicit schedule-or-waive designer decision.
2. Retroactive Sprint 1 code review: schedule or waive; not progressed this sprint.
3. Smoke coverage for menu, session, save, performance: still N/A; revisit when lobby story 005 gives a real menu.
4. CI-6 mouse-look walk with designer.
5. Export preset TD-004 / EX-1 (designer decision).
6. Deferred ACs tracked per owning story: NA-8 AC4 full-round; NA-3 AC3 "main menu" currently `src/main.tscn` placeholder (AD-67); DC-4 AC1 "host UI" currently the harness.

## Release-readiness note
Sprint 003 is releasable as a milestone increment: no S1/S2 records exist, but "no records" is NOT ASSESSED rather than clean until the bug directory exists. Filing the one advisory bug creates the record and makes the next count meaningful.

## Recommendation
Proceed to Phase 3 (sign-off) with verdict APPROVED WITH CONDITIONS on the eight in-scope stories, the four never-started backlog stories listed as excluded rows, and the six conditions above.
