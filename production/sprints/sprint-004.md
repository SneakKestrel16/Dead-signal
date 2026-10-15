# Sprint 004 — 2026-11-24 to 2026-12-07

> PR-SPRINT skipped (lean mode). No milestone is open: Milestone 1 (vertical slice) closed 2026-10-13, so this sprint is planned against the story backlog alone. There is no risk register; risks are assessed from the sprint contents and the Milestone 1 register.
> QA plan: `production/qa/qa-plan-sprint-004-2026-10-14.md`.
> Inputs: the conditions in `production/qa/qa-signoff-sprint-003-2026-10-14.md`. No Sprint 3 retrospective was written; the sign-off conditions and AD-83 to AD-101 carry its lessons.
> Auto-decided (AD-102, autonomous mode; the designer did not answer the four open items): NA-V is scheduled (not waived) as a Must Have designer session; the Sprint 1 retroactive code review is scheduled as agent work (SR-1), since agents can run it; EX-1 carries as Nice to Have and its commit question is decided when the story starts; the FM-2 greybox sign-off is a designer task under External Factors.

## Sprint Goal
Close the Sprint 1 review (carried three sprints), then give the server its first rule loop: speed modifiers, holds that start and complete, event projection to clients, and the locked roster handed to Match Flow.

## Capacity
- Total days: 10 (one developer, working days)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

Sprint 3 completed every Must Have and Should Have (8 days estimated) plus two Nice to Haves in one agent session; its misses were NA-V and EX-1, both waiting on the designer. Designer tasks are listed under Dependencies on External Factors and do not count against agent capacity.

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| SR-1 | Retroactive Sprint 1 code review (Sprint 1 QA condition 2, third sprint) | lead-programmer via /code-review | 1 | none | Every Sprint 1 source file reviewed with the specialist + qa-tester pattern; real findings fixed with regression tests or filed with /bug-report; result recorded in production/qa |
| CI-3 | [Speed modifiers](../epics/controller-interaction/story-003-speed-modifiers.md) | gameplay-programmer | 1 | CI-2 (done) | Story ACs |
| CI-8 | [Hold start and complete](../epics/controller-interaction/story-008-hold-start-complete.md) | gameplay-programmer | 1.5 | CI-7, EC-4, NA-5 (done) | Story ACs |
| NA-9 | [Event projection and sounds](../epics/network-authority/story-009-event-projection-sounds.md) | network-programmer | 1.5 | NA-8, EC-1, EC-2 (done) | Story ACs |
| LB-2 | [Roster lock and hand-off](../epics/lobby-role-assignment/story-002-roster-lock-handoff.md) | gameplay-programmer | 1 | LB-1, LB-3, EC-3, EC-4 (done) | Story ACs |

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| FM-5 | [Visibility table](../epics/facility-map/story-005-visibility-table.md) | level-designer + network-programmer | 1 | FM-1, NA-8 (done) | Story ACs |
| NA-10 | [Hidden entities and spectators](../epics/network-authority/story-010-hidden-entities-spectators.md) | network-programmer | 1 | NA-2, NA-8 (done) | Story ACs |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| CI-4 | [Steps, slopes and stand-up](../epics/controller-interaction/story-004-steps-slopes-stand-up.md) | gameplay-programmer | 1 | CI-1, CI-2 (done) | Story ACs |
| CI-9 | [Hold continue and cancel](../epics/controller-interaction/story-009-hold-continue-cancel.md) | gameplay-programmer | 1 | CI-3, CI-8 (this sprint) | Story ACs |
| LB-7 | [Rotation queue](../epics/lobby-role-assignment/story-007-rotation-queue.md) | gameplay-programmer | 0.5 | LB-2 (this sprint), NA-2 (done) | Story ACs |
| EX-1 | Export preset (TD-004; carryover) | devops-engineer | 0.5 | none | A committed project export preset, or a test that parses one. A headless export builds, and `Knobs.join_version` matches the editor build (DC-5's export check) |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| NA-V Verify NA-1 on a real network | Waived by the designer 2026-10-14 ("skip the real network test"); removed from the sprint (AD-103) | — |
| EX-1 Export preset (Nice to Have) | Waiting on the decision to commit `export_presets.cfg`; auto-decided when the story starts (AD-102) | 0.5 |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Waived NA-V: no real-network run before rule work grows (NA-6 two-PC AC, DC-5 cross-machine digest, NA-3 timing stay unverified off loopback) | Medium | High | Designer accepted the risk 2026-10-14 (AD-103); the NH-1 harness stays ready for a later run |
| SR-1 finds defects in Sprint 1 foundations (tick runner, input queue, auth) that ripple into later code | Medium | Medium | Fix with regression tests; the full suite (now 337 tests) guards the dependents |
| NA-9 projection leaks identity through a payload the NA-8 capture test does not decode | Low | High | Extend the survivor capture test to every event batch |
| R4 (Milestone 1): core fantasy never playtested before Core work grows | High | High | Not solvable by agents; a designer decision, carried below |
| R6 (Milestone 1): auto-decisions unreviewed, now AD-01 to AD-102 | High | Medium | Designer review pass; the list grows by about 15 per sprint |

## Dependencies on External Factors
- **Designer**: the CI-6 mouse-look walk (`production/qa/test-cases/controller-006-mouse-look-cases.md`, about 15 minutes). NA-V (two-PC run) was waived 2026-10-14 (AD-103).
- **Designer**: FM-2 greybox sign-off: every room has two exits and no doorway snags (about 15 minutes; Sprint 3 QA condition 6).
- **Designer**: review AD-01 to AD-102 (Milestone 1 R6); commit the `.claude/skills` invocation edits.
- **Designer**: confirm or replace the CI-7 inferences (pick radius 0.5 m, interaction point at capsule centre height; AD-93) and the LB-3 placeholder colours and voice sets (AD-101).

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-004-[date].md`, from `/qa-plan sprint`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
