# Story 003: Interaction prompt, hold ring, reject label and input glyphs

> **Epic**: HUD & Results Screen
> **Status**: In Review
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

H7-H9: the interaction prompt with verb, object, glyph and Hold or Press, the hold ring with its cancel cause, and the short refusal label. The predicted hold bar exists as a greybox rectangle in `RoundClient` (BAR_SIZE). ADR-0014 §8 adds an `InputGlyphs` helper keyed on the last-used device class.

**GDD**: `design/ux/hud.md` H7-H9; patterns P2, P3, P10, P18
**Requirement**: `TR-ui-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus
**ADR Decision Summary**: InputGlyphs maps an action to the glyph of its first InputMap event for the last-used device class, detected by event type, never device == 0.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `InputEvent.DEVICE_ID_*` (4.7) and the SDL3 gamepad driver (4.5): check the engine reference.

**Control Manifest Rules (this layer)**:
- Required: device class by event type or DEVICE_ID_*, never device == 0
- Required: the predicted hold ring is replaced by the server echo

---

## Acceptance Criteria

*From GDD `design/ux/hud.md`, scoped to this story:*

- [ ] A valid target shows the prompt with verb, object, the glyph for the last-used device and Hold or Press; switching from keyboard to gamepad changes the glyph without restart.
- [ ] Holding shows the ring driven by the predicted hold and corrected by the server echo; a cancel shows its cause for 1 s, and the broken ring plays for 200 ms (hud.md H8 and Z5 table, interaction-patterns P3; corrected 2026-10-15, AD-239).
- [ ] A refused action shows its reason label for 1.5 s; only one of prompt, ring, bleed-out or transforming bar shows in Z4 at once.
- [ ] Retained screenshots of prompt, ring and refusal.

---

## Implementation Notes

- Replace the greybox bar in RoundClient; keep its prediction code.
- Glyph textures are placeholders (text glyphs are fine) until art lands; mark them.

---

## Out of Scope

- Remapping UI.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: retained screenshot of each screen touched in `production/qa/evidence/prompt-hold-ring-reject/`

**Status**: [x] production/qa/evidence/prompt-hold-ring-reject-evidence.md (4 png); tests/unit/hud-results/prompt_hold_ring_reject_test.gd (10)

---

## Dependencies

- Depends on: Story 001
- Unlocks: None

## Progress Notes (2026-10-15)

Merged 6e96cb0+2cf1c1e. InputGlyphs (device class by event type, stick dead zone 0.5, live InputMap; placeholder text glyphs, glyph_text() not the ADR glyph_for Texture2D). InteractionHud owns Z4/Z5: prompt, drawn hold ring, broken ring on cancel, full ring on completion, one label newest-wins; Z4 exclusive; hidden while the stack blocks actions. PredictedHoldBar gains ended(cause). DEVIATIONS: cancel-cause label 1 s per P3 (story said 200 ms; the broken ring lasts 200 ms) needs a ux ruling; server sends no cancel or refusal reason, so labels read "Interrupted" / "Not now" (a reason byte in the own snapshot entry settles it); completion vs cancel inferred from predicted elapsed; prompt verbs per marker type are inference; project.godot binds no gamepad events, so a pad shows "?" in game (device switch unit-tested only); Hold/Toggle, reduced motion and deny sounds not built (no settings store, no audio event); PingCalloutHud "Too fast" label can overlap at +100 px. 10 unit tests; 5 mutations caught. Full suite 1433/1433 (one earlier run failed round_composer_test on a port held by a runaway agent test process; re-run clean after stopping it).
