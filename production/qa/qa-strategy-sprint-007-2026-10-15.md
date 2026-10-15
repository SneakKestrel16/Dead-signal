# QA Strategy: Sprint 007

**Date**: 2026-10-15 | **qa.level**: standard | **Automation**: autonomous
**Sources**: `smoke-2026-10-15-sprint-007.md` (Test Coverage), `qa-plan-sprint-007-2026-10-15.md` (Playtest Requirements)

Declared types accepted for all 27 stories. At `standard`, Logic and Integration automated evidence is a BLOCKING gate. Visual/Feel and UI need a retained screenshot plus designer sign-off. All automated tests exist and passed (1277/1277), so no story is blocked on automation. Every blocker below is a manual or decision item.

| Story | Type | Automated Required | Manual Required | Blocker? |
|---|---|---|---|---|
| MF-8 Results payload | Logic | Yes, met (`results_payload_test.gd`) | No | No |
| MF-10 Round composer | Integration | Yes, met (`round_composer_test.gd`) | Standalone round run, done (AD-218) | No |
| MF-11 Client round scene | Integration | Yes, met (`client_round_scene_test.gd`) | Greybox screenshots retained; 240 fps capture (CI-16) | Maybe: see CONCERN 1 |
| MF-12 Display catch-up | Integration | Yes, met | No | No |
| MA-7 Lunge presentation | Visual/Feel | Presenter tests, met | Sign-off; 80%-heard playtest; monster-view lunge-feel playtest | Yes: sign-off |
| MA-8 Ability stats | Logic | Yes, met | No | No |
| MA-9 False Signal | Logic | Yes, met | No | No |
| MA-10 Blackout | Integration | Yes, met | No (SO-9/MA-10 playtest fallback not owed) | No |
| FM-7 Candidate selection | Logic | Yes, met | No | No |
| FM-8 Candidate replication | Integration | Yes, met | No | No |
| FM-9 Lighting state machine | Logic | Yes, met | No | No |
| FM-10 Lighting render and Blackout | Visual/Feel | Presenter and replication tests, met | Sign-off (4 png); frame-budget number to technical-director | Yes: sign-off |
| FM-11 Surveillance cameras | Visual/Feel | Met | Sign-off (11 png) | Yes: sign-off |
| FM-12 Zone ambience | Visual/Feel | Met | Sign-off (3 png) | Yes: sign-off |
| SO-8 Active point selection | Logic | Yes, met | No | No |
| SO-9 Discovery | Integration | Yes, met | No | No |
| SD-10 Hide noise and cue | Integration | Yes, met | 5-client survivor-defense playtest (sprint-6 debt) | No for story; playtest owed |
| SD-11 Per-form presentation | Visual/Feel | Met | Sign-off (7 png) | Yes: sign-off |
| SD-13 Hiding marker facing | Logic | Yes, met | No | Check: GDD conflict (CONCERN 3) |
| SD-14 Barricade input | Integration | Yes, met (real ENet alt-press) | AD-219 decision; client door-state not rendered, so AC3 is server-side proof only | Yes: AD-219 |
| CI-13 View offset and camera FX | Logic | Yes, met | No | No |
| CI-14 Footsteps | Integration | Yes, met | 18 m trial, at least 9 of 10 (AC-4), recording retained | Yes: AC-4 trial unrun |
| BF-9 Disguise rendering | Visual/Feel | Met | Sign-off (3 png) | Yes: sign-off |
| BF-10 Transform warp and audio | Visual/Feel | Met | Sign-off (4 png); warp subtlety review; distortion-bearing listening test | Yes: sign-off |
| LB-5 Lobby screen | UI | Met | Sign-off (6 png) | Yes: sign-off |
| LB-6 No role indicators | Visual/Feel | Met | Sign-off (4 png) | Yes: sign-off |
| LB-12 Queue order display | UI | Met | Sign-off (4 png); AD-216 | Yes: sign-off, AD-216 |

**Smoke Check**: PASS WITH WARNINGS. Suite is 1277/1277, the composed 5-client round reaches RoundEnded, and the boot screenshot is retained. Hand-off to manual QA is allowed from the editor binary. Warnings: `commands.build` and the export preset are unset (EX-1, no exported build exists); 12 sign-offs pending; AD-216, AD-217 and AD-219 pending.

**Open bugs in scope**: BUG-0001 (S4), BUG-0003 (S3, real-ENet timing under load), BUG-0004 (S3). No S1 or S2, so nothing blocks at `standard`. Re-run BUG-0003 and BUG-0004 files alone before treating a failure as a regression.

## Manual sessions the designer owes (estimate)

| # | Session | Players | Est. time |
|---|---|---|---|
| 1 | Evidence sign-off pass: review png and tick the sign-off for 10 Visual/Feel and UI pages (about 51 png) plus the 2 other In Review stories | 1 | 2-3 h |
| 2 | Decisions AD-216, AD-217, AD-219 (AD-219 unblocks SD-14) | 1 | 30 min |
| 3 | Monster-view lunge feel playtest, with the MA-7 80%-heard check folded in. Sprint-6 debt; MA-2 prediction has never been played | 2 | 1 h |
| 4 | 5-client survivor-defense playtest (sprint-6 debt; MF-12 is done, so reconnect may be included) | 5 | 1.5-2 h |
| 5 | CI-14 18 m footstep trial (10 trials, two testers, recorded) | 2 | 45 min |
| 6 | BF-10 warp subtlety and distortion-bearing listening test (headphones) | 1 | 30 min |

Total: 6 sessions, about 7-8 h. Sessions 3 and 5 can share one 2-player sitting, which gives 5 sittings. Only sessions 4 and 5 need other people. SO-9/MA-10 playtest fallback is not owed because both integration tests exist.

## Concerns

1. **Unidentified In Review story.** The smoke table shows 10 Visual/UI rows plus SD-14 with sign-off or decision pending, which is 11. The brief says 12. The twelfth is not named in the report. It is probably MF-11 (AD-217, 240 fps capture) or CI-14. Confirm against `production/sprint-status.yaml`.
2. **Evidence filename mismatch.** The QA plan names LB-12's page `queue-order-display-evidence.md`. The smoke report names it `lobby-queue-order-evidence.md`. Fix whichever is wrong.
3. **SD-13 vs GDD.** The plan's open concern (AC-3 marker fallback against the first-person-controller edge case) has no recorded designer ruling. The test passed against the story's AC, not necessarily the GDD.
4. **No performance budget.** FM-10 `--measure` was not run, and FM-11 numbers were taken on greybox with an RTX 5070 only.
5. **Placeholder audio.** BF-10 and MA-7 sign-off is for placeholder tones on the default bus. Final audio will need re-verification.
