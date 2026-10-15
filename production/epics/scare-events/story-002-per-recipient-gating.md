# Story 002: Per-recipient scare gating, budgets and repeat block

> **Epic**: Scare Events
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Each client has gating state: last Major, last any, last fire per (scare_id, location), and a per-phase RoundScript budget. Major within the Major cooldown drops to Minor; RoundScript and Survivor scares are blocked inside the cooldowns; Monster-source scares are never blocked. All of it resets per round.

**GDD**: `design/gdd/scare-events.md` rules 9-12; Formulas (gating, phase budget)
**Requirement**: `TR-scare-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015: Scare presentation and view offset; secondary: ADR-0006
**ADR Decision Summary**: The server holds gating state per recipient; cooldowns and budgets are data.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: `major_scare_cooldown_s`, `minor_scare_cooldown_s`, `same_scare_repeat_block_s`, `phase_budget`, `hallucination_max_per_client` from `ScareKnobs`

---

## Acceptance Criteria

*From GDD `design/gdd/scare-events.md`, scoped to this story:*

- [x] A RoundScript scare within 45 s of a Major scare on the same client is blocked; a Monster scare in the same window plays as Minor.
- [x] A RoundScript scare within 10 s of any scare on the same client is blocked; no client receives more RoundScript scares in a phase than that phase's budget (2/6/4).
- [x] The same scare_id at the same location does not fire twice within 120 s; no client receives more than `hallucination_max_per_client` (2) hallucinations in a round.
- [x] A disguised shapeshifter entering an authored room or viewing a monitor fires the same scare a survivor would; the gating log is identical for both.

---

## Implementation Notes

- One pure gating function over a per-recipient record; test it without a scene.
- Gating is per recipient: one shared scare can be Major for one client and Minor for another.

---

## Out of Scope

- Story 003: who is a recipient.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/scare-events/per_recipient_gating_test.gd` must exist and pass

**Status**: [x] `tests/unit/scare-events/per_recipient_gating_test.gd` (12 cases)

---

## Dependencies

- Depends on: Story 001
- Unlocks: Stories 003-007

## Progress Notes (2026-10-15)

Merged from wt-se2. Full suite 1324/1324, no leak lines. Mutations caught: reduced Minor restarting the Major cooldown, budget off by one, Monster scares blocked, no budget reset on phase change (caught after the reset test was strengthened).

Deviations (inference):
- Once-per-round is per recipient; rule 11 does not say. A designer ruling settles it.
- The hallucination cap and repeat block skip Monster-source scares (the Formulas never block one).
- The Blackout block for RoundScript scares is not here; it needs lighting state (story 006).
- The repeat-block location key is the scare's origin. Infiltration, Investigation and Evacuation map onto the Low, Rising and Emergency budget slots.
- `fire()` returns true when every recipient is gated out; false still means the request was refused.
