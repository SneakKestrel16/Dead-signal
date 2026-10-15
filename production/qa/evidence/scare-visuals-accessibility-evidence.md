# Test Evidence: Scare visuals and flash accessibility

> **Story**: `production/epics/scare-events/story-009-scare-visuals-accessibility.md`
> **Story Type**: Visual/Feel
> **Date**: 2026-10-15
> **Tester**: technical-artist agent (automated capture); lead sign-off pending
> **Build / Commit**: wt-se9, code commit 7fcce3d plus the evidence commit after it

---

## What Was Tested

`ScareVisuals` (src/feature/scare_events/scare_visuals.gd): the Emergency strobe alarm at the beacon fixtures,
pulsed through `ScarePresenter.try_flash()` (one shared FlashLimiter; flash scale applied at render), a steady
alarm light and reduced-flash (still) beacons at flash scale 0, emergency strips left on, and the impossible
surveillance frame (catalogue `surveillance_image`, single-client) on the C1 monitor of the recipient only.

**Acceptance criteria covered**: AC-1, AC-2, AC-3

---

## Acceptance Criteria Results

| # | Criterion (from story) | Result | Notes |
|---|----------------------|--------|-------|
| AC-1 | With flash scale 0, no scare produces a luminance flash; scare timing and origin are unchanged. | PASS | Unit test `test_scale_zero_gives_no_luminance_flash`: 300 frames in Emergency with a flash scare every 0.25 s; flash alpha stays 0, strobe energy constant, beacons still, each scare's dim starts on its own frame. Capture at `--flash-scale=0`: one strobe onset in the whole run (the steady light turning on at Emergency), energy 1.50 in both shots. |
| AC-2 | No scare produces more than 3 flashes per second, counting lighting flicker. | PASS | Unit test `test_never_more_than_the_cap_per_second_counting_the_strobe`: strobe forced to 3 Hz plus a scare flash every 0.1 s for 10 s, frame-sampled onsets of both; never more than 3 in any one-second window. Capture at scale 1 (60 fps fixed, `STROBE_ONSET` log): 41 onsets, at most 2 in any 60 drawn frames. |
| AC-3 | Emergency state shows the strobe alarm and rotating beacons with landmarks and the exit still readable; the impossible surveillance frame appears only on the target client's monitor feed. | PASS (beacon gap noted) | Strobe: framed1/strobe.png (lit, red pool under the H-S1 strobe) vs framed1/between.png (30 frames later, unlit) visibly differ; strips, overheads and pillars stay readable in both. Hallucination: hall/hallucination.png; log shows Client0 true, Clients 1-4 false at that frame; unit test `test_impossible_frame_only_on_the_target_feed` uses the real server projection. Beacons: the Facility Map's orange beacon spot is not visible in any frame (see Observations). Exit light off (exit not opened in these runs).

---

## Screenshots / Video

| # | Filename | What It Shows | Acceptance Criterion |
|---|----------|--------------|----------------------|
| 1a | `scare-visuals-accessibility/framed1/strobe.png` | H-S1 floor under the strobe, scale 1, lit frame | AC-2, AC-3 |
| 1b | `scare-visuals-accessibility/framed1/between.png` | Same framing 30 frames later, strobe off | AC-3 |
| 1c | `scare-visuals-accessibility/framed0/strobe.png` | Same framing at flash scale 0: steady alarm light | AC-1 |
| 1d | `scare-visuals-accessibility/framed0/between.png` | 30 frames later, identical (no flash) | AC-1 |
| 1 | `scare-visuals-accessibility/scale1/strobe.png` | H-S1 in Emergency at scale 1, frame of a strobe onset (first run, strobe at the ceiling: not in shot, superseded by 1a) | AC-3 |
| 2 | `scare-visuals-accessibility/scale1/between.png` | Same view 30 frames later, strobe off; strips and overheads readable | AC-3 |
| 3 | `scare-visuals-accessibility/scale0/strobe.png` | Same spot at flash scale 0: steady alarm, no flash | AC-1 |
| 4 | `scare-visuals-accessibility/scale0/between.png` | 30 frames later, identical | AC-1 |
| 5 | `scare-visuals-accessibility/hall/hallucination.png` | Target client at the C1 monitor: red static frame instead of the feed | AC-3 |

Other files in `scale0/`, `scale1/` (zone_a, crossfade, link) are the walk bot's own ambience shots.

---

## Test Conditions

- **Game state at start**: `round_host --players=5 --force=3:evac` (ports 30911, 30912); hallucination run
  `round_host --place=monitor --force=15:hallucinate` (port 30913).
- **Platform / hardware**: Windows 11, windowed Godot 4.7.2, `--write-movie --fixed-fps 60 --resolution 1280x720`
- **Framerate during test**: fixed 60 fps (movie writer)
- **Any special setup required**: `round_view --count=5 --view=survivor --bot=walk --shot-when=strobe
  [--flash-scale=0]`; `round_view --count=5 --view=monitor --bot=monitor --shot-when=hallucination`.

---

## Observations

- First run: the strobe lit nothing. At the ceiling its range (clipped to half the volume width, 2 m in H-S1)
  does not reach a floor 2.9 m below. The strobe now sits at mid-height under the beacon (inference; Facility Map
  alarm-fixture placement settles it), framed runs `--yaw=-17 --pitch=-35`, 26 onsets at scale 1, 1 at scale 0.
- The Facility Map beacon spot (LightingPresenter) has the same ceiling-height/range problem and lights no
  floor in H-S1, so rotating beacons do not show on screen. Facility Map's fix, not changed here.
- The hallucination image is a greybox placeholder (red static); the art pass owns the real image.
- HALLUCINATION_S (0.4 s) and STROBE_ON_S (0.08 s) are inferences, no source gives them.

---

## Sign-Off

| Role | Name | Date | Signature |
|---|---|---|---|
| Lead (art-director / designer) | | | [ ] Approved |
