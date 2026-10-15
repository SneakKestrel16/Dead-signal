# Story 003: Callout acceptance limits and attached item ping

> **Epic**: Pings & Callouts
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Callouts have a per-player global cooldown and a per-line repeat block. "Drive here" and "Fuse here" may attach an item ping, which spends a ping token. A False Signal fake callout touches no limit state at all.

**GDD**: `design/gdd/pings-and-callouts.md` rules 9, 13, 16, 17; Formulas: callout acceptance
**Requirement**: `TR-pings-003`, `TR-pings-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Authoritative simulation, tick rate and input; secondary: ADR-0006
**ADR Decision Summary**: Callouts are client intents validated on the server; limits are data.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: `callout_global_cooldown_s` and `callout_repeat_block_s` come from `PingKnobs`
- Forbidden: never let a fake callout write limit state

---

## Acceptance Criteria

*From GDD `design/gdd/pings-and-callouts.md`, scoped to this story:*

- [ ] The same callout sent twice within 8 s is delivered once; after a callout at t=0, a different callout at t=1 is rejected and one at t=3 is accepted. Only accepted callouts update `last_callout_any` and `last_callout[line]`.
- [ ] "Drive here" with an attached item ping spends one ping token in addition to the callout; with 0 tokens the callout plays without the attached ping.
- [ ] A fake callout leaves the impersonated survivor's and the monster player's callout cooldowns and ping tokens unchanged: the survivor's same-line callout sent 1 s after the fake is accepted.
- [ ] A False Signal fake callout never carries an attached item ping.

---

## Implementation Notes

- The 8 lines are authored data (rule 9); store them as a data resource, not string literals in code.
- A fake callout arrives as `AbilityUsed` with signal type CALLOUT from Monster Abilities (`monster_abilities.gd` line 437 says Pings & Callouts owns its voice and feed line).
- Initial `last_callout_*` values are minus infinity, so the first callout is always accepted.

---

## Out of Scope

- Story 006: who receives a callout.
- Story 007: identity and (not you) marking.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/pings-and-callouts/callout_limits_attached_ping_test.gd` must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: Story 006
