# Story 011: Shock presentation per form and cosmetic flashlight copy

> **Epic**: Survivor Defense
> **Status**: Blocked
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

> **BLOCKED**: ADR-0010 and ADR-0013 are Proposed — accept with `/architecture-decision accept ADR-NNNN` once decided

## Context

What the shock looks and sounds like: the same stagger on a survivor and on a disguised monster, a pain cry and a stagger on the true form, a spark when resisted, the arc flash with a reduced-flash variant, the camera jitter as a visual offset only, and the hiding and barricade sounds. A disguised monster also carries a cosmetic flashlight like the survivor it copies.

**GDD**: `design/gdd/survivor-defense.md`
**Requirement**: `TR-defense-008, TR-defense-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Borrowed Face rendering (Proposed); secondary: ADR-0013 (Proposed)
**ADR Decision Summary**: The shock and stun animation follows the body shown at that moment; a disguise shows only what a survivor would.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Needs ADR-0010 and ADR-0013 accepted; check `TransformView` for the appearance API.

**Control Manifest Rules (this layer)**:
- Required: presentation picks the form from `appearance_of` / `transforming_of`, never from who was hit (ADR-0010)
- Forbidden: never alter view direction or aim from a jolt; never make a disguised hit distinguishable from a survivor hit
- Guardrail: reduced-flash and reduced-motion variants exist for the arc and the jitter

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md` (Detailed Design and Acceptance Criteria), scoped to this story:*

- [ ] A recording of a survivor shocked is indistinguishable from a disguised stunned monster, and a disguised immune hit from a survivor inside their post-lock window (acceptance 10).
- [ ] A true-form stun plays the pain cry and stagger; a resisted true-form hit plays the spark and the dull fizz only (rule 10, Visual table).
- [ ] A disguised monster shows a flashlight cone matching the survivor it copies (rule 6).

---

## Implementation Notes

- Presentation only; subscribe to the events from story 005, never to server-only state.
- Retained screenshots and a lead sign-off go in `production/qa/evidence/`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: which event is sent

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: Visual/Feel: retained screenshots of survivor shocked, disguised monster shocked and true-form stun in `production/qa/evidence/` plus `production/qa/evidence/per-form-presentation-evidence.md` sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 005, 009, 010; ADR-0010 and ADR-0013 accepted
- Unlocks: None
