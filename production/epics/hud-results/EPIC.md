# Epic: HUD & Results Screen

> **Layer**: Presentation
> **GDD**: none. The design record is the two UX specs, `design/ux/hud.md` and `design/ux/results.md` (both reviewed by `/ux-review` 2026-10-15; fixes in AD-227 to AD-232), with patterns from `design/ux/interaction-patterns.md`.
> **Architecture Module**: HUD & Results (`docs/architecture/architecture.md` Presentation layer)
> **Status**: Ready
> **Stories**: 12 stories, see the Stories table below

## Overview

This epic builds the in-round HUD and the end-of-round Results screen as views over state the server already owns. The HUD reads only a client `HudModel`, which the snapshot handler and `ClientEventRouter` feed (ADR-0014 §6). It shows the clock and phase label, the roster, the objective checklist, the crosshair, the interaction prompt and hold ring, refusal labels, own-state vignettes and bleed-out, edge cues, and the shapeshifter's face list, form and ability cooldowns. The Results screen presents the `RoundResults` payload that Match Flow builds once (ADR-0011): outcome, per-survivor fate with downs, rescues and stuns landed, and team and monster stats, then returns to the lobby after `results_duration_s`. The lobby gains its "Last round" button. Pieces already merged and reused here:
- the minimal `InputContextStack` and the ping markers, callout wheel and feed (pings-and-callouts 008 and 011);
- the predicted hold bar (`src/core/controller/predicted_hold_bar.gd`);
- the scare presenters (scare-events 008 and 009);
- `RoundResults` and `MatchDisplay.results()` (match-flow 008).

The epic also closes the drift `/ux-review` found between the shipped Sprint 8 feed and markers and `hud.md`:
- the feed's 4-line cap, scrollback view and opaque backing;
- a global cap of 6 markers;
- a distinct shape per ping type;
- gamepad stick steering of the wheel;
- the 21:9 safe rectangle;
- the flinch-off edge pulse (P8).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0014: UI and input focus | `InputContextStack` is the sole writer of mouse mode and the input mask; fixed `UiLayers`; stock `Control` focus; `HudModel` is the HUD's only source; `accessibility_name` and live regions; `tr()` everywhere | HIGH |
| ADR-0011: Round stats and results payload | Owners expose `*StatsView`s; `MatchFlow.resolve` builds `RoundResults` once; missing views are listed in `missing` | LOW |
| ADR-0005: Event catalog, state registry and tick order | HUD consumes `RoundPhaseChanged`, `ObjectiveProgressChanged`, `RoundEnded` and the rest through `ClientEventRouter` | HIGH |
| ADR-0004: Replication scope and information hiding | A survivor client never receives shapeshifter-only state, so S1–S7 never render there | HIGH |
| ADR-0015: Scare presentation and view offset | `SCARE_FX` layer below `CAPTIONS`; the flinch-off pulse is the HUD's substitute cue | MEDIUM |

## GDD Requirements

The TR registry has no `hud` or `results` system; the UX specs postdate it. Requirements come from the specs' acceptance criteria, keyed `UX-hud-NN` and `UX-results-NN` until `/architecture-review` registers them.

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-ui-001 | Ping markers, callout wheel and feed, hold bar, results screen | ADR-0014 ✅ |
| UX-hud-01 | Every HUD element at least 48 px from each edge (64 px from the 16:9 safe rectangle at 21:9) | ADR-0014 (inferred) |
| UX-hud-02 | Per-state element set (exploration, chase, holding, downed, seized, hidden, spectating, paused) matches the state table; roster Off variant | ADR-0014 (inferred) |
| UX-hud-03 | Downed: vignette and word, crosshair hidden, own bleed-out replaces the prompt | ADR-0014 (inferred) |
| UX-hud-04 | A survivor client never renders S1–S7 | ADR-0004, ADR-0014 (inferred) |
| UX-hud-05 | Screen coverage at most 8% in exploration and 12% in the busiest state | ❌ No ADR |
| UX-hud-06 | Every state distinguishable by shape or word under colourblind simulation | ADR-0014 (inferred) |
| UX-hud-07 | Feed: four lines visible, ten in scrollback, none dropped | ADR-0014 (inferred) |
| UX-hud-08 | Lunge cue at 19 m, not at 21 m (`lunge_cue_radius_m`) | ADR-0015 (inferred) |
| UX-hud-09 | Reduced motion: nothing moves or pulses | ADR-0014 (inferred) |
| UX-hud-10 | Critical text and marker labels at least 20 px; feed at least 28 px at 1080p | ADR-0014 (inferred) |
| UX-results-01 | Results screen presents the `RoundResults` payload: outcome, fates, per-survivor downs, rescues and stuns, team and monster stats | ADR-0011 (inferred) |
| UX-results-02 | A stats group listed in `missing` shows "Results unavailable", never 0 | ADR-0011 (inferred) |
| UX-results-03 | Auto-return to the lobby after `results_duration_s`; lobby "Last round" view | ADR-0014 (inferred) |
| UX-results-04 | Focus order, `accessibility_name` per row, countdown never a live region | ADR-0014 (inferred) |

Untraced requirements are informational at `workflow: standard`. "Inferred" means the orchestrator read which accepted ADR governs a spec criterion; the registry does not list them yet.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/ux/hud.md` and `design/ux/results.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` — each screen touched for UI, plus a lead sign-off for Visual/Feel

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | HudModel, UiLayers and the full InputContextStack | Logic | Complete | ADR-0014 |
| 002 | Clock, phase, roster, objective checklist and crosshair | UI | In Review | ADR-0014 |
| 003 | Interaction prompt, hold ring, reject label and input glyphs | UI | In Review | ADR-0014 |
| 004 | Own-state vignettes, own bleed-out and the HUD state table | UI | Ready | ADR-0014 |
| 005 | Edge cues, flinch-off pulse, taser count and world progress bars | UI | In Review | ADR-0014 |
| 006 | Shapeshifter HUD and survivor-side absence | UI | In Review | ADR-0014 |
| 007 | Feed cap, opaque backing, marker cap, shapes and wheel stick steering | UI | In Review | ADR-0014 |
| 008 | Results screen | UI | Ready | ADR-0014 |
| 009 | Lobby "Last round" view | UI | Ready | ADR-0014 |
| 010 | Visual budget and accessibility verification pass | UI | Ready | ADR-0014 |
| 011 | Server feeds the HUD still lacks: round roster names and hold refusal reasons | Integration | Ready | ADR-0004 |
| 012 | Gamepad bindings for every action | UI | Ready | ADR-0014 |

## Next Step

Run `/create-stories hud-results` to break this epic into implementable stories.
