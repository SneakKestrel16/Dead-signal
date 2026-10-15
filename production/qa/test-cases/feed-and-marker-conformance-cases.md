# Manual Test Cases: Feed and marker conformance (hud-results 007)

**Story**: `production/epics/hud-results/story-007-feed-and-marker-conformance.md` | **Type**: UI | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/feed-and-marker-conformance-evidence.md`
**Spec**: design/ux/hud.md feed and markers; ping-callout design
**Placeholders**: `$G` = Godot 4.7.2 console exe; run from repo root; use a free port for P; stop the host after each case.

## Test Case: FMC-01 - Five callouts in one second
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=P --players=6`. View: `$G --path . res://tests/manual/round_view.tscn --windowed --resolution 1920x1080 --write-movie <tmp>/f.avi --fixed-fps 30 -- --port=P --count=6 --view=survivor --bot=conform --shots=<dir>` (also at 2560x1080).
**Steps**:
  1. Let the five survivors send callouts in one drawn frame.
  2. Read the feed.
  3. Hold `feed_scrollback`.
  4. Measure the box contrast.
**Expected Result**: Four lines visible in order, first in scrollback (all five in order while held); opaque box at >= 7:1.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: FMC-02 - Six-marker cap, shapes, labels
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=P --players=6`. View: `$G --path . res://tests/manual/round_view.tscn --windowed --resolution 1920x1080 --write-movie <tmp>/f.avi --fixed-fps 30 -- --port=P --count=6 --view=survivor --bot=conform --shots=<dir>` (also at 2560x1080).
**Steps**:
  1. After each survivor pings twice (10 pings) count markers.
  2. Compare shapes per ping type.
  3. Measure label height.
**Expected Result**: At most 6 markers, newest kept; one shape per type (item square not live-captured); labels >= 20 px.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: FMC-03 - Wheel stick and 21:9 margin
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=P --players=6`. View: `$G --path . res://tests/manual/round_view.tscn --windowed --resolution 1920x1080 --write-movie <tmp>/f.avi --fixed-fps 30 -- --port=P --count=6 --view=survivor --bot=conform --shots=<dir>` (also at 2560x1080). A gamepad is connected.
**Steps**:
  1. Run at 2560x1080.
  2. Open the wheel (LB) and steer with the right stick.
  3. Measure leftmost feed ink against x 320.
**Expected Result**: Right stick steers the wheel; feed >= 64 px inside the 16:9 safe rect.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: FMC-04 - Retained screenshots
**Precondition**: `production/qa/evidence/feed-and-marker-conformance/` exists.
**Steps**:
  1. Open feed.png, markers.png, scrollback.png and wide/*.
**Expected Result**: All present; feed shows 4 lines on one box; markers show 6.
**Actual Result**: 
**Pass/Fail**: 

