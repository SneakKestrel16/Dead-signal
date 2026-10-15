# Manual Test Cases: SE-9 Scare visuals and flash accessibility

> **Story**: `production/epics/scare-events/story-009-scare-visuals-accessibility.md`
> **Story type**: Visual/Feel | **Output**: this file + `production/qa/evidence/scare-visuals-accessibility/` + `scare-visuals-accessibility-evidence.md` | **Gate**: BLOCKING
> **GDD**: `design/gdd/scare-events.md` rules 24, 25, 27-29; Acceptance Criteria (flash scale 0, 3 flashes/s, Emergency state, hallucination)
> **Sign-off**: designer | **Date written**: 2026-10-15 | **Tester**: ______ | **Build/commit**: ______

## Shared setup

```
GODOT="C:/Users/Ockey/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"
OUT=production/qa/evidence/scare-visuals-accessibility
```

- Emergency host: `"$GODOT" --headless --path . -s res://tests/manual/round_host.gd -- --port=<P> --players=5 --force=3:evac` (Evacuation 3 s after start).
- Strobe view (windowed, movie): `"$GODOT" --path . res://tests/manual/round_view.tscn --write-movie $OUT/<dir>/run.avi --fixed-fps 60 --resolution 1280x720 -- --port=<P> --count=5 --view=survivor --bot=walk --shot-when=strobe --yaw=-17 --pitch=-35 --shots=$OUT/<dir> [--flash-scale=0]`. With `--shot-when=strobe` the log prints `STROBE_ONSET` (drawn frame) on every rising strobe energy: this is the frame-sampled flash count. Saves `strobe.png` and, 30 drawn frames later, `between.png`.
- Hallucination host: `... round_host.gd -- --port=<P> --players=5 --place=monitor --force=15:hallucinate`; view: `... -- --port=<P> --count=5 --view=monitor --bot=monitor --shot-when=hallucination --shots=$OUT/hall`.
- Ports 30970-30979. Use a fresh port per run; read output before trusting. Movie mode renders faster than wall clock: count drawn frames, not seconds.

---

## Test Case: SE9-01 — Flash scale 1 strobe pulses (AC-3 baseline)
**Precondition**: Port 30970 free.
**Steps**:
  1. Start the Emergency host on `--port=30970`.
  2. Start the strobe view with `--port=30970`, output dir `$OUT/framed1`, no `--flash-scale` flag (default 1).
  3. Open `$OUT/framed1/strobe.png` and `between.png`.
**Expected Result**: `strobe.png` shows the red pool under the H-S1 strobe lit; `between.png` (30 frames later) shows it unlit; strips, overheads and pillars readable in both.
**Actual Result**:
**Pass Criteria**: The two images visibly differ in the strobe pool and landmark geometry is identifiable in both. Pass/Fail: ______

## Test Case: SE9-02 — Flash scale 0: no luminance flash, timing unchanged (AC-1)
**Precondition**: Port 30971 free; SE9-01 done for comparison.
**Steps**:
  1. Emergency host on 30971.
  2. Strobe view with `--flash-scale=0 --shots=$OUT/framed0`, `--port=30971`.
  3. Compare `framed0/strobe.png` and `between.png` pixel-wise (e.g. `cmp` or visual flip).
  4. Count `STROBE_ONSET` lines in the log.
  5. Confirm the Emergency transition occurs at the same drawn frame as in SE9-01 (read the first state-change log line in both runs).
**Expected Result**: The two screenshots are identical (steady alarm light, no pulse); exactly one onset in the run (the steady light turning on); timing and origin of scares unchanged vs scale 1.
**Actual Result**:
**Pass Criteria**: Images identical; STROBE_ONSET count = 1; Emergency frame equal to SE9-01 within 0 frames. Pass/Fail: ______

## Test Case: SE9-03 — Never more than 3 flashes per second (AC-2)
**Precondition**: Port 30972; scale 1.
**Steps**:
  1. Emergency host on 30972; strobe view with `--bot=walk --shot-when=strobe`, let it run at least 20 s of drawn time (1200 frames).
  2. Collect all `STROBE_ONSET` drawn-frame numbers.
  3. For each onset frame f, count onsets in [f, f+59] (60 fps). Record the max.
  4. Repeat with a scare flash overlapping: use `--bot=stage --scare-audio` host `--force=3:evac` so a Major scare plus the strobe overlap; count onsets plus screen flashes (screenshot samples) in 60-frame windows.
**Expected Result**: Maximum onsets in any 60-frame window <= 3 (reference run: at most 2, 41 total).
**Actual Result**:
**Pass Criteria**: Max in any 60-frame window <= 3 in both runs. Lighting flicker counts toward the 3: if flicker pulses are visible between onsets, note them. Pass/Fail: ______

## Test Case: SE9-04 — Reduced flash and lighting flicker (AC-2 "counting lighting flicker")
**Precondition**: Port 30973.
**Steps**:
  1. Run SE9-03 view with `--reduced-flash` added.
  2. Compare onset counts to SE9-03.
