## QA Sign-Off Report: Sprint 008
**Date**: 2026-10-15
**Build**: 2fe161d
**Drafted by**: qa-lead (Phase 6). The orchestrator checked the verdict against the rules and agrees with it.
**Smoke check**: PASS WITH WARNINGS (`production/qa/smoke-2026-10-15-sprint-008.md`). Warnings:
- The export preset is unset (EX-1).
- The tracked class cache is stale, so a fresh checkout needs `--import`.
- Designer items are pending.
- Open bugs are S3/S4 only.

**Automated suite**: 1393/1393 at 2fe161d, no leak lines.

### Test Coverage Summary

| Story | Type | Auto Test | Manual QA | Result |
|---|---|---|---|---|
| PC-1 Ping validation, token bucket | Logic | PASS | n/a | PASS |
| PC-2 Sender-state gating | Logic | PASS | n/a | PASS |
| PC-3 Callout limits, attached ping | Logic | PASS | n/a | PASS |
| PC-4 Ping recipients, delivery | Integration | PASS (real ENet) | Smoke path 5 done | PASS |
| PC-5 Marker lifecycle | Logic | PASS | n/a | PASS |
| PC-6 Callout recipients | Integration | PASS | Smoke path 5 done | PASS |
| PC-7 Identity and fake parity | Integration | PASS | Smoke path 5 done; the "(not you)" playtest is advisory and has not run | PASS WITH NOTES |
| PC-8 Ping and callout presentation | UI | PASS (supporting only) | 4 png retained. The speaker gesture (AC-4) is not captured on screen; case not walked; no designer review | NO EVIDENCE |
| SE-1 Scare catalogue and module | Logic | PASS | n/a | PASS |
| SE-2 Per-recipient gating | Logic | PASS | n/a | PASS |
| SE-3 Scoped delivery, hallucinations | Integration | PASS (real ENet) | Smoke path 6 done | PASS |
| SE-4 Monster-source scares | Integration | PASS | Smoke path 6 done | PASS |
| SE-5 Ambush lunge and flinch | Integration | PASS | n/a | PASS |
| SE-6 Facility scare state, RoundScript | Integration | PASS, but only with the anchors injected in memory | The shipped map has no scare anchors; case not walked; the user's map decision is pending | BLOCKED |
| SE-7 Presentation-only guarantees | Integration | PASS | n/a | PASS |
| SE-8 Scare audio | Visual/Feel | PASS (supporting only) | 1 png retained. AC-2 (stinger at most +6 dB over the bed) is unproven: the meter's readings varied by 3.6 dB. Case not walked; no lead sign-off | NO EVIDENCE |
| SE-9 Scare visuals, flash accessibility | Visual/Feel | PASS (supporting only) | Strobe and hallucination png retained. AC-3 is not captured: the beacons light no floor, and there is no exit-light shot. Case not walked; no lead sign-off | NO EVIDENCE |

Presenter unit tests do not count as executed evidence for Visual/Feel and UI stories.

### Bugs Found

| ID | Severity | System | Status | Note |
|---|---|---|---|---|
| — | — | — | — | Phase 5 was not executed, so no bugs were filed in it |
| BUG-0001 | S4 | Outside sprint systems | Open | On file |
| BUG-0003 | S3 | Outside sprint systems | Open | On file |
| BUG-0004 | S3 | Outside sprint systems | Open | On file |
| (not filed) | S4 suggested | Pings | Concern | A ping dropped by the per-tick cap gets no rejection echo. Only a modified client can trigger this. |

### Verdict: NOT ASSESSED — NO EVIDENCE

NOT APPROVED does not apply: no S1 or S2 bug is open in scope, and no story FAILs. APPROVED does not apply either, because four stories have no executed evidence:
- **PC-8 (UI)**: no screenshot of the speaker gesture, and the case was not walked.
- **SE-8 (Visual/Feel)**: no lead sign-off, AC-2 is unmeasured, and the case was not walked.
- **SE-9 (Visual/Feel)**: no lead sign-off, AC-3 is not captured, and the case was not walked.
- **SE-6 (Integration)**: blocked on the map decision. If the user declines the map edit, this story FAILs with no workaround, and the verdict becomes NOT APPROVED.

The other 13 stories pass on executed automated tests and stay Complete.

### Conditions
1. **SE-6**: the user decides on adding the 9 scare anchors to `research_facility.tres`. Then walk `facility-scare-state-roundscript-cases.md`.
2. **SE-8**: measure LUFS on recorded audio for AC-2, do a headphone pass, walk `scare-audio-cases.md`, and get the lead sign-off.
3. **SE-9**: capture a beacon shot and an exit-open shot, walk `scare-visuals-accessibility-cases.md`, and get the lead sign-off.
4. **PC-8**: capture the speaker gesture on screen, walk `ping-callout-presentation-cases.md`, and get the designer sign-off.
5. **Fresh checkout**: fix the stale tracked class cache, or document the `--import` step, before any external hand-off.

### Next Step
QA did not run to completion. When the designer is back:
1. Walk the 4 case files in `production/qa/test-cases/`. The estimate is about 3.25 h, plus two playtest sessions.
2. Re-issue this sign-off.

Because S3 bugs are open, the best outcome then is APPROVED WITH CONDITIONS. Do not close the 4 In Review stories or advance the build on this verdict.
