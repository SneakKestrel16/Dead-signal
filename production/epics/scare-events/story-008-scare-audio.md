# Story 008: Scare audio: positional origin, stingers, ducking and volume scales

> **Epic**: Scare Events
> **Status**: In Review
> **Layer**: Feature
> **Type**: Visual/Feel
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Diegetic scare sounds play from their true origin. Stingers play only on Major scares, at most `stinger_max_db_rel` over the ambient bed. Gameplay cues and callouts are never masked; scares duck only `Ambience` and `ScareDuck`. Stinger and scare master volume scales are separate player settings. There is no AudioDirector yet; sounds are placeholders.

**GDD**: `design/gdd/scare-events.md` rules 16-18, 26
**Requirement**: `TR-scare-008`, `TR-scare-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013: Spatial audio pipeline; secondary: ADR-0015
**ADR Decision Summary**: All audio routes through the bus layout; ducking writes only `Ambience` and `ScareDuck`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No AudioDirector or AudioCatalog exists; use `placeholder_audio.gd` and the 15 buses in `default_bus_layout.tres`. Sign-off covers placeholder audio and must be re-verified when final audio lands.

**Control Manifest Rules (this layer)**:
- Required: ducking writes only `Ambience` and `ScareDuck`
- Required: gameplay cues and callouts are never ducked or stolen

---

## Acceptance Criteria

*From GDD `design/gdd/scare-events.md`, scoped to this story:*

- [ ] Lunge wind-up and transform distortion cues play at full level during any scare and with any accessibility setting.
- [ ] A stinger plays only on a Major scare and at most `stinger_max_db_rel` (+6 dB) above the ambient bed.
- [ ] A diegetic scare sound comes from its true origin, with correct direction and distance for the listener; stinger and scare master scales change level only, never timing.

---

## Implementation Notes

- Measure bus peak levels in a capture run and record the numbers in the evidence page.
- Standalone presenter with a one-line hook in `round_client.gd`.

---

## Out of Scope

- Final sound design.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: retained screenshot in `production/qa/evidence/scare-audio/` + lead sign-off in `production/qa/evidence/scare-audio-evidence.md`

**Status**: [x] `tests/unit/scare-events/scare_audio_test.gd` (7 cases); `production/qa/evidence/scare-audio-evidence.md` (AC-2 unproven, sign-off pending)

---

## Dependencies

- Depends on: Stories 001, 003
- Unlocks: None

## Progress Notes (2026-10-15)

Merged from wt-se8. Full suite 1384/1384, no leak lines. Mutations caught: stinger on every intensity, GameplayCues added to the ducked buses, stinger without its one-tick delay, stinger gain above the cap, MonsterScares no longer excluding the monster.

Evidence: `production/qa/evidence/scare-audio-evidence.md` + `scare-audio/scare.png` (sign-off unchecked). Capture (windowed `--write-movie`, `round_view --bot=stage --scare-audio`):
- Ducked Ambience -12.0 dB vs -4.0 dB unducked (exactly `duck_db`); GameplayCues peaked +2.0 dB at full duck (never ducked).
- Scare origin at bearing -7.9 deg, 3.88 m from the camera.
- **AC-2 not proven:** the Stinger bus peaked +4.0 dB in both runs, but the unducked bed read -4.0 dB in one run and -0.4 dB in the other, so the gap was +8.0 or +4.4 dB. The peak meter cannot measure loudness for these placeholder tones; a LUFS measurement of recorded audio, or final assets authored to the bed level, settles it.

Notes:
- `ScareAudio` (client): diegetic `AudioStreamPlayer3D` at the true origin on ScareSFX (`max_distance` = audible range); stinger only on a delivered Major, non-positional on Stinger, one sim tick later, at `stinger_max_db_rel`; ducking writes only Ambience and ScareDuck (`duck_db`/attack/release), triggered by gameplay cues, `PlayerShocked`, `MonsterStunned`; `stinger_scale` and `scare_scale` write only Stinger and Scare.
- `round_client.gd` now feeds `ScarePresenter` the shipped catalogue (it was `{}`). `PlaceholderAudio` cues play on GameplayCues.
- `MonsterScares` now selects recipients with `ScareRelevance` (story 003); its test hides out-of-range players in sight-blocking booths (the composed round has no map collision).

Deviations (inference):
- Ducking holds a fixed time per trigger instead of ADR-0013's start/finish counter (`ponytail:`; equivalent while every cue is a fixed beep). Players are created per sound (no AudioDirector pool).
- Lunge wind-up and transform distortion still play on their presenters' own players on Master; ducking never touches them.
- The stinger shows on its bus one frame before the 3D origin sound: a rule 17 "covers the origin" question for the designer.
- Placeholder tone lengths, pitches and diegetic amplitude are unsourced. Re-verify when final audio and the AudioDirector land.
