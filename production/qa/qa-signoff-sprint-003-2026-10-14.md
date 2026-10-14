## QA Sign-Off Report: Sprint 003
**Date**: 2026-10-14
**QA level**: standard. **Config**: team.size individual, automation autonomous. qa-lead drafted this report. The orchestrator checked the verdict against the /team-qa rules and agrees.
**Plan**: `production/qa/qa-plan-sprint-003-2026-10-14.md`, the pre-sprint plan, reused; no new plan was written. **Strategy**: `production/qa/qa-strategy-sprint-003-2026-10-14.md`.
**Smoke**: PASS (`production/qa/smoke-2026-10-14-sprint-003.md`).
- 320/320 tests pass, exit 0, 0 orphans.
- The build booted headless and windowed. The boot screen is kept at `production/qa/evidence/boot-sprint-003-2026-10-14.png`.
- A local harness host and client joined, and the client got PLAYER_ID 0.
- A greybox walk from A1 to B1 covered 35.6 m at an average of 3.98 m/s.
- Menu, save and performance are N/A, each with its reason.

**Scope decision**: NA-V, FM-3, LB-3 and EX-1 are left out of the sign-off scope, following the Sprint 2 precedent. None of them was started (all are in the backlog), so no work was delivered for QA to run against. Each one still gets a row below. NA-V's real-network goal stays as Condition 1, and this is the third sprint it has been carried.

### Test Coverage Summary
| Story | Type | Auto Test | Manual QA | Result |
|---|---|---|---|---|
| NH-1 host/join harness | Integration (manual tool) | None by design | `net-harness-1-evidence.md` checks all run: join, version mismatch reject, bad_name, bad_payload, lobby keys, rejoin, route FINAL identical, bots with 5 clients, token never printed. Screenshot `net-harness-1-host-route.png`. The orchestrator checked the doc and found it complete | PASS WITH NOTES: the two-PC cases belong to NA-V. BUG-0001 (S4) is open against the tool |
| NA-3 disconnect/host left | Integration | `disconnect_host_left_test.gd` (12) PASS | Screenshot `network-authority-003-host-left.png` | PASS WITH NOTES: the AC3 main-menu text waits for a menu (the current main is the `src/main.tscn` placeholder, AD-67). Real-network dead-peer timing belongs to NA-V |
| CI-2 movement step | Logic | `movement_step_test.gd` (12) PASS | — | PASS |
| FM-2 greybox | Integration (+Visual) | `greybox_geometry_test.gd` (9) PASS | Screenshot `facility-map-002-greybox-top.png`. The smoke walk A1 to B1 passed | PASS WITH NOTES: the story's manual check (designer sign-off that every room has two exits and no doorway snags) is not recorded. The smoke walk does not count as that review |
| DC-4 refuse to host | Integration (+UI) | `refuse_to_host_test.gd` (9) PASS | Screenshot `data-config-004-refuse-to-host.png` | PASS WITH NOTES: showing the errors in the host UI waits for the menu story |
| CI-7 interaction targeting | Logic | `interaction_targeting_test.gd` (20) PASS | — | PASS WITH NOTES: the 0.5 m pick radius and the interaction point height are inferences (AD-93) |
| NA-8 handles/relevance | Integration | `handles_relevance_test.gd` (18) PASS | — | PASS WITH NOTES: AC4 ran as a scripted visibility and form-change sequence because there is no round flow yet. form_changed and hidden_from are not wired to their owners yet. Door state replication is not built (AD-95/96) |
| CI-5 controller load checks | Logic | `controller_load_checks_test.gd` (10) PASS | — | PASS |
| NA-V verify NA-1 on a real network | Integration | — | `na-v-real-network-cases.md`, not walked | OUT OF SCOPE: never started (Should Have, backlog), third sprint carried. It needs the designer and a second PC. NH-1 now unblocks every case except NAV-08, which needs EX-1 |
| FM-3 connectivity checks | Logic | `connectivity_test.gd` planned, not written | — | OUT OF SCOPE: never started (Nice to Have, backlog) |
| LB-3 character data/M1 assignment | Logic | `character_assignment_test.gd` planned, not written | — | OUT OF SCOPE: never started (Nice to Have, backlog) |
| EX-1 export preset | Config/Data | — | — | OUT OF SCOPE: never started (Nice to Have, backlog). It waits on the designer's export preset decision (TD-004) |

