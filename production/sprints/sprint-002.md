# Sprint 002 — 2026-10-27 to 2026-11-09

> PR-SPRINT skipped — Lean mode. No milestone defined: planning against the story backlog alone. No risk register: risks assessed from the sprint contents only.
> QA plan: `production/qa/qa-plan-sprint-002-2026-10-13.md`.

## Sprint Goal
Finish the Foundation layer's network spine (tokens and reconnect, snapshots with owner prediction) and start the Core layer on the body, view and input it needs: player capsule and collision, mouse look and input actions.

## Capacity
- Total days: 10 (one developer, working days)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

Estimates are first guesses. Sprint 1 landed 9 stories (about 8 estimated days) in its first working session, so these hold the same scale. Story files still read `[fill before sprint planning]` and should take these values when started.

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| NA-2 | [Session tokens and reconnect rebinding](../epics/network-authority/story-002-tokens-reconnect.md) | network-programmer | 1 | NA-1 (done) | Story ACs |
| NA-6 | [Snapshots, owner prediction and reconciliation](../epics/network-authority/story-006-snapshots-prediction.md) | network-programmer | 2 | NA-4, NA-5 (done) | Story ACs |
| DC-3 | [Cross-knob rules](../epics/data-config/story-003-cross-knob-rules.md) | gameplay-programmer | 0.5 | DC-1, DC-2 (done) | Story ACs |
| CI-1 | [Player body, capsules and collision layers](../epics/controller-interaction/story-001-body-capsule-collision.md) | gameplay-programmer | 1.5 | NA-4, DC-2 (done) | Story ACs |
| CI-6 | [View direction, mouse look and input actions](../epics/controller-interaction/story-006-view-direction-input-actions.md) | gameplay-programmer | 1 | NA-5 (done) | Story ACs |

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| DC-5 | [Knob digest in the join version check](../epics/data-config/story-005-digest-version-check.md) | gameplay-programmer | 1 | DC-1, DC-2, NA-1 (done) | Story ACs |
| EC-6 | [Layer boundary check](../epics/event-catalog-state-registry/story-006-layer-boundary-check.md) | gameplay-programmer | 0.5 | EC-4 (done) | Story ACs |
| NA-V | Verify NA-1 on a real network (QA condition 1): two machines over Tailscale, reject delay under real latency, exported headless server | SneakKestrel16 + network-programmer | 0.5 | A second PC | Results recorded in `prototypes/networking-spike/README.md`; ADR-0001 verification rows updated. NAT and IPv6 rows skipped if Tailscale only (designer decision 2026-10-13) |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| LB-1 | [Ready and countdown state machine](../epics/lobby-role-assignment/story-001-ready-countdown-state-machine.md) | gameplay-programmer | 1 | DC-2, NA-4 (done) | Story ACs |
| FM-1 | [Facility map data and whole-level load](../epics/facility-map/story-001-map-data-loader.md) | level-designer + gameplay-programmer | 1 | DC-2 (done) | Story ACs |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| none | All 9 Sprint 1 stories are Complete | |

## QA conditions carried from the Sprint 1 sign-off (`production/qa/qa-signoff-sprint-001-2026-10-13.md`)
1. NA-1 real-network verification: task NA-V above.
2. Code review was skipped in lean mode for Sprint 1: run `/code-review` on each Sprint 2 story as it closes, and decide on a retroactive review of Sprint 1 (designer decision pending).
3. Menu, session, save and performance become required smoke items when a sprint adds each. No Sprint 2 story adds one (LB-1 has no screen), so they stay N/A.
4. File defects with `/bug-report` under `production/qa/bugs/`.

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| NA-6 (snapshots, prediction) is the largest story and touches the tick order | Medium | High: the predicted hold bar later waits on it | Keep it first in the order; CI-1 and CI-6 do not depend on it |
| CI-1 collision layers are a physics guess until a body moves on the map | Medium | Medium | Integration test on the layers now; the map arrives with FM-2 |
| No second PC for NA-V | Medium | Low: it is a Should Have and a condition, not a blocker | Reuse the Sprint 1 Tailscale setup |
| Proposed ADR-0009/0010/0012/0013/0014/0015 still block 14 Core stories | High | Medium | None of this sprint's stories depend on them; accept them before Sprint 3 |

## Dependencies on External Factors
- A second PC on the Tailscale network for NA-V.
- Designer review of AD-01..AD-68 in `production/auto-decisions.md` (pending); none block this sprint's stories.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-002-[date].md`, from `/qa-plan sprint`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
