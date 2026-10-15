# Story 006: Shapeshifter HUD and survivor-side absence

> **Epic**: HUD & Results Screen
> **Status**: In Review
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

S1-S7 are the shapeshifter's elements: face list with observation progress, form and form cooldown, ability cooldowns, transforming bar, stun or immunity remaining, the install alert and the placement preview. A survivor client must never render any of them, which ADR-0004 makes true at the data level and this story proves at the tree level.

**GDD**: `design/ux/hud.md` S1-S7
**Requirement**: `TR-ui-001`, UX-hud-04
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus; secondary: ADR-0004
**ADR Decision Summary**: Shapeshifter-only state never reaches a survivor client; HUD widgets read HudModel only.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: S1-S7 are not instanced on a survivor client
- Forbidden: hiding S1-S7 with visibility while instanced on a survivor client

---

## Acceptance Criteria

*From GDD `design/ux/hud.md`, scoped to this story:*

- [ ] The shapeshifter sees S1-S3 always and S4-S7 in their trigger states, values matching server state (cooldowns within 0.1 s).
- [ ] An automated check on a survivor client's HUD tree finds no S1-S7 node in any state.
- [ ] Retained screenshots of the shapeshifter HUD in true form, disguised and transforming.

---

## Implementation Notes

- Placement preview for False Signal and Blackout may already exist in monster-abilities client code: reuse it.

---

## Out of Scope

- Ability balance.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: retained screenshot of each screen touched in `production/qa/evidence/shapeshifter-hud/`

**Status**: [x] production/qa/evidence/shapeshifter-hud-evidence.md (4 png); tests/unit/hud-results/shapeshifter_hud_test.gd; tests/integration/hud-results/shapeshifter_hud_absence_test.gd

---

## Dependencies

- Depends on: Story 001
- Unlocks: None

## Progress Notes (2026-10-15)

Merged ddb94c6..9ea6b90. Server: MonsterHudFeed (batch_extras, shapeshifter peer only; survivors and spectators get []) sends EventBatch.MONSTER_HUD {ready per ability and form, transform_end, stun_end, immune_end, faces [survivor, observed_s, appearance]} as absolute ticks, re-sent on change; getters BorrowedFace.cooldown_end_tick/transform_end_tick, SurvivorDefense.lock_end_tick/free_tick; composer keeps a reference to the feed (integration test caught it being freed). Client: HudModel on_monster_hud, faces, transform_progress, stun/immunity remaining, install_alerts, signal monster_state_changed (seventh signal, deviation from ADR-0014 §6); widgets shapeshifter_hud/face_list/kit/status/install_alert, mounted on first shapeshifter state so survivors never instance S nodes. NOT DONE: S7 placement preview (no client ability input exists; follow-up monster-abilities 011); S6 unit-tested only, no screenshot; S3 greybox text, icons and sweep for the art pass; face names are CharacterDef ids; ambience debug overlay draws over the face list. on_cooldown from HUD-1 kept with no sender. Unit + integration (survivor-tree absence, real ENet); 4 mutations caught. Full suite 1458/1458.
