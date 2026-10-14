# Story 004: Stun immunity during and after transformation

> **Epic**: Borrowed Face
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Survivor Defense gives the shapeshifter a short immunity after a stun. An immune hit must not cancel a transformation, and a fresh disguise never carries immunity observers did not see.

**GDD**: `design/gdd/borrowed-face.md`
**Requirement**: `TR-borrowedface-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order
**ADR Decision Summary**: Defense runs before Borrowed Face in the tick order, so the same tick's stuns and immunity are set when Borrowed Face steps.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: As Story 002.

**Control Manifest Rules (this layer)**:
- Required: read stun and immunity at the current tick

---

## Acceptance Criteria

*From `borrowed-face.md` Acceptance Criteria (immune hits; cross-review B1, B4), scoped to this story:*

- [ ] An immune taser hit during a transformation (out of a disguise or out of true form) applies no root, slow or lock, and the transformation completes 2 s after acceptance.
- [ ] A stun item hit on an immune disguised shapeshifter does not interrupt a transformation or change the form, and a transformation request during the following `stun_duration_s` is not rejected on that account.
- [ ] A shapeshifter stunned in true form that completes a transformation into a disguise during `stun_immunity_s` is no longer immune: the next hit stuns it and applies the rule 14 lock.

---

## Implementation Notes

*Derived from `borrowed-face.md` Edge Cases and `survivor-defense.md` rules 10, 14, 16:*

- Taser and immunity live in Survivor Defense; drive them from a stub in these tests and re-run when that epic lands.

---

## Out of Scope

- Shock presentation (Story 008, Story 009)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/borrowed-face/transform_immunity_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003
- Unlocks: Survivor Defense epic
