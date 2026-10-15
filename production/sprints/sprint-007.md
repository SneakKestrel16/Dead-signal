# Sprint 7 — 2027-01-05 to 2027-01-18

> PR-SPRINT skipped (lean mode). This sprint is planned against the story backlog. No milestone after Milestone 1 is defined, and there is no risk register, so risks come from the sprint contents.
> QA plan: run `/qa-plan sprint` before implementation begins.
> Inputs:
> - Sprint 6 QA sign-off: `production/qa/qa-signoff-sprint-006-2026-10-15.md`, APPROVED WITH CONDITIONS. This sprint addresses conditions 3 (composer and playtests) and 4 (reconnect catch-up).
> - ADR-0009 to ADR-0015 accepted 2026-10-15 (AD-196), which unblocked 21 stories.
> - User design calls AD-197 to AD-201 (composer, hiding marker facing).
>
> Auto-decided (autonomous mode, recommended options):
> - The sprint takes every Ready story.
> - The composer and the client round scene lead the sprint.
> - Visual/Feel and UI stories go in Nice to Have and Should Have, after the client scene, because they need a running client to capture evidence and the lead's sign-off.

## Sprint Goal
Make a real round run and be seen:
- a composition root that wires every module into one server round;
- a client round scene that joins that round and renders it;
- the server-side work the newly accepted ADRs unblocked: results, discovery, lighting, flinch, False Signal and Blackout.

## Capacity
- Total days: 10 (one developer, working days)
- Buffer (20%): 2 days
- Available: 8 days

Observed throughput with parallel worktree agents is far above the estimates: sprint 6 closed 16 stories in one session. The Must Have list (12.5 days on paper) matches that pace. Designer tasks do not count against agent capacity.

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| MF-10 | [Round composer](../epics/match-flow/story-010-round-composer.md) | gameplay-programmer | 2 | all Feature modules (Complete) | Story ACs |
| MF-11 | [Client round scene](../epics/match-flow/story-011-client-round-scene.md) | network-programmer | 2 | MF-10 | Story ACs |
| MF-12 | [Display catch-up on rejoin](../epics/match-flow/story-012-display-catch-up-on-rejoin.md) | network-programmer | 0.5 | none | Story ACs |
| SD-13 | [Hiding marker facing](../epics/survivor-defense/story-013-hiding-marker-facing.md) | gameplay-programmer | 0.5 | none | Story ACs |
| MF-8 | [Results payload](../epics/match-flow/story-008-results-payload.md) | gameplay-programmer | 1 | none | Story ACs |
| MA-8 | [Ability stats for results](../epics/monster-abilities/story-008-ability-stats.md) | gameplay-programmer | 0.5 | MF-8 | Story ACs |
| FM-7 | [Candidate point selection](../epics/facility-map/story-007-candidate-selection.md) | gameplay-programmer | 1 | none | Story ACs |
| FM-8 | [Candidate replication and discovery agreement](../epics/facility-map/story-008-candidate-replication.md) | network-programmer | 1 | FM-7 | Story ACs |
| SO-8 | [Active point selection](../epics/survivor-objectives/story-008-active-point-selection.md) | gameplay-programmer | 1 | FM-7 | Story ACs |
| SO-9 | [Objective discovery](../epics/survivor-objectives/story-009-discovery.md) | gameplay-programmer | 1 | SO-8 | Story ACs |
| FM-9 | [Lighting state machine](../epics/facility-map/story-009-lighting-state-machine.md) | gameplay-programmer | 1 | none | Story ACs |
| CI-13 | [Flinch view offset and camera effects](../epics/controller-interaction/story-013-view-offset-camera-effects.md) | gameplay-programmer | 1 | none | Story ACs |

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| MA-9 | [False Signal](../epics/monster-abilities/story-009-false-signal.md) | gameplay-programmer | 2 | none | Story ACs |
| MA-10 | [Blackout](../epics/monster-abilities/story-010-blackout.md) | gameplay-programmer | 2 | FM-9 | Story ACs |
| SD-10 | [Hiding noise and long-hide cue](../epics/survivor-defense/story-010-hide-noise-and-long-hide-cue.md) | gameplay-programmer | 0.5 | none | Story ACs |
| CI-14 | [Footstep events](../epics/controller-interaction/story-014-footsteps.md) | network-programmer | 1 | none | Story ACs |
| BF-9 | [Disguise and true-form rendering](../epics/borrowed-face/story-009-disguise-rendering.md) | technical-artist | 1.5 | MF-11 | Story ACs + lead sign-off |
| LB-5 | [Lobby screen](../epics/lobby-role-assignment/story-005-lobby-screen.md) | ui-programmer | 1.5 | none | Story ACs + screenshots |

### Nice to Have
Each of these needs MF-11's running client for its evidence.

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| LB-6 | [No name tags or role indicators](../epics/lobby-role-assignment/story-006-no-role-indicators.md) | network-programmer | 0.5 | MF-11 | Story ACs + screenshot |
| FM-10 | [Lighting render, Blackout scope, reduced flash](../epics/facility-map/story-010-lighting-render-blackout.md) | technical-artist | 1.5 | FM-9, MF-11 | Story ACs + sign-off |
| FM-11 | [Surveillance cameras](../epics/facility-map/story-011-surveillance-cameras.md) | technical-artist | 1.5 | FM-9, BF-9 | Story ACs + sign-off |
| FM-12 | [Zone ambience and footstep masking](../epics/facility-map/story-012-zone-ambience.md) | sound-designer | 1 | CI-14 | Story ACs + sign-off |
| BF-10 | [Transformation warp and distortion audio](../epics/borrowed-face/story-010-transform-warp-audio.md) | technical-artist | 1 | BF-9 | Story ACs + sign-off |
| MA-7 | [Lunge cue, coil pose, hit feedback](../epics/monster-abilities/story-007-lunge-presentation.md) | technical-artist | 1.5 | MF-11 | Story ACs + sign-off |
| SD-11 | [Shock presentation per form](../epics/survivor-defense/story-011-per-form-presentation.md) | technical-artist | 1.5 | SD-10, BF-9 | Story ACs + sign-off |
| LB-12 | [Queue order display (post-M1)](../epics/lobby-role-assignment/story-012-queue-order-display.md) | ui-programmer | 1 | LB-5 | Story ACs + screenshots |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| — | Sprint 6 closed with every task done (`production/qa/qa-signoff-sprint-006-2026-10-15.md`) | — |

CI-16 (sprint 5) stays In Review: its 240 fps capture is an acceptance criterion of MF-11.

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| The composer touches every module's setup, so it conflicts with every parallel story. | High | Medium | Merge MF-10 first and alone. Start dependent stories from the post-merge main. |
| The client scene is the first rendering of the game at all; D3D12 and Jolt behaviour on a real client is unproven. | Medium | High | MF-11 takes retained screenshots and a 240 fps capture; failures are filed as bugs, not worked around. |
| Visual/Feel and UI stories need your sign-off and cannot close without it. | High | Medium | They are Nice to Have or Should Have; the sprint goal does not depend on them. |
| Real-ENet flakes under parallel agent load (BUG-0003). | Medium | Low | Re-run alone before calling a regression. Never widen bounds. |

## Dependencies on External Factors
- **Lead sign-off:** each Visual/Feel story.
- **Playtests:** the two playtests owed from sprint 6 (monster-view lunge feel; 5-client survivor defense), once MF-11 lands.
- **Two-PC session:** NA-V.
- **Settings:** `commands.build` and an export preset (EX-1).
- **Decide:** the BUG-0004 approach.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-007-[date].md`, from `/qa-plan sprint`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
