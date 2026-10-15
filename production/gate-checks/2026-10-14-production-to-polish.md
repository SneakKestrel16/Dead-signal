## Gate Check: Production → Polish

**Date**: 2026-10-14
**Checked by**: gate-check skill (workflow: standard, qa.level: standard, review_mode: lean, performance.enforce: warn)
**Gate confirmation**: Auto-accepted (recommended option), 2026-10-14. Production → Polish was detected from `project.yaml` `project.stage: Production` (AD-118).

### Required Artifacts (standard tier): 2/5 met
- [ ] Core mechanics from the GDDs implemented. FAIL. 7 of the 12 system GDDs have no epic and no code in `src/`: match-flow, monster-abilities, downing-and-rescue, survivor-defense, survivor-objectives, scare-events, pings-and-callouts. A grep of `src/` finds them only in comments and knob files (`downing_knobs.gd`). The 7 epics cover foundation, controller, facility map, lobby and borrowed-face. Story status: 36 Complete, 23 Ready, 12 Blocked.
- [x] Smoke check PASS. `production/qa/smoke-2026-10-14-sprint-004.md` was spot-read and its claims hold against the tree: 41 test suites exist under `tests/unit/` and `tests/integration/`, the gdUnit4 runner is present, and the report is dated after the last code commit (`d7136a6`).
- [ ] Main gameplay path playable end-to-end. FAIL. `src/main.tscn` is a placeholder boot scene that shows knob health. There is no main menu and no round scene.
- [ ] 1+ documented playtest. FAIL. `production/qa/playtests/` does not exist.
- [x] No open S1 Critical bugs. Open bugs are BUG-0002 and BUG-0003 (S3) and BUG-0001 (S4).

Recommended at standard:
- [x] QA sign-off: `production/qa/qa-signoff-sprint-004-2026-10-14.md`, APPROVED WITH CONDITIONS.
- [x] Per-story test coverage: every Logic and Integration story of Sprint 4 has a test (smoke report).

### Quality Checks
- [x] Tests passing: 484/484 (smoke run, 2026-10-14, after the last code commit).
- [x] No open S1 bugs.
- [ ] Core loop plays as designed. Not testable: there is no round.
- [-] Performance within budget. CONCERNS: `project.yaml` sets no `performance.*` budgets and there is no profiling data (advisory at `warn`).
- [-] Playtest, confusion-loop, difficulty-curve, UX-spec, pattern-library and accessibility items: dropped at `standard`.

### Director Panel Assessment
Technical Director: NOT READY. 7 core system GDDs have no code. There is no playable path and no playtest. ADR-0009 (lighting and blackout) and ADR-0010 (Borrowed Face rendering) are still Proposed and block 12 stories. No performance budgets are set (concern).

Producer: NOT READY. Not playable end to end, which also fails milestone-01's own exit ("carry both drives out wins"). No playtest. 35 open stories is more than 2 sprints at 1 developer and 8 days per sprint.

Panel: 2 of 4 (`workflow: standard`, from `modes.rigor: standard`). Creative and Art perspectives were not consulted. Raise `modes.rigor` to `full` for the complete panel.

### Blockers
1. **Core mechanics missing.** Seven gameplay systems have no epics. Run `/create-epics` and `/create-stories` for match-flow, survivor-objectives and downing-and-rescue first, since milestone-01 needs them. The rest follow.
2. **No playable round.** Build a round scene that loads the facility greybox, spawns players, and wires drives, terminal and exit to a win. Add a boot-to-round flow; the menu can be a stub. This is milestone-01's exit condition.
3. **No playtest.** Once the round exists, run and document one playtest in `production/qa/playtests/`, with retained screenshots in `production/qa/evidence/`.

### Recommendations
- Plan Sprint 5 around the round-scene integration story as the critical path (producer). Schedule BUG-0002 there as well (QA sign-off condition 2).
- Triage the 23 Ready and 12 Blocked stories against the milestone-01 path, and defer what the slice does not need.
- Decide ADR-0009 and ADR-0010 (`/architecture-decision accept`), which unblocks 12 stories.
- Set `performance.*` budgets in `project.yaml` before Polish.
- Set `commands.build` (smoke advisory).

### Verdict: FAIL
Three required items are missing: core mechanics, a playable path and a playtest. Both directors returned NOT READY. `project.stage` stays **Production**.

Chain-of-Verification: 5 questions checked, 2 with tool actions:
- A grep of `src/` for match-flow, downing and scare code found no implementation.
- A grep of `project.yaml` found no `performance` block.
- The blockers are separated from the advisory items.
- The minimal path to PASS is the three blockers above.
- The fail condition is unfinished scope, not a design flaw.

Verdict unchanged.
