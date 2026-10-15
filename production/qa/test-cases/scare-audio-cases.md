# Manual Test Cases: SE-8 Scare audio

> **Story**: `production/epics/scare-events/story-008-scare-audio.md`
> **Story type**: Visual/Feel | **Output**: this file + `production/qa/evidence/scare-audio/` + `scare-audio-evidence.md` | **Gate**: BLOCKING
> **GDD**: `design/gdd/scare-events.md` rules 16-18, 26; Acceptance Criteria ("Lunge wind-up and transform distortion cues play at full level...")
> **Sign-off**: designer (audio lead) | **Placeholder audio**: re-verify when final audio and AudioDirector land
> **Date written**: 2026-10-15 | **Tester**: ______ | **Build/commit**: ______

## Shared setup

```
GODOT="C:/Users/Ockey/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"
```

- Host: `"$GODOT" --headless --path . -s res://tests/manual/round_host.gd -- --port=<P> --players=5`
- View: `"$GODOT" --path . res://tests/manual/round_view.tscn -- --port=<P> --count=5 --view=survivor --bot=stage --scare-audio [--stun]` (windowed; add `--write-movie <file>.avi --fixed-fps 60 --resolution 1280x720 --shots=production/qa/evidence/scare-audio` for captures). Ports 30960-30969 here.
- `--scare-audio` prints the shown client's `ScareTriggered`, `ScareAudio` levels, saves `scare.png` and `duck.png`, then prints each bus peak per drawn frame for `SCARE_AUDIO_FRAMES` frames and the per-bus maxima. `--stun` overlaps a PlayerShocked/MonsterStunned duck.
- Bus peaks come from `AudioServer.get_bus_peak_volume_left_db`, a peak meter and not a loudness measure for these placeholders (see SE8-04). Use fresh ports; read output before trusting a run.
- Headphones needed for SE8-05 and SE8-06.

---

## Test Case: SE8-01 — Gameplay cues never ducked; duck exact (AC-1, manifest rule)
**Precondition**: Port 30960 free; shipped knobs `duck_db` -8, `duck_attack_s` 0.05, `duck_release_s` 0.6.
**Steps**:
  1. `"$GODOT" --headless --path . -s res://tests/manual/round_host.gd -- --port=30960 --players=5`
  2. `"$GODOT" --path . res://tests/manual/round_view.tscn -- --port=30960 --count=5 --view=survivor --bot=stage --scare-audio --stun`
  3. Record from the printed table: Ambience peak ducked vs unducked, GameplayCues peak while the duck is at full depth, the per-bus maxima.
**Expected Result**: Ambience reads exactly `duck_db` (8.0 dB) lower while ducked than unducked; GameplayCues is audible during the full duck (not reduced); ScareSFX/Stinger/Master not written by ducking.
**Actual Result**:
**Pass Criteria**: Ambience delta = 8.0 dB +/- 0.2; GameplayCues peak at full duck is not below its value in a no-duck frame (reference run: +2.0 dB while duck -8.0). Pass/Fail: ______

## Test Case: SE8-02 — Lunge wind-up cue at full level during a scare and with accessibility settings (AC-1)
**Precondition**: Port 30961. Known: lunge/distortion presenters play on their own players on Master; not captured in the evidence run.
**Steps**:
  1. Host on 30961. Run `--bot=lunge --view=survivor --shots=production/qa/evidence/scare-audio --count=5` first to hear the wind-up with no scare (baseline).
  2. Repeat with scale settings at both extremes: set stinger and scare master scales to 0 and 1 (setting UI/file location: check `src/` for `stinger_scale` / `scare_scale` before the run; if no player-facing setting exists, record it).
  3. Trigger a Blackout scare during the wind-up if the launcher allows (`--bot=stage --scare-audio` does not lunge; combining is likely unsupported, record BLOCKED if so).
  4. Using the bus-peak print (add the bus peak print if running `--scare-audio`; otherwise by ear), compare wind-up level across baseline, scale 0 and scale 1.
**Expected Result**: Wind-up level identical in all runs; no ducking while the scare plays.
**Actual Result**:
**Pass Criteria**: By measurement (Master peak during wind-up, tolerance 1 dB) or, if measurement is not possible, listener cannot hear a difference in three A/B passes. Mark the gap "measured" vs "by ear" explicitly. Pass/Fail: ______

## Test Case: SE8-03 — Transform distortion cue at full level during a scare (AC-1)
**Precondition**: Port 30962. `--bot=stage --disguise` triggers the shapeshifter form change; TransformPresenter distortions are printed with bearing.
**Steps**:
  1. Host on 30962; view `--port=30962 --count=5 --view=survivor --bot=stage --disguise --scare-audio`.
  2. Listen to the transform distortion and compare with a run without `--scare-audio` (baseline).
  3. Note bus peaks of Master during the distortion in both runs.
**Expected Result**: Distortion level unchanged by the overlapping scare.
**Actual Result**:
**Pass Criteria**: Master peak during distortion within 1 dB between runs, or marked BLOCKED if the two cannot overlap. Pass/Fail: ______

