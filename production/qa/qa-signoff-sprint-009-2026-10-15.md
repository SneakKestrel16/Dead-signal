## QA Sign-Off Report: Sprint 009
**Date**: 2026-10-15
**Build**: a8a14d2
**Drafted by**: qa-lead (Phase 6). The orchestrator checked the verdict against the rules and agrees. It corrected one fact: the ADR-0014 verification evidence is on disk (`d6beffc`), so the HUD-1 row and condition 4 differ from the draft.
**Smoke check**: PASS WITH WARNINGS (`production/qa/smoke-2026-10-15-sprint-009.md`). The warnings:
- the BUG-0012 flake (since fixed);
- the export preset is unset (EX-1);
- the stale class cache;
- designer items still pending.

**Automated suite**: 1575/1575 at a8a14d2, 0 leak lines.
**Manual QA**: the designer playtested the shipped build on 2026-10-15. Every session passed:
- lobby start;
- always-on HUD;
- the survivor session;
- the shapeshifter session;
- spectating.

One finding: a disguised lunge did nothing. That became design change MA-12, now done.

### Test Coverage Summary

| Story | Type | Auto Test | Manual QA | Result |
|---|---|---|---|---|
| MF-13 Lobby to round wiring | Integration | PASS | 8 png; lobby start playtested | PASS |
| MF-14 Register round stats views | Integration | PASS | `results.png`, `results-survivor-host.png`; Results with stats playtested | PASS |
| HUD-1 HudModel, UiLayers, InputContextStack | Logic | PASS | ADR-0014 items 1, 2, 4, 5 and 6 PASS (`production/qa/evidence/ui-input-focus/adr-0014-verification.md`). Item 3 (NVDA) NOT ASSESSED; it is manual | PASS WITH NOTES |
| HUD-11 Server feeds | Integration | PASS (real ENet) | 2 png; feed playtested | PASS |
| SD-15 Taser fire input | Integration | PASS | taser playtested | PASS |
| MA-12 Disguised lunge (design change) | Integration | PASS (real ENet) | came out of the playtest | PASS |
| HUD-2 Always-on HUD | UI | support PASS | 4 png; playtested; designer approved (AD-242) | PASS |
| HUD-3 Prompt, ring, reject | UI | support PASS | 4 png; playtested; AD-242 | PASS |
| HUD-4 Own state, state table | UI | support PASS | 4 png; spectating playtested; AD-242 | PASS |
| HUD-5 Edge cues, taser count, progress | UI | support PASS | 5 png; playtested; AD-242 | PASS |
| HUD-6 Shapeshifter HUD | UI | support + absence test PASS | 4 png; playtested; AD-242. After-fix shot for BUG-0013 is `after/bug-0013-trueform.png` | PASS WITH NOTES |
| HUD-7 Feed and marker conformance | UI | support PASS | 3 png; AD-242 | PASS |
| HUD-8 Results screen | UI | support PASS | 6 png; playtested; AD-242. The 500 ms cross-client bound and the 150% margins were not captured | PASS WITH NOTES |
| HUD-9 Lobby Last round | UI | support PASS | 3 png; AD-242 | PASS |
| HUD-10 Budget and accessibility | UI | n/a | evidence md + 44 png; AD-242. Item ping shape and 3 text sizes not captured | PASS WITH NOTES |
| HUD-12 Gamepad bindings | UI | support PASS | 1 png; AD-242. AC2 (physical gamepad) waived by the designer (AD-241) | PASS WITH NOTES |
| MA-11 Client ability input | UI | support PASS | 7 png; R/X previews playtested; AD-242 | PASS |
| BF-11 Client form picker | UI | support PASS | 4 png; transform playtested; AD-242 | PASS |
| SE-6 Facility scare state (carried) | Integration | PASS | shipped map has 9 anchors; a live round fired a RoundScript scare with nothing injected | PASS |
| MF-11 Client round scene (carried) | Integration | PASS | cases not walked (AD-217); the playtest ran the round scene | PASS WITH NOTES |
| SD-14 Barricade input (carried) | Integration | PASS | not required (AD-219) | PASS WITH NOTES |
| PC-8 Ping callout presentation (carried) | UI | support PASS | 4 png + AC-4 `gesture.png`; pings playtested; sign-off row unticked | PASS WITH NOTES |
| pings-11 Warning pings, feed scrollback (carried) | UI | support PASS | 3 png; feed playtested; unticked | PASS WITH NOTES |
| LB-5 Lobby screen (carried) | UI | support PASS | 6 png; lobby playtested; unticked | PASS WITH NOTES |
| LB-12 Queue order display (carried) | UI | support PASS | 4 png; unticked (AD-216) | PASS WITH NOTES |
| BF-9 Disguise rendering (carried) | Visual/Feel | support PASS | 3 png; no lead sign-off | NO EVIDENCE |
| BF-10 Transform warp audio (carried) | Visual/Feel | support PASS | 4 png; listening test and sign-off unticked | NO EVIDENCE |
| LB-6 No role indicators (carried) | Visual/Feel | support PASS | 4 png; no lead sign-off | NO EVIDENCE |
| FM-10 Lighting render (carried) | Visual/Feel | support PASS | 4 png; no lead sign-off | NO EVIDENCE |
| FM-11 Surveillance cameras (carried) | Visual/Feel | support PASS | 11 png; no lead sign-off | NO EVIDENCE |
| FM-12 Zone ambience (carried) | Visual/Feel | support PASS | 3 png; no lead sign-off | NO EVIDENCE |
| MA-7 Lunge presentation (carried) | Visual/Feel | support PASS | 3 png; lunge playtested; no lead sign-off | NO EVIDENCE |
| SD-11 Per-form presentation (carried) | Visual/Feel | support PASS | 7 png; no lead sign-off | NO EVIDENCE |
| SE-8 Scare audio (carried) | Visual/Feel | support PASS | 1 png; AC-2 (stinger at most +6 dB) unproven; no sign-off | NO EVIDENCE |
| SE-9 Scare visuals (carried) | Visual/Feel | support PASS | AC-3 not captured: the beacons light no floor and there is no exit-light shot; no sign-off | NO EVIDENCE |

