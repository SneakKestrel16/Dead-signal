# Sprint 001 — 2026-10-13 to 2026-10-26

> PR-SPRINT skipped — Lean mode. No milestone defined: planning against the story backlog alone. No risk register: risks assessed from the sprint contents only.
> QA plan: run `/qa-plan sprint` before implementation begins (recommended option auto-accepted, AD-37).

## Sprint Goal
Unblock the Foundation layer and land its pure-logic core: run the two-PC network test, accept the governing ADRs, then build the knob loader, event bus, state registry, tick runner and input queue.

## Capacity
- Total days: 10 (one developer, working days)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

Estimates are first guesses for a solo developer working with agents; story files still read `[fill before sprint planning]` and should take these values when started.

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| U1 | Two-PC real-network test (list in `prototypes/networking-spike/README.md`) | SneakKestrel16 + network-programmer | 1 | A second PC | Results recorded in `prototypes/networking-spike/README.md`; ADR-0001/0002/0003 verification rows updated. **Done 2026-10-13**: WAN movement run; drift and Wi-Fi tests skipped (designer decision, Tailscale) |
| U2 | Accept ADR-0001..0006 (`/architecture-decision accept`), regenerate the control manifest | SneakKestrel16 + technical-director | 0.5 | U1 | Status lines read Accepted; manifest version re-stamped; story Status lines flip to Ready. **Done 2026-10-13**: ADR-0001..0008 Accepted, 21 stories Ready |
| DC-1 | [Knob sections, range and unset validation](../epics/data-config/story-001-knob-section-validation.md) | gameplay-programmer | 1 | U2 (ADR-0006) | Story ACs |
| EC-1 | [ServerEvent base and the 15-event catalog](../epics/event-catalog-state-registry/story-001-server-event-catalog.md) | godot-gdscript-specialist | 0.5 | U2 (ADR-0005) | Story ACs |
| EC-2 | [EventBus emit, subscribe and flush](../epics/event-catalog-state-registry/story-002-event-bus.md) | godot-gdscript-specialist | 1 | EC-1, DC-1 | Story ACs |
| EC-3 | [StateRegistry and typed views](../epics/event-catalog-state-registry/story-003-state-registry.md) | godot-gdscript-specialist | 0.5 | U2 (ADR-0005) | Story ACs |
| NA-4 | [TickRunner and the server clock](../epics/network-authority/story-004-tick-runner.md) | network-programmer | 1 | DC-1, U2 (ADR-0002) | Story ACs |
| NA-5 | [Input frames and the server input queue](../epics/network-authority/story-005-input-frames-queue.md) | network-programmer | 1.5 | NA-4 | Story ACs |

Must Have total: 7 days.

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| DC-2 | [All knob sections and the shipped files](../epics/data-config/story-002-sections-and-shipped-files.md) | gameplay-programmer | 1 | DC-1 | Story ACs |
| EC-4 | [Composition root and feature tick order](../epics/event-catalog-state-registry/story-004-composition-root-tick-order.md) | lead-programmer | 1 | EC-2, EC-3, NA-4 | Story ACs |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| NA-1 | [Host, join and join validation](../epics/network-authority/story-001-host-join-auth.md) | network-programmer | 1.5 | DC-1, U2 (ADR-0001) | Story ACs |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| — | First sprint | — |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| No second PC available for U1 | Medium | High: every story stays Blocked | Borrow a machine or a friend's PC; a cloud VM can stand in for WAN/NAT rows only |
| Two-PC test changes ADR-0001/0002 | Medium | Medium: stories need edits | Stories cite ADR sections; re-run `/create-control-manifest update` and patch the affected story notes |
| Estimates are guesses (no velocity yet) | High | Low | Sprint 001 sets the velocity baseline; Nice to Have absorbs the error |

## Dependencies on External Factors
- A second PC on a different network for U1 (two home connections preferred).
- Designer decisions AD-01..AD-37 are Pending review in `production/auto-decisions.md`; none block this sprint's stories.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-[sprint-slug]-[date].md`, from `/qa-plan sprint`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
