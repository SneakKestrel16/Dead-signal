# Story 008: Ping input, marker display, callout wheel and feed

> **Epic**: Pings & Callouts
> **Status**: In Review
> **Layer**: Feature
> **Type**: UI
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

The client half: a ping button and callout wheel send intents; markers draw through walls with direction and distance for their lifetime; callouts play the voice line positionally and add `[Name]: [text]` with an arrow to the feed. Placeholder voice lines are fine (no final audio). HUD layout follows `design/ux/hud.md` (Draft).

**GDD**: `design/gdd/pings-and-callouts.md` rules 2, 10, 12; UI Requirements; Visual/Audio Requirements
**Requirement**: `TR-pings-004`, `TR-pings-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus; secondary: ADR-0013
**ADR Decision Summary**: Input goes through `InputContextStack`; the HUD reads projected state; audio goes through the audio pipeline.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: `InputContextStack` is the only writer of `Input.mouse_mode` (ADR-0014). No AudioDirector exists yet; use `placeholder_audio.gd` and the 15 ADR buses in `default_bus_layout.tres`.

**Control Manifest Rules (this layer)**:
- Required: `InputContextStack` masks input by the top context; the wheel pushes its own context
- Required: UI reads only projected client state
- Required: callouts are never ducked by scare or ambience sounds

---

## Acceptance Criteria

*From GDD `design/gdd/pings-and-callouts.md`, scoped to this story:*

- [ ] Pressing ping shows a pending marker immediately; it becomes the server's marker on acceptance or disappears on rejection with a local "too fast" tick.
- [ ] Markers draw through walls with the sender's name, colour, direction and distance, and fade at expiry.
- [ ] The callout wheel lists the 8 lines; a callout plays positional audio from its origin and adds `[Name]: [text]` with a direction arrow to the feed; the feed keeps a 10-line scrollback and each line stays at least 8 s (AD-02).
- [ ] A real callout plays a visible gesture on the speaker's body for viewers with line of sight.

---

## Implementation Notes

- Standalone presenter with a one-line hook in `round_client.gd` (house rule).
- Capture screenshots with `tests/manual/round_view` on ports 30000-30999.

---

## Out of Scope

- Rebinding (Accessibility Options).
- Final voice recordings.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: retained screenshot of each screen touched in `production/qa/evidence/ping-callout-presentation/`

**Status**: [x] `tests/unit/pings-and-callouts/ping_callout_presentation_test.gd` (9 cases); `production/qa/evidence/ping-callout-presentation-evidence.md` (sign-off pending)

---

## Dependencies

- Depends on: Stories 005, 006, 007
- Unlocks: None

## Progress Notes (2026-10-15)

Merged from wt-pc8. Full suite 1393/1393, no leak lines. Mutations caught: behind-camera negation removed in `place()`, feed scrollback cap removed, wheel pop removed, every callout given a gesture.

Evidence: `production/qa/evidence/ping-callout-presentation-evidence.md` with `pending.png`, `markers.png`, `toofast.png`, `wheel.png` (sign-off unchecked; `round_view --bot=ping`).

Notes:
- `PingCalloutHud` (Control in the client `hud` layer) reads only `PingReceiver`, `PingMarkers` and `CalloutReceiver`: pending marker on press, server marker or a 1.5 s "too fast" tick after; markers through walls with name, colour, direction and distance, fading at expiry; callout wheel (8 lines) pushing its own input context; positional callout audio on the Voice bus (never ducked); feed `[Name]: [text]` with an arrow, every line shown at least 8 s, 10 kept; "(not you)" appended; a placeholder gesture sphere over the speaker.
- New minimal `InputContextStack` (`src/core/ui/input_context_stack.gd`, ADR-0014 §1): push/pop with stale-pop error, `allows_*`, mouse-mode write only when the cursor flag changes. `LocalInput` masks mouse look while the top context disallows it.
- Existing bindings used: `ping` (middle mouse), `callout_wheel` (Q, hold).

Not done (follow-ups):
- Warning pings (player target, separate action); only location and item pings are wired.
- Hold-to-show feed scrollback (needs a new action and the `view_direction_test` action list).
- Wheel toggle mode, gamepad steering, cooldown greying, open animation; screen-reader live region for the feed.
- On-screen capture of the gesture (unit-tested only).
- `InputContextStack` focus restore and round start/end reset; `LocalInput` still captures the mouse itself.
- Open question: in the capture, 8 rapid pings gave 1 rejection and 5 still pending at quit. Inference: replies in flight when the run ended. Note the server drops requests beyond `ping_bucket_size` in one tick with no rejection echo (story 004), which would leave a pending marker forever; a key press cannot reach that rate, a modified client can. A longer run settles which.

Deviations (inference):
- Names are character ids (C1-C5); `CharacterDef` has no display name.
- Marker fade-out 150 ms (hud.md H12 gives only fade-in); gesture 0.5 s; wheel dead zone 40 px placeholder. The feed shows every line younger than 8 s, overriding P9's "last 4".
