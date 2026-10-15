## QA Sign-Off Report: Sprint 007
**Date**: 2026-10-15
**Drafted by**: qa-lead (Phase 6). The orchestrator checked the verdict against the rules and agrees with it. Two corrections, both noted under Conditions:
- SD-13 AC-3 is already resolved.
- The LB-12 filename is fixed in the story.

### Test Coverage Summary
| Story | Type | Auto Test | Manual QA | Result |
|---|---|---|---|---|
| MF-8 Results payload | Logic | PASS (`results_payload_test.gd`) | Not required | PASS |
| MF-10 Round composer | Integration | PASS (`round_composer_test.gd`) | Standalone round done (AD-218); the smoke check confirmed it reaches RoundEnded | PASS |
| MF-11 Client round scene | Integration | PASS (`client_round_scene_test.gd`) | NOT EXECUTED: `client-round-scene-cases.md` not walked. The remote-flashlight-in-view clause is covered by the integration test only. AD-217 pending | PASS WITH NOTES (In Review) |
| MF-12 Display catch-up | Integration | PASS | Not required | PASS |
| MA-7 Lunge presentation | Visual/Feel | PASS (presenter tests) | NOT EXECUTED: `lunge-presentation-cases.md` not walked, no sign-off. The 20 m clause is unit-test only. The 80%-heard and lunge-feel playtests have not run | NOT ASSESSED |
| MA-8 Ability stats | Logic | PASS | Not required | PASS |
| MA-9 False Signal | Logic | PASS | Not required | PASS |
| MA-10 Blackout | Integration | PASS | Not required | PASS |
| FM-7 Candidate selection | Logic | PASS | Not required | PASS |
| FM-8 Candidate replication | Integration | PASS | Not required | PASS |
| FM-9 Lighting state machine | Logic | PASS | Not required | PASS |
| FM-10 Lighting render and Blackout | Visual/Feel | PASS | NOT EXECUTED: `lighting-render-cases.md` not walked, no sign-off (4 png). The frame budget is recorded as a number only | NOT ASSESSED |
| FM-11 Surveillance cameras | Visual/Feel | PASS | NOT EXECUTED: `surveillance-cameras-cases.md` not walked, no sign-off (11 png). The orchestrator spot-checked screenshots against the page | NOT ASSESSED |
| FM-12 Zone ambience | Visual/Feel | PASS | NOT EXECUTED: `zone-ambience-cases.md` not walked, no sign-off (3 png) | NOT ASSESSED |
| SO-8 Active point selection | Logic | PASS | Not required | PASS |
| SO-9 Discovery | Integration | PASS | Not required | PASS |
| SD-10 Hide noise and cue | Integration | PASS | The 5-client survivor-defense playtest is still owed (sprint-6 debt) | PASS WITH NOTES |
| SD-11 Per-form presentation | Visual/Feel | PASS | NOT EXECUTED: `per-form-presentation-cases.md` not walked, no sign-off (7 png) | NOT ASSESSED |
| SD-13 Hiding marker facing | Logic | PASS | Not required. AC-3 follows the controller GDD edge case (line 245): nearest free point within 1 m, otherwise the exit waits | PASS |
| SD-14 Barricade input | Integration | PASS (real-ENet alt press; all 4 ACs) | Not required. AC3 is proven server-side only, because the client renders no door state | PASS WITH NOTES (In Review, AD-219) |
| CI-13 View offset and camera FX | Logic | PASS | Not required | PASS |
| CI-14 Footsteps | Integration | PASS | The AC-4 18 m trial has not run | PASS WITH NOTES |
| BF-9 Disguise rendering | Visual/Feel | PASS | NOT EXECUTED: `disguise-rendering-cases.md` not walked, no sign-off (3 png). The drive-carrier and Downed-copy clauses cannot be tested yet | NOT ASSESSED |
| BF-10 Transform warp and audio | Visual/Feel | PASS | NOT EXECUTED: `transform-warp-audio-cases.md` not walked, no sign-off (4 png). Warp subtlety and the listening test are pending | NOT ASSESSED |
| LB-5 Lobby screen | UI | PASS | NOT EXECUTED: `lobby-screen-cases.md` not walked, no sign-off (6 png) | NOT ASSESSED |
| LB-6 No role indicators | Visual/Feel | PASS | NOT EXECUTED: `no-role-indicators-cases.md` not walked, no sign-off (4 png) | NOT ASSESSED |
| LB-12 Queue order display | UI | PASS | NOT EXECUTED: `queue-order-display-cases.md` not walked, no sign-off (4 png). AD-216 pending | NOT ASSESSED |

