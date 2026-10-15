# Story 009: Scare visuals and flash accessibility

> **Epic**: Scare Events
> **Status**: Ready
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Visual scares: stinger flash and camera reaction (already in `ScarePresenter`), strobe alarm and rotating beacons in Emergency, and the impossible surveillance frame on one client's monitor as a hallucination. Flash scale and the 3 flashes/s cap apply to all of them through `FlashLimiter`.

**GDD**: `design/gdd/scare-events.md` rules 24, 25, 27-29; Visual/Audio Requirements
**Requirement**: `TR-scare-012`, `TR-scare-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015: Scare presentation and view offset; secondary: ADR-0009
**ADR Decision Summary**: Client-side accessibility hooks scale intensity only; they never change server timing, cooldowns or recipients.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: apply the `max_flashes_per_s` clamp in precompute; flash scale at render time
- Required: emergency strip lights stay on in every state

---

## Acceptance Criteria

*From GDD `design/gdd/scare-events.md`, scoped to this story:*

- [ ] With flash scale 0, no scare produces a luminance flash; scare timing and origin are unchanged.
- [ ] No scare produces more than 3 flashes per second, counting lighting flicker.
- [ ] Emergency state shows the strobe alarm and rotating beacons with landmarks and the exit still readable; the impossible surveillance frame appears only on the target client's monitor feed.

---

## Implementation Notes

- Reuse `FlashLimiter` and `ScarePresenter`; add only the Emergency and feed pieces.
- Capture with `tests/manual/round_view` on ports 30000-30999.

---

## Out of Scope

- Story 008: audio.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: retained screenshot in `production/qa/evidence/scare-visuals-accessibility/` + lead sign-off in `production/qa/evidence/scare-visuals-accessibility-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 003, 006
- Unlocks: None
