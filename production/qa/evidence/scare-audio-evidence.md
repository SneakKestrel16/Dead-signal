# Test Evidence: Scare audio: positional origin, stingers, ducking and volume scales

> **Story**: `production/epics/scare-events/story-008-scare-audio.md`
> **Story Type**: Visual/Feel
> **Date**: 2026-10-15
> **Tester**: gameplay-programmer agent (capture run); lead sign-off pending
> **Build / Commit**: wt-se8, `ScareAudio` commit bd8f599 plus the capture flag in `tests/manual/round_view.gd`

---

## What Was Tested

`ScareAudio` (`src/feature/scare_events/scare_audio.gd`) on a rendering client of a real round: a Major `blackout`
scare (the shapeshifter's Blackout at its own spot, 3.9 m from the shown survivor) delivered over ENet, with
footsteps and a taser stun overlapping it. Bus peaks were read every drawn frame for 240 frames from the first
frame the shown client received `ScareTriggered`. All sounds are placeholders (generated tones); the story's
Engine Notes say sign-off covers placeholder audio and must be re-verified when final audio lands.

**Acceptance criteria covered**: AC-1, AC-2, AC-3

---

## Acceptance Criteria Results

| # | Criterion (from story) | Result | Notes |
|---|----------------------|--------|-------|
| AC-1 | Lunge wind-up and transform distortion cues play at full level during any scare and with any accessibility setting. | PASS (by construction + measured) | Ducking writes only `Ambience` and `ScareDuck`; `GameplayCues` (where `PlaceholderAudio` now plays every cue) is never written, and no scale setting touches it (unit test `test_scales_write_only_their_bus_and_never_move_stinger_timing`). Run 1: `GameplayCues` peaked at +2.0 dB at frame +6, while the duck was at its full -8.0 dB. Lunge and distortion presenters play on their own players (Master); not captured in this run. |
| AC-2 | A stinger plays only on a Major scare and at most `stinger_max_db_rel` (+6 dB) above the ambient bed. | PASS (gain), meter UNRESOLVED | Only a delivered Major starts a stinger (unit tests). The stinger tone peaks at the bed's placeholder amplitude (0.2) and plays at +6.0 dB gain = `stinger_max_db_rel`. Stinger bus peak, both runs: **+4.0 dB**. Undducked Ambience bus peak (zone A bed, 0.0 dB player gain): **-4.0 dB** in run 1, **-0.4 dB** in run 2, so the measured gap is +8.0 dB (run 1) or +4.4 dB (run 2). The same bed reads 3.6 dB apart between runs, so the meter does not settle this; see Observations. |
| AC-3 | A diegetic scare sound comes from its true origin, with correct direction and distance for the listener; stinger and scare master scales change level only, never timing. | PASS | The diegetic `AudioStreamPlayer3D` sits at the projected origin on `ScareSFX`, `max_distance` = the entry's `audible_range_m` (unit test). Capture: origin (2.53, 0.00, 27.51), bearing -7.9 deg from the camera, 3.88 m. Scales write only the `Stinger` / `Scare` buses; the stinger start (one sim tick after the scare) is unchanged at scale 0.5 (unit test). |

### Measured bus peaks (dB, `AudioServer.get_bus_peak_volume_left_db`, frames after the scare arrived)

Run 1 (`--bot=stage --stun --scare-audio`, port 30480):

| Frame | Duck (dB) | Ambience | GameplayCues | Scare | ScareDuck | Stinger | ScareSFX | Master |
|---|---|---|---|---|---|---|---|---|
| +0 | -7.11 | -11.1 | silent | silent | silent | silent | silent | -11.1 |
| +1 | -6.89 | -10.9 | silent | -2.9 | -2.9 | **4.0** | silent | -0.1 |
| +5 | -8.00 | -12.0 | silent | 1.2 | 1.2 | 3.2 | 3.3 | 2.8 |
| +6 | -8.00 | -12.0 | **2.0** | 1.0 | 1.0 | 3.1 | 3.1 | 4.6 |
| +99 | 0.00 | **-4.0** | silent | silent | silent | silent | silent | -4.0 |
| max over 240 | | -4.0 | 7.7 | 3.3 | 3.3 | 4.0 | 3.8 | 9.0 |

The duck was already running at +0: footsteps of the staged line (gameplay cues) were ducking. Ambience ducked
reads -12.0 against -4.0 undducked: exactly `duck_db` (-8.0). The duck returned to 0.0 dB after the cues stopped.

Run 2 (`--bot=stage --scare-audio`, no stun, port 30481, stinger tone temporarily 110 Hz to match the zone A bed;
reverted): Stinger peak max **+4.0**, Ambience max **-0.4** (ducked -8.4), ScareSFX max 4.3, GameplayCues max 2.1.

---

## Screenshots / Video

| # | Filename | What It Shows | Acceptance Criterion |
|---|----------|--------------|----------------------|
| 1 | `scare-audio/scare.png` | Shown survivor 3 frames after the blackout scare arrived: the staged line with the shapeshifter (the scare origin) ahead, zone A ambience overlay at 0.0 dB player gain | AC-3 |

Audio is not visible in a screenshot; the numbers above are the evidence. The run's movie (`--write-movie`) was
not retained (size).

---

## Test Conditions

- **Game state at start**: `round_host.gd --players=5`, `round_view.tscn --count=5 --view=survivor --bot=stage --scare-audio` (run 1 also `--stun`); shipped knobs (`duck_db` -8, `duck_attack_s` 0.05, `duck_release_s` 0.6, `stinger_max_db_rel` 6)
- **Platform / hardware**: Windows 11, windowed 1280x720, Movie Maker (`--write-movie`, fixed 60 fps)
- **Framerate during test**: fixed 60 fps (Movie Maker)
- **Any special setup required**: the `--scare-audio` flag added to `tests/manual/round_view.gd` for this story

---

## Observations

- AC-2 meter: identical-amplitude sine beds read -4.0 and -0.4 dB in two runs, and every reading is about 10 dB above the source amplitude (0.2 = -14 dBFS). Inference: Godot's bus peak meter is not a loudness measure for these placeholder tones (training-data API, not in `docs/engine-reference`). What would settle it: a loudness (LUFS) measurement of the recorded movie audio, or the AudioDirector's final assets authored loudness-normalised to the bed (ADR-0013 §5).
- Rule 17 timing: the stinger starts one sim tick after the scare in script time, but the 3D origin sound's bus first shows level at frame +2, a frame after the stinger (+1). The stinger does not cover the origin (it overlaps it), but it is heard first by about one frame. A designer call on whether the stinger should lag further would settle it.
- Lunge wind-up and transform distortion play on their presenters' own players (default bus), not through `GameplayCues`; ducking never writes the bus they use either.

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Lead (designer, owner of scare-events) | | | [ ] |
