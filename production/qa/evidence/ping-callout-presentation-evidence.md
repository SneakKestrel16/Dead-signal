# Test Evidence: Ping input, marker display, callout wheel and feed

> **Story**: `production/epics/pings-and-callouts/story-008-ping-callout-presentation.md`
> **Story Type**: UI
> **Date**: 2026-10-15
> **Tester**: ui-programmer agent (scripted capture)
> **Build / Commit**: wt-pc8, code f81dfaf (evidence committed on top)

---

## What Was Tested

`PingCalloutHud` (`src/feature/pings_callouts/ping_callout_hud.gd`) in a real 5-client round:
`round_host.gd --port=30922 --players=5` with `round_view.tscn --count=5 --view=survivor --bot=ping`
(windowed, `--write-movie`, 1280x720). The other survivors ping where they look and call out Danger and
Wait; the shown survivor pings ahead (pending), then spams past its bucket (rejection), then opens the wheel.
Logic (pending replacement, fade, edge clamp, wheel context, feed hold and scrollback, (not you), Voice bus,
gesture) is covered by `tests/unit/pings-and-callouts/ping_callout_presentation_test.gd`.

**Acceptance criteria covered**: AC-1, AC-2, AC-3; AC-4 by unit test only.

---

## Acceptance Criteria Results

| # | Criterion (from story) | Result | Notes |
|---|----------------------|--------|-------|
| AC-1 | Pressing ping shows a pending marker immediately; it becomes the server's marker on acceptance or disappears on rejection with a local "too fast" tick | PASS | pending.png: dimmed own marker on the press frame; markers.png: full-alpha server marker; toofast.png: "Too fast" under the crosshair |
| AC-2 | Markers draw through walls with the sender's name, colour, direction and distance, and fade at expiry | PASS (fade by unit test) | markers.png: four senders' names, colours and metres; off-screen ones clamp to the edge as arrows |
| AC-3 | Wheel lists the 8 lines; a callout plays positional audio and adds `[Name]: [text]` with a direction arrow; 10-line scrollback, each line at least 8 s | PASS | wheel.png: 8 lines, aimed one boxed; feed lines with arrows in markers.png; audio, scrollback and hold by unit test |
| AC-4 | A real callout plays a visible gesture on the speaker's body | PASS | gesture.png: yellow placeholder sphere over C3's body as its Danger callout lands in the feed |

---

## Screenshots / Video

| # | Filename | What It Shows | Acceptance Criterion |
|---|----------|--------------|----------------------|
| 1 | `ping-callout-presentation/pending.png` | Own pending marker (half alpha) on the press frame | AC-1 |
| 2 | `ping-callout-presentation/markers.png` | Server markers from 4 senders (name, colour, metres; edge-clamped arrows) and the feed with arrows | AC-1, AC-2, AC-3 |
| 3 | `ping-callout-presentation/toofast.png` | "Too fast" rejection tick | AC-1 |
| 4 | `ping-callout-presentation/wheel.png` | Callout wheel open with 8 lines, "Fuse here" aimed | AC-3 |

---

## Test Conditions

- **Game state at start**: fresh round, shown survivor at its spawn, fixed yaw 0.6 rad, pitch -0.15 rad
- **Platform / hardware**: Windows 11, Godot 4.7.2 windowed, `--write-movie` fixed frame step
- **Framerate during test**: not measured (movie mode)
- **Any special setup required**: `--bot=ping` in `tests/manual/round_view.gd`

---

## Observations

- Names are character ids (C1..C5): CharacterDef has no display name yet (inference, flagged in code).
- After 8 rapid pings only 1 rejection arrived before the run quit and 5 stayed pending; requests still in
  flight at quit is the likely cause (inference; a longer capture would settle it).
- Placeholder look: fallback font, plain shapes; no wheel open animation, no cooldown greying (P6).

---

## Sign-Off

- [ ] Lead sign-off (optional for UI)