## Test Case: SE8-04 — Known gap: stinger cap measurement (AC-2, UNPROVEN)
**Precondition**: Evidence page states AC-2 unproven: stinger bus +4.0 dB in both runs, unducked bed read -4.0 dB in one and -0.4 dB in another (gap +8.0 / +4.4 dB, over the +6 limit in run 1). Peak meter is unreliable for these tones. A LUFS (loudness) measurement of recorded audio settles it. Port 30963.
**Steps**:
  1. Host on 30963. View with movie capture: `"$GODOT" --path . res://tests/manual/round_view.tscn --write-movie production/qa/evidence/scare-audio/audio.avi --fixed-fps 60 --resolution 1280x720 -- --port=30963 --count=5 --view=survivor --bot=stage --scare-audio`
  2. Extract audio (if ffmpeg is installed: `ffmpeg -i production/qa/evidence/scare-audio/audio.avi -vn production/qa/evidence/scare-audio/audio.wav`; else record BLOCKED: no tool).
  3. Measure integrated loudness of (a) the ambient bed alone before the scare, (b) the stinger window (LUFS short-term): `ffmpeg -i audio.wav -af ebur128 -f null -` over the two time ranges.
  4. Repeat 3 times (the meter varied between runs); record all values and the stinger-minus-bed delta.
**Expected Result**: Stinger loudness minus ambient bed loudness is <= +6 dB (`stinger_max_db_rel`) in every run.
**Actual Result**:
**Pass Criteria**: Delta <= 6.0 dB in all 3 runs. If delta is > 6 dB, FAIL and file a bug (System: Scare audio). If it cannot be measured, record BLOCKED and AC-2 remains unproven; the sign-off cannot tick AC-2. Pass/Fail: ______

## Test Case: SE8-05 — Stinger only on Major scares (AC-2)
**Precondition**: Port 30964; ability to deliver a Minor scare. Blackout is Major. The launchers only force Major (`--scare-audio`) or hallucination (`--force=<s>:hallucinate`).
**Steps**:
  1. Run `--scare-audio` as SE8-01: record a Stinger bus peak after the Major scare.
  2. Run host with `--force=5:hallucinate --place=monitor` and the view `--bot=monitor`; read the Stinger bus peak (print buses, or listen).
  3. If a Minor scare can be forced (check the scare catalogue for Minor entries and whether `round_host --force` supports them; it does not list one), run it; otherwise BLOCKED and rely on unit tests ("stinger on every intensity" mutation).
**Expected Result**: Stinger peak non-silent after the Major scare; silent after Minor scares and hallucination.
**Actual Result**:
**Pass Criteria**: Stinger bus silent for every non-Major scare tried; present for Major. Pass/Fail: ______

## Test Case: SE8-06 — Diegetic direction and distance match origin (AC-3)
**Precondition**: Port 30965, headphones. Reference: origin (2.53, 0, 27.51), bearing -7.9 deg, 3.88 m from the camera.
**Steps**:
  1. Run the SE8-01 view/host without `--write-movie` so audio is real time.
  2. Read the printed origin and bearing; note whether the scare sound comes from slightly left of centre (negative bearing).
  3. Repeat with the shown client turned (mouse look; remove `--bot` is not possible with stage, so restart with `--yaw=90` for a 90 deg offset) and confirm the sound moves to the side.
  4. Walk away or take a reading at a longer range if the launcher permits; otherwise note not tested.
**Expected Result**: Sound localises at the printed bearing; louder when closer; stinger is centred (non-positional).
**Actual Result**:
**Pass Criteria**: Tester's left/right/ahead call is correct for 3 of 3 trials with the camera in 3 different yaws. Pass/Fail: ______

## Test Case: SE8-07 — Scale settings change level only, never timing (AC-3)
**Precondition**: Port 30966; knob/setting for `stinger_scale` and `scare_scale` identified (see SE8-02 note).
**Steps**:
  1. Run `--scare-audio` with scales at 1.0; record the printed frame of Stinger onset relative to `ScareTriggered`.
  2. Repeat with both scales at 0.5, and at 0.
  3. Compare onset frames and peaks (Stinger and Scare buses only should change).
**Expected Result**: Onset frame identical across all three; only Stinger/Scare bus level changes; Ambience, GameplayCues unchanged.
**Actual Result**:
**Pass Criteria**: Onset frame offset equal across runs (reference: stinger at +1 frame) and peak scales as set. Pass/Fail: ______

## Test Case: SE8-08 — Stinger vs origin sound ordering (open designer question, rule 17)
**Precondition**: Evidence shows stinger on its bus at +1 frame, origin sound at +2.
**Steps**:
  1. Listen to the scare 5 times with headphones.
  2. Record whether the stinger masks the origin or the origin is audible and distinct.
**Expected Result**: Origin sound is audible and attributable despite the stinger.
**Actual Result**:
**Pass Criteria**: Designer decision recorded: stinger acceptable / needs delay. Not pass/fail on its own; flag result in the evidence page. Pass/Fail: ______

## Test Case: SE8-09 — Playtest note: scares do not mask gameplay cues
**Precondition**: One new-player session (QA plan).
**Steps**:
  1. Run `--bot=stage --scare-audio --stun`; ask the player to name every footstep/taser sound heard during the scare.
**Expected Result**: Player reports footsteps and the stun sound.
**Actual Result**:
**Pass Criteria**: Player identifies both cues. Notes go to `production/session-logs/playtest-sprint-008-scare-audio.md`. Pass/Fail: ______

---

## Sign-off

- [ ] `scare-audio/scare.png` and `duck.png` retained; bus-peak table pasted into `scare-audio-evidence.md`
- [ ] AC-2 proven by loudness measurement (SE8-04) or explicitly deferred
- Designer (audio lead): ______ Date: ______