Every done story went through /code-review with mutation checks.

### Bugs Found
| ID | Story | Severity | Status |
|---|---|---|---|
| BUG-0001 | NH-1 | S4-Low, P3-Backlog | Open. In the net harness route mode, the tool keeps sending after HOST_LEFT. It affects the test tool only, and no AC is affected. |

No bugs were on file at Phase 1: `production/qa/bugs/` did not exist then. It now holds BUG-0001, so later bug counts can be read as real counts. Before this, an empty count meant "no records", not "clean".

### Verdict: APPROVED WITH CONDITIONS
NOT APPROVED was checked first. No S1 or S2 bug is open, and no story failed. The precondition holds. All eight in-scope stories have executed evidence: seven have a test that ran and passed, and NH-1 has a walked manual evidence doc. The smoke check passed.

The verdict is "with conditions" for three reasons. One S4 bug is open. Six stories pass with documented notes. The Sprint 2 conditions are still open.

FM-2 is not held back as unexecuted. Its required Integration test ran, and its screenshot is retained. The missing piece is the designer's review, so it is recorded as a condition.

### Conditions
1. **Real-network verification of NA-1 (NA-V).** It has now been carried into a third sprint. Sprint 004 planning must either schedule it or have the designer waive it explicitly. Carrying it a fourth time without a decision is not acceptable.
   - The run needs the designer and a second PC. Walk `production/qa/test-cases/na-v-real-network-cases.md` with NH-1.
   - The walk also closes the NA-6 two-PC AC, the DC-5 cross-machine half, and NA-3's real-network timing.
   - NAV-08 waits for EX-1.
2. **Retroactive Sprint 1 code review.** It has been carried into a third sprint without being done or waived. The producer must schedule it or waive it explicitly at Sprint 004 planning.
3. **Smoke coverage for menu, session, save and performance.** Add each item when its system lands. Lobby story 005 is the first real menu.
4. **Walk the CI-6 mouse-look cases with the designer.** Do it in the same session as NA-V. CI-6-01 needs a temporary canvas_items stretch mode.
5. **Export preset (TD-004 / EX-1).** This is the designer's decision. It unblocks the DC-5 export-build digest check and NAV-08.
6. **Get the FM-2 designer sign-off.** The designer reviews the screenshot and walks the greybox: every room has two exits and no doorway snags. Record the result in FM-2's evidence. This is about 15 minutes and is not a re-test.
7. **Triage BUG-0001** with /bug-triage. It is S4-Low and may be deferred to polish. Triage should confirm that `disconnect_host_left_test.gd` still covers the real client path for HOST_LEFT, because the harness tool does not cover it.
8. **Track each deferred acceptance criterion against the story that owns it:**
   - NA-3 AC3 main-menu text goes to the menu story.
   - DC-4 host UI error listing goes to the menu story.
   - NA-8 AC4 full-round re-run waits for the round flow. Wiring form_changed and hidden_from to their owners, and door state replication, follow AD-95/96.
   - CI-7 pick radius and interaction height stay inferences (AD-93) until a designer value settles them.
   - Sprint 2 items carry on: FM-1 AC2 and AC4, TD-007, TD-008 and TD-006.

### Next Step
Resolve the conditions before advancing. S3/S4 bugs may be deferred to polish. Conditions 1 and 2 are in their third sprint, so Sprint 004 planning must schedule or waive each one explicitly before any other carried work.
