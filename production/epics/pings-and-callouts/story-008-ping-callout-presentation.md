# Story 008: Ping input, marker display, callout wheel and feed

> **Epic**: Pings & Callouts
> **Status**: Ready
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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 005, 006, 007
- Unlocks: None
