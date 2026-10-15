## QA Sign-Off Report: Sprint 6
**Date**: 2026-10-15
**Inputs**: strategy `production/qa/qa-strategy-sprint-006-2026-10-15.md`; QA plan `production/qa/qa-plan-sprint-006-2026-10-15.md`; smoke `production/qa/smoke-2026-10-15-sprint-006.md` (PASS).
**Run shape**: team.size `individual`. `qa-lead` ran at the strategy and sign-off gates. `qa-tester` was not spawned: there are no manual-QA stories (no Visual/Feel, UI or Config/Data).

### Test Coverage Summary
| Story | Type | Auto Test | Manual QA | Result |
|---|---|---|---|---|
| SD-001 Defense module, charges, intents | Logic | `tests/unit/survivor-defense/defense_charges_test.gd` (8): PASS | Not required | PASS |
| SD-002 Taser trace | Logic | `tests/unit/survivor-defense/taser_trace_test.gd` (10): PASS | Not required | PASS |
| SD-003 Shock lock, post-lock window | Logic | `tests/unit/survivor-defense/shock_lock_test.gd` (9): PASS | Not required | PASS |
| SD-004 Monster stun, immunity, cancels | Logic | `tests/unit/survivor-defense/monster_stun_test.gd` (16): PASS | Not required | PASS WITH NOTES (SD-5 StunResisted event pending a designer decision) |
| SD-005 Identity-hiding events | Integration | `tests/integration/survivor-defense/identity_hiding_events_test.gd` (5): PASS | Not required | PASS WITH NOTES (AD-194 replication scope pending; no reconnect catch-up for CHARGES/HIDING/BARRICADE) |
| SD-006 Hiding spots | Integration | `tests/integration/survivor-defense/hiding_spots_test.gd` (12): PASS | Not required | PASS WITH NOTES (SD-6 hiding marker facing pending) |
| SD-007 Barricade build/remove, door block | Integration | `tests/integration/survivor-defense/barricade_doors_test.gd` (12): PASS | Not required | PASS |
| SD-008 Barricade break, lockout | Logic | `tests/unit/survivor-defense/barricade_break_test.gd` (8): PASS | Not required | PASS |
| SD-009 Flashlight toggle | Integration | `tests/integration/survivor-defense/flashlight_toggle_test.gd` (7): PASS | Not required | PASS |
| SD-012 Five-client agreement, stand-ins retired | Integration | `tests/integration/survivor-defense/five_client_agreement_test.gd` (1), `tests/unit/survivor-defense/defense_knob_literals_test.gd` (3): PASS | Not required | PASS |
| MA-001 Request validation, Lunge states | Logic | `tests/unit/monster-abilities/request_validation_test.gd` (12): PASS | Not required | PASS |
| MA-002 Wind-up and dash | Integration | `tests/integration/monster-abilities/lunge_movement_test.gd` (13): PASS | Optional feel playtest deferred (no round composer) | PASS WITH NOTES (monster-client prediction is an inference, not playtested) |
| MA-003 Hit test, lag compensation | Logic | `tests/unit/monster-abilities/lunge_hit_test_test.gd` (14), `tests/integration/monster-abilities/lunge_lag_comp_test.gd` (9): PASS | Not required | PASS WITH NOTES (MA-3 cone to body edge vs centre pending) |
| MA-004 Resolution, cooldown, miss slow | Logic | `tests/unit/monster-abilities/lunge_resolution_test.gd` (10): PASS | Not required | PASS WITH NOTES (MA-4 hit on the disconnect tick pending) |
| MA-005 AbilityUsed and state | Integration | `tests/integration/monster-abilities/ability_used_hiding_test.gd` (5): PASS | Not required | PASS |
| MA-006 Integrate Downing, Borrowed Face | Integration | `tests/integration/monster-abilities/lunge_end_to_end_test.gd` (3): PASS | Not required | PASS |

Executed evidence:
- All 16 stories have it. Every test passed in the full run, 1057/1057 at `8557fd2` with 0 leaks.
- The smoke check passed.
- No manual cases were required.
- This cycle filed no new bugs.

### Bugs Found
| ID | Story | Severity | Status |
|---|---|---|---|
| BUG-0003 | Cross-cutting: network-authority real-ENet test harness (fired once on `transforming_visibility_test` under parallel load, passed when run alone) | S3-Medium | Open |

Also on file but outside these epics, so not counted in the verdict:
- BUG-0004 (S3-Medium, Open): the controller tick budget depends on the host machine.
- BUG-0001 (S4-Low, Open): the net harness tool.

There are no open S1 or S2 bugs.

### Verdict: APPROVED WITH CONDITIONS

**Conditions**
1. BUG-0003 (S3) stays open as a known flake risk. Track it, and do not widen the timing bound to hide it. Fix it before the full ENet suite is run in parallel in CI, or defer it to polish.
2. Five designer decisions are still pending:
   - AD-194: replication scope
   - SD-5: a StunResisted event
   - SD-6: hiding marker facing
   - MA-3: cone measured to the body edge or the body centre
   - MA-4: a hit on the disconnect tick

   The stories pass as currently implemented. Whatever the designer decides must be re-verified with a targeted test re-run.
3. Nothing from this sprint can be played yet, because there is no composition root and the hooks are wired only in tests. The MA-002 prediction behaviour is an inference nobody has played. The sprint that adds the round composer owes two playtests: a monster-view lunge feel playtest, and a 5-client survivor-defense playtest.
4. Reconnect catch-up for the CHARGES, HIDING and BARRICADE display entries is missing. Schedule it before any playtest that includes reconnects.
5. `commands.build` is still unset in `project.yaml`, so no build has been checked. Set it before the first build goes to manual QA.

### Next Step
Resolve conditions before advancing. S3/S4 bugs may be deferred to polish.
