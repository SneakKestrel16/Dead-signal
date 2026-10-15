# Sprint 5 — 2026-12-08 to 2026-12-21

> PR-SPRINT skipped (lean mode). No milestone is open: Milestone 1 (prototype vertical slice) closed 2026-10-13. This sprint is planned against the story backlog and the blockers of the Production → Polish gate check (`production/gate-checks/2026-10-14-production-to-polish.md`, FAIL). There is no risk register, so risks are assessed from the sprint contents.
> QA plan: run `/qa-plan sprint` before implementation begins (AD-122).
> Inputs:
> - The conditions in `production/qa/qa-signoff-sprint-004-2026-10-14.md`; condition 2 schedules BUG-0002 here.
> - The new Feature epics: Match Flow, Survivor Objectives, Downing (AD-119 to AD-121).
> - No Sprint 4 retrospective was written. AD-102 to AD-121 carry its lessons.
> Auto-decided (AD-122, autonomous mode, recommended options): the sprint is built around the server round loop, and the QA plan is run before implementation.

## Sprint Goal
Give the server a round that runs end to end in production code: Match Flow loads players, runs the clock and phases and decides the outcome, and survivors can extract drives, install fuses, and arm and activate the terminal.

## Capacity
- Total days: 10 (one developer, working days)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

Sprint 4 completed every Must, Should and Nice to Have task in one agent session, with all 11 tasks done. Designer tasks are listed under Dependencies on External Factors and do not count against agent capacity.

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| BUG-2 | [BUG-0002](../qa/bugs/BUG-0002.md): unranged int and alpha knobs load any finite value | gameplay-programmer | 0.5 | none | Bug's expected result met: every int knob and alpha float carries a range sourced from its GDD/ADR, or one marked as an inference with what would settle it. Out-of-range values fail validation. Regression test watched failing |
| MF-1 | [Round clock and phase state machine](../epics/match-flow/story-001-round-clock-phases.md) | gameplay-programmer | 1 | none | Story ACs |
| MF-2 | [Win evaluation order and immediate endings](../epics/match-flow/story-002-win-evaluation.md) | gameplay-programmer | 1 | MF-1 | Story ACs |
| MF-4 | [Loading barrier, spawn, round end and return to lobby](../epics/match-flow/story-004-round-lifecycle.md) | network-programmer | 1.5 | MF-1, MF-2 | Story ACs |
| SO-1 | [Drive extract and carry](../epics/survivor-objectives/story-001-drive-extract-and-carry.md) | gameplay-programmer | 1 | none | Story ACs |
| SO-3 | [Fuses, fuse boxes and power restored](../epics/survivor-objectives/story-003-fuses-and-power.md) | gameplay-programmer | 1 | SO-1 | Story ACs |
| SO-5 | [Docking and the evacuation terminal](../epics/survivor-objectives/story-005-docking-and-terminal.md) | gameplay-programmer | 1.5 | SO-1, SO-3 | Story ACs |

Must Have total: 7.5 days.

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| MF-3 | [Escape, evidence extraction and outcome lock](../epics/match-flow/story-003-escape-and-outcome-lock.md) | gameplay-programmer | 1 | MF-2 | Story ACs |
| SO-6 | [Drive extraction at the exit](../epics/survivor-objectives/story-006-extraction.md) | gameplay-programmer | 0.5 | SO-2, SO-5, MF-3 | Story ACs |
| DR-1 | [Life state and takedown commit](../epics/downing-and-rescue/story-001-takedown-commit.md) | gameplay-programmer | 1 | none | Story ACs |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| SO-2 | [Item drops and pickups](../epics/survivor-objectives/story-002-drops-and-pickups.md) | gameplay-programmer | 1 | SO-1 | Story ACs |
| DR-3 | [Bleed-out timer and anti-camping slow](../epics/downing-and-rescue/story-003-bleed-out.md) | gameplay-programmer | 1 | DR-1 | Story ACs |
| MF-9 | [Clients display server phase and outcome only](../epics/match-flow/story-009-client-display-authority.md) | network-programmer | 0.5 | MF-4 | Story ACs |

SO-6 depends on SO-2, which is a Nice to Have. If SO-6 is reached first, SO-2 moves up with it.

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| — | Sprint 4 closed with every task done (`production/qa/qa-signoff-sprint-004-2026-10-14.md`) | — |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| No story yet builds the client round scene or main menu (gate blocker 2). The server loop can be finished while the game is still not playable end to end | High | High | Raise it with the designer: the lobby screen (LB-5) and HUD wait on ADR-0014 (Proposed). A round-scene story needs a UI decision first |
| Proposed ADRs block the path: ADR-0011 (results), ADR-0012 (point selection, discovery), ADR-0014 (UI) | High | High | Designer decision. Until then the round uses the first authored candidate of each type (AD-121) and results carry no stats |
| Downing and Objectives stories need events from systems with no code yet (Monster Abilities, Survivor Defense) | Medium | Medium | Tests emit those events directly (stories say so). The lunge and taser come in a later sprint |
| Real-ENet tests flake under load (BUG-0003, and the one-off `prediction_reconcile_test` failure) | Medium | Low | Do not widen bounds. Raise a test-stability story if a third flake appears (QA sign-off condition 3) |
| BUG-0002's ranges are not all sourced in a GDD or ADR | Medium | Low | Mark each unsourced range as an inference in code and name what would settle it (global rule) |

## Dependencies on External Factors
- Designer: accept or revise ADR-0011, ADR-0012 and ADR-0014 (`/architecture-decision accept`). They unblock results, point selection, discovery and every UI story.
- Designer: CI-6 mouse-look walk and FM-2 greybox sign-off (carried from Sprint 3).
- Designer: review AD-01 to AD-122.
- Designer: set `commands.build` and `performance.*` budgets in `project.yaml` (`/settings`).

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-005-[date].md`, from `/qa-plan sprint`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
