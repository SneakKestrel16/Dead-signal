# Story 009: Disguise and true-form rendering

> **Epic**: Borrowed Face
> **Status**: Ready
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]


## Context

A disguise must be a perfect copy of the survivor's body, outfit, colour, animations and footsteps, and the true form a separate model on the same capsule.

**GDD**: `design/gdd/borrowed-face.md`
**Requirement**: `TR-borrowedface-005`, `TR-borrowedface-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Borrowed Face rendering (primary, Proposed); ADR-0004: Replication scope and information hiding
**ADR Decision Summary**: Appearance-child swap on the body; the true-form model is a separate child on the same capsule; the warp effect runs during Transforming.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Per ADR-0010 once Accepted.

**Control Manifest Rules (this layer)**:
- Required: (Proposed) rendering rules per ADR-0010 — re-check the control manifest once it is Accepted

---

## Acceptance Criteria

*From `borrowed-face.md` Acceptance Criteria (copy, label, footsteps, stagger) and Edge Cases, scoped to this story:*

- [ ] A disguised copy of a drive carrier shows no drive; two copies of the same survivor visible at once both render as that survivor (retained screenshots).
- [ ] The copied name label (where labels exist) and footstep set match the target exactly; a copy of a Downed survivor stands healthy.
- [ ] A stunned disguise plays the stagger on the borrowed body with that survivor's shocked grunt; a true-form stun plays the monster stagger and pain cry (retained capture).

---

## Implementation Notes

*Derived from ADR-0010 (Proposed):*

- Slice evidence shots `production/qa/evidence/vertical-slice/` show the greybox swap; the true-form view was very dark (REPORT.md) — check it here.

---

## Out of Scope

- Final character art

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: retained screenshot or capture in `production/qa/evidence/` + sign-off in `production/qa/evidence/disguise-rendering-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007; lobby-role-assignment story 003; ADR-0010 Accepted
- Unlocks: none