**How the rows are graded:**
- Presenter unit tests do not count as executed evidence for Visual/Feel or UI stories. This matches the sprint-008 sign-off.
- A Visual/Feel story needs screenshots plus a lead sign-off. A general playtest that showed the feature does not replace the sign-off.

### Bugs Found

A bug is open unless its Status is Closed or Verified Fixed.

| ID | Severity | System | Status | Note |
|---|---|---|---|---|
| BUG-0008 | S3 | hud-results / pings | Fixed, unverified | Reduced motion did not stop fades |
| BUG-0009 | S4 | hud-results | Fixed, unverified | Install alert was 18 px |
| BUG-0010 | S3 | hud-results | Fixed, unverified | Shapeshifter HUD text was 16 px |
| BUG-0011 | S4 | facility (FM-12) | Fixed, unverified | Ambience debug label was drawn in the HUD |
| BUG-0012 | S3 | network | Fixed, unverified | Killed-host detection flake |
| BUG-0013 | S4 | hud-results | Fixed, unverified | Kit was 16 px from the edge instead of 48 px |
| BUG-0014 | S3 | core/controller, ui | Fixed, unverified | First mouse motion after recapture. The designer saw no jump with a real mouse |
| BUG-0015 | S4 | match-flow | Fixed, unverified | Host kept predicting at round end |
| BUG-0016 | S3 | pings | Fixed, unverified | `unproject_position` error spam |
| BUG-0001 | S4 | net harness (outside) | Open | On file |
| BUG-0003 | S3 | network-authority (outside) | Open | May share a cause with BUG-0012 |
| BUG-0004 | S3 | controller tick budget (outside) | Open | On file |

No S1 bug is on file and no S2 bug is open. BUG-0005, BUG-0006 and BUG-0007 are Verified Fixed.

### Verdict: NOT ASSESSED — NO EVIDENCE

**Why not NOT APPROVED:** no S1 or S2 bug is open, and no story FAILs. SE-6 now passes on the shipped map.

**Why not APPROVED WITH CONDITIONS:** 10 carried Visual/Feel stories have no executed evidence that meets their gate.
- BF-9, BF-10, LB-6, FM-10, FM-11, FM-12, MA-7 and SD-11 have screenshots, but no lead sign-off and no walked cases.
- SE-8 is also missing a measurement of AC-2.
- SE-9 is also missing a capture of AC-3.

**Sub-verdict for the 19 sprint-9 stories only (the 18 done this sprint plus SE-6): APPROVED WITH CONDITIONS.**
- All 19 have executed evidence and PASS or PASS WITH NOTES.
- No S1 or S2 bug is open.
- Nine S3/S4 bugs are Fixed but unverified.

### Conditions
1. **Lead sign-off on the 10 Visual/Feel stories.**
   - Walk their case files.
   - SE-8: measure LUFS on recorded audio.
   - SE-9: capture a beacon shot and an exit-open shot. The beacons need a Facility Map placement fix or a designer ruling.
2. **Designer close-out of PC-8, pings-11, LB-5 and LB-12.** Their evidence is on disk, but their sign-off rows are unticked.
3. **Verify the nine Fixed bugs (0008 to 0016)** with `/bug-report verify`.
4. **ADR-0014 item 3 (NVDA).** It is manual and stays NOT ASSESSED until someone runs it. The designer waivers are already recorded: HUD-12 AC2 and NA-V (AD-241).
5. **Before any external hand-off:** set the export preset (EX-1) and fix or document the stale class cache.

### Next Step
- The sprint-9 work stands on its sub-verdict. Do not advance the build on the overall verdict yet.
- Once the designer has signed off the 10 Visual/Feel stories (condition 1), re-issue this report.
- With the nine Fixed bugs verified first, the report can reach APPROVED. Otherwise the best outcome is APPROVED WITH CONDITIONS.

### Addendum (2026-10-15, after the sign-off)

- Condition 3 progress: an independent verifier re-checked the nine bugs on `aa581ab` (`2c8bbbe`).

  - Verified Fixed: BUG-0008, 0009, 0010, 0011, 0012, 0013, 0015 and 0016.

  - BUG-0014 reproduced in a window: a zero OS motion spent the discard.

- BUG-0014 was re-fixed in `5887fda`. The windowed V4 test passed 5 of 5 runs, and the full suite is 1576/1576. Its status is Fixed and still awaits a second check.

- Neither verdict changes: one S3 bug is still unverified, and the 10 Visual/Feel sign-offs are still outstanding.
