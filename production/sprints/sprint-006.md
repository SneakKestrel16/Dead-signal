# Sprint 6 — 2026-12-22 to 2027-01-04

> PR-SPRINT skipped (lean mode). This sprint is planned against the story backlog: Milestone 1 (`production/milestones/milestone-01-vertical-slice.md`) closed 2026-10-13 and no later milestone is defined. There is no risk register, so risks are assessed from the sprint contents.
> QA plan: run `/qa-plan sprint` before implementation begins (AD-177).
> Inputs:
> - Sprint 5 QA sign-off: `production/qa/qa-signoff-sprint-005-2026-10-15.md`, APPROVED WITH CONDITIONS. Its condition 1 is resolved; the rest are S3/S4 bugs that may be deferred.
> - The new Feature epics, Survivor Defense and Monster Abilities (AD-172 to AD-176).
> Auto-decided (AD-177, autonomous mode, recommended options):
> - The sprint takes every Ready story in the two new epics.
> - The QA plan runs before implementation.

## Sprint Goal
Give the server its two missing combat systems, so every merged stand-in can be retired:
- **Predatory Lunge:** the server validates, hit-tests and resolves it into Downing's takedown.
- **Survivor Defense:** the taser stuns, shocks and grants immunity, hidden by form; hiding spots, barricades and the flashlight work.

## Capacity
- Total days: 10 (one developer, working days)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

Velocity is far above this estimate. Sprint 5 and the parallel story waves closed about 55 stories in two sessions using worktree agents. The 16 stories below exceed 8 days on paper but match observed throughput. Designer tasks are listed under Dependencies on External Factors and do not count against agent capacity.

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| MA-1 | [Ability requests and Lunge state machine](../epics/monster-abilities/story-001-request-validation-and-lunge-states.md) | gameplay-programmer | 1 | none | Story ACs |
| MA-2 | [Lunge wind-up root and dash](../epics/monster-abilities/story-002-wind-up-and-dash.md) | gameplay-programmer | 1 | MA-1 | Story ACs |
| MA-3 | [Lunge hit test with lag compensation](../epics/monster-abilities/story-003-hit-test-and-survivor-hit.md) | network-programmer | 1 | MA-2 | Story ACs |
| MA-4 | [Lunge resolution, cooldown and miss slow](../epics/monster-abilities/story-004-resolution-cooldown-miss-slow.md) | gameplay-programmer | 0.5 | MA-2, MA-3 | Story ACs |
| SD-1 | [Defense module, charges and intent validation](../epics/survivor-defense/story-001-defense-module-charges-intents.md) | gameplay-programmer | 1 | none | Story ACs |
| SD-2 | [Taser trace along the view ray with rewind](../epics/survivor-defense/story-002-taser-trace.md) | network-programmer | 1 | SD-1 | Story ACs |
| SD-3 | [One shock lock, no refresh, post-lock window](../epics/survivor-defense/story-003-shock-lock-post-lock-window.md) | gameplay-programmer | 0.5 | SD-1, SD-2 | Story ACs |
| SD-4 | [Monster stun, immunity and cancels](../epics/survivor-defense/story-004-monster-stun-immunity-cancels.md) | gameplay-programmer | 1 | SD-2, SD-3 | Story ACs |
| SD-5 | [Identity-hiding stun and shock events](../epics/survivor-defense/story-005-identity-hiding-events.md) | network-programmer | 1 | SD-3, SD-4 | Story ACs |

Must Have total: 8 days.

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| MA-5 | [AbilityUsed emission and Lunge state publishing](../epics/monster-abilities/story-005-ability-used-and-state.md) | gameplay-programmer | 0.5 | MA-1 | Story ACs |
| MA-6 | [Integrate with Downing and Borrowed Face](../epics/monster-abilities/story-006-integrate-downing-borrowed-face.md) | gameplay-programmer | 1 | MA-3, MA-4, MA-5 | Story ACs |
| SD-6 | [Hiding spots: enter, exit, occupancy, search](../epics/survivor-defense/story-006-hiding-spots.md) | gameplay-programmer | 1 | SD-1, SD-4 | Story ACs |
| SD-7 | [Barricade build and remove, closed doors block the dash](../epics/survivor-defense/story-007-barricade-build-remove-door-block.md) | gameplay-programmer | 1 | SD-1 | Story ACs |
| SD-8 | [Barricade break, persistence and rebarricade lockout](../epics/survivor-defense/story-008-barricade-break-lockout.md) | gameplay-programmer | 0.5 | SD-4, SD-7 | Story ACs |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| SD-9 | [Flashlight toggle and replicated cone](../epics/survivor-defense/story-009-flashlight-toggle.md) | network-programmer | 0.5 | SD-1 | Story ACs |
| SD-12 | [Five-client agreement and retiring the stand-ins](../epics/survivor-defense/story-012-five-client-agreement-retire-stand-ins.md) | network-programmer | 1 | SD-4, SD-5, SD-6, SD-8 | Story ACs |

Not planned:
- **LB-6** is Ready but needs a running-round client screenshot, and no client round scene exists yet.
- **MA-7 to MA-10 and SD-10 to SD-11** are Blocked on Proposed ADRs.

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| — | Sprint 5 closed with every task done (`production/qa/qa-signoff-sprint-005-2026-10-15.md`) | — |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| The two epics cross-depend: the lunge needs stun cancels and closed-door blocking from Defense, and Defense needs the lunge wind-up for immunity end. | High | Medium | Each story's tests emit the other system's events directly (as the stories say). MA-6 and SD-12 re-run against both real modules at the end. |
| Many parallel stories edit shared files (`downing.gd`, `borrowed_face.gd`, `hold_service.gd`, `server_movement.gd`), so squash merges conflict. | High | Low | Merge one at a time and run the full suite after each. Sprint 5 resolved every such conflict by keeping both additive sides. |
| No round composer exists, so new hooks are wired only in tests. | High | High | Out of this sprint's stories. Raise a composer story with the designer (Sprint 5 smoke advisory). |
| Real-ENet and timing tests flake under parallel agent load (BUG-0003, BUG-0004). | Medium | Low | Re-run flaky files alone before treating a failure as a regression. Never widen bounds. |
| Lag-compensated taser and lunge hit tests clamp to the rewind cap until a client fills `view_tick` (NA-7). | Medium | Medium | Tests set `view_tick`. Client filling is a later story. |

## Dependencies on External Factors
- **ADRs to accept** (`/architecture-decision accept`): ADR-0009, ADR-0010, ADR-0011, ADR-0012, ADR-0013, ADR-0014, ADR-0015. They unblock 21 stories, including the lunge cue and stats, False Signal, Blackout, hiding noise and shock presentation.
- **Lead sign-off:** CI-16 sign-off and its 240 fps capture.
- **Review:** AD-87 to AD-177.
- **Decide:** the BUG-0004 tick-budget approach.
- **Settings:** set `commands.build` in `project.yaml` (`/settings`).

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-006-[date].md`, from `/qa-plan sprint`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