Totals:
- 27 stories: 10 PASS, 7 PASS WITH NOTES, 10 NOT ASSESSED, 0 FAIL.
- Suite at `4401e6b`: 1277/1277.
- Smoke check: PASS WITH WARNINGS (`production/qa/smoke-2026-10-15-sprint-007.md`).

**Presenter unit tests do not count as executed evidence for Visual/Feel and UI stories.** The testing standards require a retained screenshot plus a lead sign-off for these stories. A presenter test proves the presenter's state, not how the frame looks or sounds. A screenshot that no lead has judged is a capture, not a verdict.

### Bugs Found
No bugs were filed this cycle. Open bugs in scope:

| ID | Story / System | Severity | Status |
|----|-------|----------|--------|
| BUG-0001 | net_check route mode keeps sending input after HOST_LEFT | S4-Low | Open |
| BUG-0003 | Real-ENet timing under load (killed-server detection 4.3 s vs 3.0 s) | S3-Medium | Open |
| BUG-0004 | Controller tick budget p95 620-670 µs vs 500 µs | S3-Medium | Open |

### Verdict: NOT ASSESSED — NO EVIDENCE

The NOT APPROVED rule does not apply: no S1 or S2 bug is open and no story FAILs.

The precondition is not met. Ten stories have no executed evidence against their required gate, because the Phase 5 manual QA was not run. The designer is away, no case was walked, no sign-off is ticked, and nobody answered on the designer's behalf. The ten are:
- Visual/Feel: MA-7, FM-10, FM-11, FM-12, SD-11, BF-9, BF-10, LB-6.
- UI: LB-5, LB-12.

The other 17 stories have executed evidence. If the ten pass, the expected verdict is APPROVED WITH CONDITIONS. That is a projection, not a verdict.

**Conditions**

Required to reach a verdict:
1. Walk the 10 manual case files in `production/qa/test-cases/` and tick the lead sign-off on each evidence page.
2. Decide AD-216 (LB-12), AD-217 (MF-11, hold target on the wire) and AD-219 (SD-14, barricade on key G).

Carried into APPROVED WITH CONDITIONS:

3. BUG-0003 and BUG-0004 (S3) stay open at P2. BUG-0001 (S4) stays in the backlog. Re-run each flaky file alone before calling a failure a regression.
4. Owed manual sessions:
   - CI-14 AC-4 18 m trial.
   - MA-7: 80%-heard check and the monster-view lunge-feel playtest.
   - BF-10: warp subtlety and headphone listening.
   - SD-10: 5-client survivor-defense playtest.
5. FM-10's frame-budget number goes to technical-director. No performance budget exists yet.
6. BF-10, MA-7, FM-12 and SD-11 sign-offs cover placeholder audio. Re-verify them when final audio lands.
7. Smoke warning: `commands.build` and the export preset are unset (EX-1), so manual QA runs from the editor binary only.

Resolved during drafting:
- SD-13 AC-3: already follows the GDD (story file, ticked).
- LB-12: the story's evidence path now names `lobby-queue-order-evidence.md`.

### Next Step
QA did not run to completion. When the designer is back:
1. Walk the 10 case files and tick the sign-offs.
2. Decide AD-216, AD-217 and AD-219.
3. Re-run `/team-qa sprint-007` Phase 6.

Do not close the 12 In Review stories or advance the build on this verdict.
