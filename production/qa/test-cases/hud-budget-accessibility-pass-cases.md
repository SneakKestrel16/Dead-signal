# Manual Test Cases: HUD budget and accessibility (hud-results 010)

**Story**: `production/epics/hud-results/story-010-hud-budget-accessibility-pass.md` | **Type**: UI | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/hud-budget-accessibility-evidence.md`
**Spec**: design/ux/hud.md budget, colour-blind, reduced motion
**Placeholders**: `$G` = Godot 4.7.2 console exe; run from repo root; use a free port for P; stop the host after each case.

## Test Case: HBA-01 - HUD pixel budget
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=30901 --players=6 --force=15:evac`. View: `$G --path . res://tests/manual/round_view.tscn --windowed --resolution 1920x1080 --write-movie <tmp>/f.avi --fixed-fps 30 --quit-after 3000 -- --port=30901 --count=6 --view=survivor --bot=budget [--reduced-motion] --shots=<dir>`. Measure with `python tools/hud_measure.py`.
**Steps**:
  1. Run; use the `*_hud.png` frames.
  2. Measure covered fraction in exploration and in the busiest state.
**Expected Result**: <= 8% in exploration; <= 12% in the busiest state.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: HBA-02 - Colour-blind distinguishability
**Precondition**: Screenshots from HBA-01.
**Steps**:
  1. Apply protanopia, deuteranopia, tritanopia filters.
  2. Check every roster state, checklist state and ping type.
**Expected Result**: Each distinguishable by shape or word. Item ping square not in a capture (see CONCERNS).
**Actual Result**: 
**Pass/Fail**: 

## Test Case: HBA-03 - Reduced motion and text size
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=30901 --players=6 --force=15:evac`. View: `$G --path . res://tests/manual/round_view.tscn --windowed --resolution 1920x1080 --write-movie <tmp>/f.avi --fixed-fps 30 --quit-after 3000 -- --port=30901 --count=6 --view=survivor --bot=budget [--reduced-motion] --shots=<dir>`. Measure with `python tools/hud_measure.py`. with `--reduced-motion`.
**Steps**:
  1. Run `hud_measure.py motion --rect=...` on consecutive frames for H2, H7, H1 final 30 s.
  2. Measure critical and feed text height at 1080p.
**Expected Result**: 0 changed px on H2, H7, H1 (H7 fade fixed in b024355, BUG-0008; before the fix the prompt faded over 3 frames). Critical text >= 20 px; feed text >= 28 px.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: HBA-04 - Evidence lists every number
**Precondition**: Evidence file open.
**Steps**:
  1. Check each measured figure names its source screenshot.
**Expected Result**: Every number has a source screenshot.
**Actual Result**: 
**Pass/Fail**: 

