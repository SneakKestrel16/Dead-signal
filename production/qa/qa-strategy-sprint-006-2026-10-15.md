# QA Strategy: sprint-006 (2026-10-15)

Stage: Production. `qa.level`: standard (Logic/Integration evidence = an automated test that ran). Types are as declared in each story header; all 16 are Status Complete, all ACs ticked (0 unticked; AC counts match the QA Test Cases blocks), Test Evidence ticked with a test file.

| Story | Type | Automated Required | Manual Required | Blocker? |
|---|---|---|---|---|
| SD-001 Defense module, charges, intents | Logic | `tests/unit/survivor-defense/defense_charges_test.gd` (8) - ran | No | No |
| SD-002 Taser trace | Logic | `.../taser_trace_test.gd` (10) - ran | No | No |
| SD-003 Shock lock, post-lock window | Logic | `.../shock_lock_test.gd` (9) - ran | No | No |
| SD-004 Monster stun, immunity, cancels | Logic | `.../monster_stun_test.gd` (16) - ran | No | No |
| SD-005 Identity-hiding events | Integration | `tests/integration/survivor-defense/identity_hiding_events_test.gd` (5) - ran | No | No |
| SD-006 Hiding spots | Integration | `.../hiding_spots_test.gd` (12) - ran | No | No |
| SD-007 Barricade build/remove, door block | Integration | `.../barricade_doors_test.gd` (12) - ran | No | No |
| SD-008 Barricade break, lockout | Logic | `tests/unit/survivor-defense/barricade_break_test.gd` (8) - ran | No | No |
| SD-009 Flashlight toggle | Integration | `tests/integration/survivor-defense/flashlight_toggle_test.gd` (7) - ran | No | No |
| SD-012 Five-client agreement, stand-ins retired | Integration | `.../five_client_agreement_test.gd` (1), `tests/unit/survivor-defense/defense_knob_literals_test.gd` (3) - ran | No | No |
| MA-001 Request validation, Lunge states | Logic | `tests/unit/monster-abilities/request_validation_test.gd` (12) - ran | No | No |
| MA-002 Wind-up and dash | Integration | `tests/integration/monster-abilities/lunge_movement_test.gd` (13) - ran | Optional: monster-view feel playtest (prediction note, story line 114, is an inference) | No |
| MA-003 Hit test, lag compensation | Logic | `tests/unit/monster-abilities/lunge_hit_test_test.gd` (14), `tests/integration/monster-abilities/lunge_lag_comp_test.gd` (9) - ran | No (designer decision pending: cone to body edge vs centre) | No |
| MA-004 Resolution, cooldown, miss slow | Logic | `tests/unit/monster-abilities/lunge_resolution_test.gd` (10) - ran | No (designer decision pending: hit on disconnect tick) | No |
| MA-005 AbilityUsed and state | Integration | `tests/integration/monster-abilities/ability_used_hiding_test.gd` (5) - ran | No | No |
| MA-006 Integrate Downing, Borrowed Face | Integration | `tests/integration/monster-abilities/lunge_end_to_end_test.gd` (3) - ran | No | No |

Classification: 8 Logic (SD-001/002/003/004/008, MA-001/003/004), 8 Integration (SD-005/006/007/009/012, MA-002/005/006). No Visual/Feel, UI or Config/Data stories, so no screenshot evidence is owed by these stories.

**Manual QA sessions estimate**: 0 required. No story is Visual/UI, and no composition root exists, so none of this sprint's features can be played in a build yet. Optional: 1 session (about 2 h) for a monster-view lunge feel playtest, plus 1 session (about 2 h) for a 5-client survivor-defense playtest. Both are deferred until a round composer wires the hooks; schedule them for the sprint that adds it.

**Smoke Check**: PASS - 1057/1057 at 8557fd2 (`production/qa/smoke-2026-10-15-sprint-006.md`), 16 covered / 0 missing. Advisory (non-blocking): no composition root (hooks wired only in tests); no reconnect catch-up for CHARGES/HIDING/BARRICADE display entries; `commands.build` still `[TO BE CONFIGURED]`. Pending designer decisions: AD-194, SD-5, SD-6, MA-3, MA-4.

**Open bugs in scope**: BUG-0003 (S3-Medium, network-authority real-ENet timing flake; fired once on `transforming_visibility_test` under parallel load, passed alone twice; bound not widened). Not blocking at `standard`: it is a risk, S1 only blocks. BUG-0004 (S3-Medium, controller tick budget host-dependent) listed for completeness, outside these epics. BUG-0001 (S4-Low, net harness) out of scope. BUG-0002 is Verified Fixed. No S1/S2 bugs.

**Blockers to QA hand-off**: none.
