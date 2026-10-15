# Story 011: Shipped client input for Lunge, False Signal and Blackout, with placement preview

> **Epic**: Monster Abilities
> **Status**: Ready
> **Layer**: Feature
> **Type**: UI
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

The server accepts ability requests (`MonsterAbilities.request_packet`, `signal_packet`) but no shipped client code sends them: only `tests/manual/round_view.gd` writes raw packets. A shapeshifter in the shipped lobby-to-round build cannot lunge, fake a signal or black out a room. HUD-6 also found S7 (the placement preview) had nothing to drive it.

**GDD**: `design/gdd/monster-abilities.md` rules 1, 7, 9 (requests); hud.md S7
**Requirement**: `TR-monster-001`, `TR-monster-007`, `TR-monster-009`, `TR-ui-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus; secondary: ADR-0002
**ADR Decision Summary**: Inputs pass through the InputContextStack mask; the client sends intent only and the server validates every request.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: new input actions added to the action list pinned by view_direction_test
- Required: requests gated by contexts.allows_actions()
- Forbidden: the client deciding cooldowns, hits or validity

---

## Acceptance Criteria

*From GDD `design/gdd/monster-abilities.md`, scoped to this story:*

- [ ] A shapeshifter client presses the lunge action and the server receives a Lunge request; the lunge presenter and server state run as they do with the round_view bot.
- [ ] Holding the False Signal or Blackout action shows the S7 preview (the snapped point or path, or the target volume) and releasing sends the request at that aim; the server accepts or rejects as its rules say.
- [ ] A survivor client never sends an ability request and never shows S7.
- [ ] Retained screenshots of each preview and a landed lunge in the shipped lobby-to-round path.

---

## Implementation Notes

- Bindings are inference; mark them, a controls pass settles them.
- S7 lives beside the HUD-6 shapeshifter widgets in src/feature/hud_results/.

---

## Out of Scope

- Gamepad bindings (hud-results 012).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: retained screenshot of each screen touched in `production/qa/evidence/client-ability-input/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: match-flow 013; hud-results 006
- Unlocks: None
