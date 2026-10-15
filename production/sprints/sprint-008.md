# Sprint 8 — 2027-01-19 to 2027-02-01

> PR-SPRINT skipped (lean mode). This sprint is planned against the story backlog. No milestone after Milestone 1 is defined, and there is no risk register, so risks come from the sprint contents.
> QA plan: `production/qa/qa-plan-sprint-008-2026-10-15.md`.
> Inputs:
> - Sprint 7 QA sign-off: `production/qa/qa-signoff-sprint-007-2026-10-15.md`, NOT ASSESSED (10 Visual/UI stories await the designer's walk and sign-off).
> - New epics: Pings & Callouts and Scare Events (AD-223), 18 stories (AD-224).
>
> Auto-decided (autonomous mode, recommended options):
> - The sprint takes every Ready story; Pings & Callouts 009 (proximity voice) stays out, Blocked on a voice-transport ADR.
> - Server stories are Must Have; the three client presentation stories (pings 008, scare 008 and 009) are Should Have, because they need the designer's sign-off to close.

## Sprint Goal
Build the last two Vertical Slice Feature systems, Pings & Callouts and Scare Events: server half first, then their client presentation.

## Capacity
- Total days: 10 (one developer, working days)
- Buffer (20%): 2 days
- Available: 8 days

Parallel worktree agents close stories far faster than the estimates (sprint 7: 27 stories in one session). Designer tasks do not count against agent capacity.

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| PC-1 | Ping module, request validation and token bucket | network-programmer | 1 | None | Story ACs; `tests/unit/pings-and-callouts/` |
| PC-2 | Sender-state gating | gameplay-programmer | 0.5 | PC-1 | Story ACs |
| PC-3 | Callout limits and attached item ping | gameplay-programmer | 0.5 | PC-1, PC-2 | Story ACs |
| PC-4 | Ping recipients and per-peer delivery | network-programmer | 1 | PC-1, PC-2 | Real-ENet 5-client test |
| PC-5 | Marker lifecycle | gameplay-programmer | 0.5 | PC-4 | Story ACs |
| PC-6 | Callout recipients and monster audio-only | network-programmer | 1 | PC-2, PC-3 | Real-ENet test |
| PC-7 | Displayed identity, (not you), fake parity | network-programmer | 1 | PC-4, PC-6 | Packet parity test |
| SE-1 | Scare catalogue and server Scare module | gameplay-programmer | 1 | None | Story ACs |
| SE-2 | Per-recipient gating, budgets, repeat block | gameplay-programmer | 1 | SE-1 | Story ACs |
| SE-3 | Scoped delivery and hallucinations | network-programmer | 1 | SE-1, SE-2 | Real-ENet 5-client test |
| SE-4 | Monster-source scares | gameplay-programmer | 1 | SE-1, SE-2 | Story ACs |
| SE-5 | Ambush lunge scare and flinch suppression | gameplay-programmer | 1 | SE-1, SE-2 | Story ACs |
| SE-6 | Facility scare state and RoundScript anchors | gameplay-programmer | 1.5 | SE-1, SE-2 | Story ACs |
| SE-7 | Presentation-only guarantees | gameplay-programmer | 0.5 | SE-6 | Story ACs |

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| PC-8 | Ping input, markers, callout wheel and feed (UI) | ui-programmer | 1.5 | PC-5, PC-6, PC-7 | Screenshots + designer sign-off |
| SE-8 | Scare audio (Visual/Feel) | gameplay-programmer | 1.5 | SE-1, SE-3 | Evidence page + sign-off |
| SE-9 | Scare visuals and flash accessibility (Visual/Feel) | technical-artist | 1 | SE-3, SE-6 | Evidence page + sign-off |

### Nice to Have
None.

## Carryover from Previous Sprint
All 12 are implemented and merged; each waits on the designer only.

| Task | Reason | New Estimate |
|------|--------|-------------|
| MF-11 Client round scene | Manual case walk; AD-217 | 0 (designer) |
| BF-9 Disguise rendering | Sign-off | 0 (designer) |
| LB-5 Lobby screen | Sign-off | 0 (designer) |
| LB-6 No role indicators | Sign-off | 0 (designer) |
| FM-10 Lighting render | Sign-off | 0 (designer) |
| FM-11 Surveillance cameras | Sign-off | 0 (designer) |
| FM-12 Zone ambience | Sign-off | 0 (designer) |
| BF-10 Transform warp and audio | Sign-off, listening test | 0 (designer) |
| MA-7 Lunge presentation | Sign-off, playtests | 0 (designer) |
| SD-11 Per-form presentation | Sign-off | 0 (designer) |
| LB-12 Queue order display | Sign-off; AD-216 | 0 (designer) |
| SD-14 Barricade input | AD-219 | 0 (designer) |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Parallel agents conflict in `round_composer.gd` and `round_client.gd` | High | Low | Standalone modules with one-line hooks; merge one at a time, full suite after each |
| Agent capture servers collide with the test port range | Medium | Medium | Ports 30000-30999 only; check for stray processes before full runs |
| No AudioDirector: SE-8 and PC-8 sign off on placeholder audio | High | Low | Re-verify when final audio lands (sprint-7 condition 6) |
| Untraced TRs (AD-223) leave gating design to the story | Medium | Medium | Stories embed the GDD formulas; deviations recorded as AD rows |

## Dependencies on External Factors
- Designer: sprint-7 sign-offs and AD-216, AD-217, AD-219.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-008-[date].md`, from `/qa-plan sprint`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
