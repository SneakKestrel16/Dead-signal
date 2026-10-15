# Story 011: Shipped client input for Lunge, False Signal and Blackout, with placement preview

> **Epic**: Monster Abilities
> **Status**: In Review
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

**Status**: [x] `production/qa/evidence/client-ability-input/` (7 screenshots, lead sign-off pending); `tests/unit/monster-abilities/client_ability_input_test.gd` (10 tests)

---

## Dependencies

- Depends on: match-flow 013; hud-results 006
- Unlocks: None

## Progress Notes (2026-10-15)

Merged 09f9ddd..1374fe9 (round_view bot conflict with HUD-4 resolved keeping both). ShapeshifterAim (mounted on first shapeshifter state; gated by HudModel.is_shapeshifter() and contexts.allows_actions(); a context push drops the aim): Lunge on press; False Signal and Blackout preview while held (snapped floor point and footstep path; target volume outline), send on release; invalid preview crossed out and sends nothing. MapQueries.floor_point shared by client preview and server. SERVER FIX: RoundComposer now passes the False Signal sources (floor snap, observed, status_of, footstep set c<appearance>.walk, install sound radius, step interval); before this the shipped server rejected every False Signal. Model, contexts and multiplayer bound as WeakRefs (first version leaked on survivor clients). INFERENCE: bindings lunge = right mouse, False Signal = R, Blackout = X; False Signal always Footsteps along the view direction as the first face-list survivor (no selector in the spec); floor snap assumes volumes tile a flat floor; no path cut (straight lines through walls, server and preview alike); preview range from camera minus eye height (server uses body); preview does not check blackout_able, dark zones or cooldowns. Evidence via round_host + round_view (same RoundClient as the lobby); bo_dark.png looks like the preview because emergency light stays on. 10 unit tests (watched fail first); 3 mutations caught; tests/integration/hud-results clean. Full suite 1510/1510, no leak lines.
