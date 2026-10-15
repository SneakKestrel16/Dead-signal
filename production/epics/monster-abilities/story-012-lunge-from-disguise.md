# Story 012: Lunge from disguise with a wind-up reveal

> **Epic**: Monster Abilities
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Playtest finding (2026-10-15): a disguised lunge did nothing and gave no feedback. Designer decision 2026-10-15 (playtest): "allow lunge when disguised but add a reveal in the windup".

**GDD**: `design/gdd/monster-abilities.md` rule 4, Disguise interaction, Edge Cases "Lunge while Disguised"; `design/gdd/borrowed-face.md` rule 11, Edge Cases "Lunge requested while Disguised"
**Requirement**: `TR-monster-001`, `TR-monster-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order; secondary: ADR-0004
**ADR Decision Summary**: Borrowed Face reacts to the accepted Lunge's `AbilityUsed` in the MONSTER_ABILITIES flush, so the true-form appearance replicates in the same tick's snapshot; `AbilityUsed` itself stays server-internal.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API.

---

## Acceptance Criteria

*From GDD `design/gdd/monster-abilities.md`, scoped to this story:*

- [ ] A lunge requested while Disguised is accepted, and the shapeshifter is in true form from the wind-up's first tick (instant reveal, no 2 s transformation; **proposed**), with `FormChanged` into true form.
- [ ] Survivor clients receive the reveal (the body's true-form appearance) before the hit can land: the dash starts `lunge_windup_s` later.
- [ ] The shock lock (Survivor Defense rule 14) and Transforming still reject the lunge; a transformation still cannot start during wind-up, active or takedown commit.
- [ ] The shipped client sends the lunge while disguised (ShapeshifterAim has no form gate; the server decides).

---

## Implementation Notes

- Inference (proposed): the reveal starts no form-change cooldown and does not count as a completed form change in `stats.borrowed_face`; a Borrowed Face ruling settles both.

---

## Out of Scope

- Any new reveal VFX: the reveal reuses the transformation-reveal scare (Scare Events, FormChanged into true form).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/monster-abilities/lunge_from_disguise_test.gd` plus unit tests in `tests/unit/monster-abilities/` and `tests/unit/borrowed-face/`

**Status**: [x] `tests/integration/monster-abilities/lunge_from_disguise_test.gd` (real ENet, 5 RoundClients: a survivor client renders the true-form body while the server is still in wind-up with no SurvivorHit, then the lunge downs the copied survivor); unit tests in `request_validation_test.gd`, `transform_state_machine_test.gd`, `monster_stun_test.gd` (rejection reason now Transforming), and `tests/integration/borrowed-face/disguise_restrictions_test.gd` rewritten for the accept-and-reveal rule. ShapeshifterAim already sent the lunge in any form (no client change). 3 mutations caught.

---

## Dependencies

- Depends on: monster-abilities 006, 011; borrowed-face 005
- Unlocks: None

## Closed (2026-10-15)

Integration gate: `tests/integration/monster-abilities/lunge_from_disguise_test.gd` (real ENet, 5 clients) passes; 3 mutations caught. Full suite on merge: 1572 tests, 0 failures, 0 leak lines. Designer decision from the 2026-10-15 playtest (AD-243). Inference marked proposed: the reveal is instant, starts no form-change cooldown and is not counted in form_changes.
