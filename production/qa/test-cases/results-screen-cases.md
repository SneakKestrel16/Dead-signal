# Manual Test Cases: Results screen (hud-results 008)

**Story**: `production/epics/hud-results/story-008-results-screen.md` | **Type**: UI | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/results-screen-evidence.md`
**Spec**: design/ux/results.md R1-R9, P29
**Placeholders**: `$G` = Godot 4.7.2 console exe; run from repo root; use a free port for P; stop the host after each case.

## Test Case: RES-01 - Payload shown field for field
**Precondition**: Fixture: `$G --path . --windowed --resolution 1920x1080 res://tests/manual/results_view.tscn -- --shot=<png> [--payload=shapeshifter|missing|corrupt] [--ui-scale=1.5] [--focus=N] [--leave]`.
**Steps**:
  1. Open default and `--payload=shapeshifter`.
  2. Compare outcome, fates, causes, downs, rescues, stuns, shapeshifter row, team and monster stats with `tests/unit/hud-results/results_fixtures.gd`.
**Expected Result**: Every field matches; outcome banner correct for each.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: RES-02 - Missing group and unknown player
**Precondition**: Fixture: `$G --path . --windowed --resolution 1920x1080 res://tests/manual/results_view.tscn -- --shot=<png> [--payload=shapeshifter|missing|corrupt] [--ui-scale=1.5] [--focus=N] [--leave]`. `--payload=missing`.
**Steps**:
  1. Read the stun figures.
  2. Check a survivor with an empty name (unit-test forced; not in the fixture shot).
**Expected Result**: Stats in `missing` read 'Results unavailable' (never 0); empty name reads 'Unknown player'.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: RES-03 - Focus order, Leave confirm, return
**Precondition**: Fixture: `$G --path . --windowed --resolution 1920x1080 res://tests/manual/results_view.tscn -- --shot=<png> [--payload=shapeshifter|missing|corrupt] [--ui-scale=1.5] [--focus=N] [--leave]`. Live path: host `$G --path . --windowed --resolution 1280x720 -- --lobby-host --lobby-port=30722 --lobby-name=Host --lobby-ready`; guest same with `--lobby-join=127.0.0.1 --lobby-port=30722 --lobby-name=Guest --lobby-ready`; two `--headless` joiners Bot1, Bot2 (round runs to the 540 s deadline).
**Steps**:
  1. Tab / D-pad through every focus stop; compare with the spec order.
  2. Activate Leave session.
  3. Wait results_duration_s (20 s) with no input.
**Expected Result**: Every stop reachable by keyboard and pad in order; 'Leave this session?' opens with Stay focused; clients return to the lobby unattended.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: RES-04 - Timing and screenshots
**Precondition**: Live path: host `$G --path . --windowed --resolution 1280x720 -- --lobby-host --lobby-port=30722 --lobby-name=Host --lobby-ready`; guest same with `--lobby-join=127.0.0.1 --lobby-port=30722 --lobby-name=Guest --lobby-ready`; two `--headless` joiners Bot1, Bot2 (round runs to the 540 s deadline).
**Steps**:
  1. Record the run with a movie; measure RoundEnded to first results frame.
  2. Compare the five clients' open times.
  3. Check survivors-win, shapeshifter-win, missing-defense PNGs under `production/qa/evidence/results-screen/`.
**Expected Result**: <= 100 ms to open; five clients within 500 ms (no measured number exists - see CONCERNS); PNGs present.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: RES-05 - 150% scale and corrupt payload
**Precondition**: Fixture: `$G --path . --windowed --resolution 1920x1080 res://tests/manual/results_view.tscn -- --shot=<png> [--payload=shapeshifter|missing|corrupt] [--ui-scale=1.5] [--focus=N] [--leave]`.
**Steps**:
  1. Run with `--ui-scale=1.5`; measure body text and look for clipping.
  2. Run with `--payload=corrupt`.
**Expected Result**: Body text >= 24 px (36 px recorded), nothing clipped (scroll used). Corrupt fields show 'Results unavailable'; no crash.
**Actual Result**: 
**Pass/Fail**: 

