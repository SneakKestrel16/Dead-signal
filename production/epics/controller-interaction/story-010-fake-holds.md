# Story 010: Shapeshifter fake holds

> **Epic**: First-Person Controller & Interaction
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

A disguised shapeshifter can pretend to work an objective. To observers it looks identical; on the server it does nothing and never blocks a real survivor.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Hold-to-interact protocol
**ADR Decision Summary**: §6: a shapeshifter Start on a `fakeable` interactable is a fake — same animation and quiet loop, no lock, no progress, no owner calls, never completes; a real survivor Start cancels the fake; on a non-fakeable target `eligible` rejects it. §8: observers see the same `holding` pose bit for real and fake holds.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: As Story 008.

**Control Manifest Rules (this layer)**:
- Required: only `HoldService` times holds
- Required: resolve body targets through the requesting peer's handle table

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (fake hold) and rule 17, scoped to this story:*

- [ ] A shapeshifter faking an allowed hold on a free exclusive target for longer than `duration_s` has progress 0, never takes the lock, and causes no owner callback.
- [ ] A survivor can Start on the same target while the fake runs, and that Start cancels the fake.
- [ ] Remote clients receive the same `holding` pose bit for the fake as for a real hold; a non-fakeable target rejects the shapeshifter's Start.

---

## Implementation Notes

*Derived from ADR-0008 Decision §6, §8:*

- The audio loop and animation are presentation; this story asserts the replicated pose bit only.

---

## Out of Scope

- Fake-hold audio and animation (presentation epics)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/first-person-controller/hold_service_fake_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 008
- Unlocks: Survivor Objectives epic