**Expected Result**: Beacons still; strobe obeys the cap; no more flashes than SE9-03.
**Actual Result**:
**Pass Criteria**: Onsets in any 60 frames <= 3 and <= the SE9-03 count. Pass/Fail: ______

## Test Case: SE9-05 — Emergency state: strobe, landmarks, exit readable (AC-3)
**Precondition**: Port 30974.
**Steps**:
  1. Run SE9-01 and capture additional frames without `--yaw`/`--pitch` (default walking view) with `--shots=$OUT/emergency`.
  2. Inspect: strobe visible, emergency strip lights on, landmarks identifiable, the exit marker readable.
**Expected Result**: Emergency strips stay on in every state; room landmarks and the exit remain identifiable under the strobe. The exit LIGHT is off in all runs so far because no run opened the exit; record this.
**Actual Result**:
**Pass Criteria**: Tester can name three landmarks and locate the exit door in a strobe-lit and unlit frame. Subjective part: if unsure escalate to qa-lead with the screenshot. Pass/Fail: ______

## Test Case: SE9-06 — Known gap: rotating beacons not visible (AC-3)
**Precondition**: Port 30975. Story says the Facility Map `LightingPresenter` beacon spot lights no floor in H-S1 (ceiling height / range clipping).
**Steps**:
  1. Run the SE9-01 setup, then walk to at least two other beacon volumes (use `--bot=walk` for H-S1, plus an interactive run, `--port=30975 --count=5 --view=survivor` without `--bot`, to visit A-zone rooms).
  2. In each, look at the floor and walls for a rotating orange beacon light across a 10 s window; take three screenshots 1 s apart.
**Expected Result**: A rotating orange beacon sweep visible in Emergency.
**Actual Result**:
**Pass Criteria**: Sweep visible in screenshots in at least one beacon volume. Expected current result: FAIL (known gap; Facility Map placement follow-up). Record as FAIL and keep the gap open, do not mark Pass. Pass/Fail: ______

## Test Case: SE9-07 — Exit light in Emergency after the exit opens (AC-3 gap)
**Precondition**: A run where the exit is opened (fuses/terminal powered); no launcher flag opens it (`--force=<s>:power` sets Power Restored only).
**Steps**:
  1. Host with `--force=3:evac,6:power` and view the exit area interactively.
  2. Check the exit light state.
**Expected Result**: Exit light on and readable under the strobe once the exit opens.
**Actual Result**:
**Pass Criteria**: Exit light on in screenshot. If the exit cannot be opened from the launchers, record BLOCKED. Pass/Fail: ______

## Test Case: SE9-08 — Impossible surveillance frame only on the target (AC-3)
**Precondition**: Port 30976; `--place=monitor` puts the first survivor at the C1 monitor.
**Steps**:
  1. `"$GODOT" --headless --path . -s res://tests/manual/round_host.gd -- --port=30976 --players=5 --place=monitor --force=15:hallucinate`
  2. `"$GODOT" --path . res://tests/manual/round_view.tscn --write-movie $OUT/hall/run.avi --fixed-fps 60 --resolution 1280x720 -- --port=30976 --count=5 --view=monitor --bot=monitor --shot-when=hallucination --shots=$OUT/hall`
  3. Open `$OUT/hall/hallucination.png`.
  4. Read the log line printing every client's `hallucinating()` at the shot frame.
**Expected Result**: Red static on the C1 monitor of client 0 only; Client0 true, Clients 1-4 false.
**Actual Result**:
**Pass Criteria**: Screenshot shows the static on client 0; log shows exactly one true. Pass/Fail: ______

## Test Case: SE9-09 — Hallucination on a second monitor viewer is absent (AC-3 negative)
**Precondition**: Port 30977.
**Steps**:
  1. Repeat SE9-08 with `--view=1` (a different client is shown) in place of `--view=monitor`, and the monitor still the C1 monitor.
  2. Screenshot the C1 monitor from client 1's view at the forced time.
**Expected Result**: Client 1's monitor shows the normal feed, not the static.
**Actual Result**:
**Pass Criteria**: No static visible on client 1's feed. Pass/Fail: ______

## Test Case: SE9-10 — Hallucination server trigger (known gap)
**Precondition**: None.
**Steps**:
  1. Note the story: the server trigger (viewing the monitor) is not built; only `round_host --force=<s>:hallucinate` fires it.
**Expected Result**: Not testable yet; the real "view the monitor" trigger fires the same scare (GDD rule 14).
**Actual Result**:
**Pass Criteria**: Recorded BLOCKED until the trigger exists. Pass/Fail: ______

---

## Sign-off

- [ ] `framed1/{strobe,between}.png`, `framed0/{strobe,between}.png`, `hall/hallucination.png` retained
- [ ] SE9-06 and SE9-07 gaps recorded in the evidence page
- Designer: ______ Date: ______
