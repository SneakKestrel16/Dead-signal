# Sprint 003 — 2026-11-10 to 2026-11-23

> PR-SPRINT skipped (lean mode). No milestone is open: Milestone 1 (vertical slice) closed 2026-10-13, so this sprint is planned against the story backlog alone. There is no risk register; risks are assessed from the sprint contents and the Milestone 1 register.
> QA plan: run `/qa-plan sprint` before implementation begins.
> Inputs: `production/retrospectives/retro-sprint-002-2026-10-14.md` (4 action items) and the conditions in `production/qa/qa-signoff-sprint-002-2026-10-14.md`.

## Sprint Goal
Make real-network verification runnable at last, and move Core from a standing body to a moving one in a built level. Concretely: the host/join harness, host-left handling, movement gaits, the greybox facility, and the knob refusal at host start.

## Capacity
- Total days: 10 (one developer, working days)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

Sprint 2 completed 10.0 estimated days in one agent session; its only miss was NA-V, which needs hardware and a harness. The estimates here use the same relative scale. Tasks for a human (the designer at a second PC or at the keyboard) are listed under Dependencies on External Factors. They do not count against agent capacity.

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| NH-1 | Host/join harness `tests/manual/net_check.tscn`, run from the command line (retro action 1) | network-programmer | 1 | NA-1, NA-2 (done) | The flags and keys in `production/qa/test-cases/na-v-real-network-cases.md` (`--role`, `--host`, `--name`, `--build`, `L`, `R`) work. Two local instances host and join. The token is never printed. NAV cases move from BLOCKED-UNTIL-HARNESS to runnable |
| NA-3 | [Disconnect handling and host left](../epics/network-authority/story-003-disconnect-host-left.md) | network-programmer | 1 | NA-2 (done) | Story ACs |
| CI-2 | [Movement step and gaits](../epics/controller-interaction/story-002-movement-step-gaits.md) | gameplay-programmer | 1.5 | CI-1 (done) | Story ACs |
| FM-2 | [Greybox geometry and collision](../epics/facility-map/story-002-greybox-geometry-collision.md) | level-designer + gameplay-programmer | 1.5 | FM-1, CI-1 (done) | Story ACs. Also closes FM-1 AC2's geometry-node-count half |
| DC-4 | [Refuse to host and freeze](../epics/data-config/story-004-refuse-to-host-and-freeze.md) | gameplay-programmer | 1 | DC-1, DC-3, NA-1 (done) | Story ACs |

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| CI-7 | [Interaction targeting](../epics/controller-interaction/story-007-interaction-targeting.md) | gameplay-programmer | 1 | CI-1, CI-6 (done) | Story ACs |
| NA-8 | [Handles and relevance](../epics/network-authority/story-008-handles-relevance.md) | network-programmer | 1.5 | NA-6 (done) | Story ACs |
| CI-5 | [Controller load checks](../epics/controller-interaction/story-005-controller-load-checks.md) | gameplay-programmer | 0.5 | DC-2, DC-3 (done) | Story ACs |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| FM-3 | [Connectivity checks](../epics/facility-map/story-003-connectivity-checks.md) | gameplay-programmer | 0.5 | FM-1 (done) | Story ACs |
| LB-3 | [Character data and M1 assignment](../epics/lobby-role-assignment/story-003-character-data-m1-assignment.md) | gameplay-programmer | 1 | DC-2 (done) | Story ACs |
| EX-1 | Export preset (TD-004, retro action 4) | devops-engineer | 0.5 | none | A committed project export preset, or a test that parses one. A headless export builds, and `Knobs.join_version` matches the editor build (DC-5's export check). Un-ignoring `export_presets.cfg` is the designer's call |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| NA-V Verify NA-1 on a real network (Should Have) | Never started: it needs a second PC, and no scene let a person host or join. Second sprint carried (first owed as Sprint 1 QA condition 1) | 0.5 (designer session after NH-1). The cases are in `production/qa/test-cases/na-v-real-network-cases.md` |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| NA-V slips a third sprint | Medium | High: a networked game with zero real-network runs | NH-1 is Must Have; the session is an external dependency with a named owner |
| FM-2 greybox shows that the sketch-derived coordinates in FM-1 are wrong | Medium | Low | FM-1's data is marked inference; FM-2 edits the `.tres` directly (generator note) |
| R4 (Milestone 1): core fantasy never playtested before Core work grows | High | High | Not solvable by agents; a designer decision, carried below |
| R6 (Milestone 1): auto-decisions unreviewed, now AD-01 to AD-81 | High | Medium | Designer review pass; the list grows by about 10 per sprint |
| CI-2 movement replay drifts from NA-6 reconciliation | Low | Medium | CI-2 reuses the shared movement step; the NA-6 prediction test stays green |

## Dependencies on External Factors
- **Designer, second PC**: the NA-V session after NH-1 lands (1–2 h).
- **Designer**: walk `production/qa/test-cases/controller-006-mouse-look-cases.md`, about 15 minutes (retro action 3).
- **Designer**: schedule or waive the Sprint 1 retroactive code review (retro action 2; Sprint 1 QA condition 2, in its second sprint).
- **Designer**: review AD-01 to AD-81 (Milestone 1 R6); commit the `.claude/skills` invocation edits.
- **Designer**: decide whether `export_presets.cfg` may be committed (EX-1).

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-003-[date].md`, from `/qa-plan sprint`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
