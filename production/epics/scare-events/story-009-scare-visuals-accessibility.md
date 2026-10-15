# Story 009: Scare visuals and flash accessibility

> **Epic**: Scare Events
> **Status**: In Review
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

**Status**: [x] `tests/unit/scare-events/scare_visuals_accessibility_test.gd` (5 cases); `production/qa/evidence/scare-visuals-accessibility-evidence.md` (sign-off pending)

---

## Dependencies

- Depends on: Stories 003, 006
- Unlocks: None

## Progress Notes (2026-10-15)

Merged from wt-se9. Full suite 1377/1377, no leak lines. Mutations caught: strobe skipping the limiter, reduced-flash sync removed, hallucination target check never matching.

Evidence: `production/qa/evidence/scare-visuals-accessibility-evidence.md` (sign-off unchecked). Windowed `--write-movie` captures at 60 fps:
- Flash scale 1: `framed1/strobe.png` (red pool under the H-S1 strobe) vs `framed1/between.png` (unlit, 30 frames later); at most 2 strobe onsets in any 60 frames.
- Flash scale 0: `framed0/strobe.png` and `framed0/between.png` identical, a steady light; one onset in the run.
- Hallucination: `hall/hallucination.png`, red static on the C1 screen of client 0 only (clients 1-4 false on the shot frame).

Notes:
- `ScareVisuals` (client): Emergency strobe gated by `FacilityScareDisplay.state()`, pulsing at `alarm_pulse_hz` with energy `beacon_energy * flash_scale` through `ScarePresenter.try_flash()` (shared `FlashLimiter`), off in a blacked-out volume, steady at scale 0. `ScarePresenter.play()` now uses `try_flash()` too.
- Manual tooling: `round_host --force=<s>:hallucinate`; `round_view --flash-scale=`, `--shot-when=strobe,hallucination`.

Gaps for sign-off:
- The rotating beacons (Facility Map `LightingPresenter`) light no floor in H-S1: ceiling height and range clipping, the same problem the strobe had. A Facility Map placement follow-up.
- The exit light is off in every shot (no run opened the exit).

Deviations (inference):
- No second beacon set: the Facility Map owns lighting (rule 22); `ScareVisuals` only sets reduced flash at scale 0.
- The strobe sits at mid-height under each beacon fixture (at the ceiling its 2 m range did not reach the floor). Facility Map alarm fixtures settle it.
- The hallucination uses the existing single-client `surveillance_image` (Survivor source); its server trigger (viewing the monitor) is not built, only the `round_host` force fires it.
- Unsourced constants: `HALLUCINATION_S` 0.4 s, `STROBE_ON_S` 0.08 s, the red-static placeholder.
