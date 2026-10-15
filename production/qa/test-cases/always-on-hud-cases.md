# Manual Test Cases: Always-on HUD (hud-results 002)

**Story**: `production/epics/hud-results/story-002-always-on-hud.md` | **Type**: UI | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/always-on-hud-evidence.md`
**Spec**: design/ux/hud.md H1-H6, Layout Zones, HUD States
**Placeholders**: `$G` = Godot 4.7.2 console exe; run from repo root; use a free port for P; stop the host after each case.

## Test Case: AOH-01 - Exploration element set
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=P --players=5`. View: `$G --path . res://tests/manual/round_view.tscn --windowed --resolution 1920x1080 --fixed-fps 30 --quit-after 600 -- --port=P --count=5 --view=survivor --bot=look --light --shot-at=560 --shots=<dir>` (add `--no-roster` for step 4).
**Steps**:
  1. Start host, then view.
  2. Wait until the phase label reads INFILTRATION (about 19 s).
  3. List every HUD element visible.
  4. Relaunch the view with `--no-roster`; list again.
**Expected Result**: Exactly clock, phase label, roster (4 survivors, icon + word), checklist (Drives, Fuses, Terminal) and centre crosshair dot, plus live markers/feed lines if any. With --no-roster the roster is absent and the rest unchanged.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: AOH-02 - Server-following clock, phase, countdown, roster words
**Precondition**: As AOH-01; host `--force=15:evac` for a phase change.
**Steps**:
  1. Watch the clock for 10 s against the host log.
  2. Observe the phase label change.
  3. Read each roster entry.
  4. Read H3 while the terminal is Activating with nobody holding.
**Expected Result**: Clock and phase follow the server. Roster entries show icon and word ('Healthy'). H3 'Paused' cannot be driven live (no server message): only 'Activating' appears.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: AOH-03 - Margins and text size at three resolutions
**Precondition**: As AOH-01; run at 1920x1080, 2560x1080 and 1920x1200.
**Steps**:
  1. Capture one screenshot per resolution.
  2. Measure roster-left and checklist-right glyph gaps to each edge (21:9: to the 16:9 safe rect, x 320-2240).
  3. At 1080p measure the capital height of 'D' in 'Drives'.
**Expected Result**: >= 48 px from each edge at 16:9 and 16:10 (recorded glyph gaps ~60 px); >= 64 px from the safe rect at 21:9; critical text capital height >= 20 px (recorded 21).
**Actual Result**: 
**Pass/Fail**: 

## Test Case: AOH-04 - Retained screenshots
**Precondition**: `production/qa/evidence/always-on-hud/` exists.
**Steps**:
  1. Open exploration-1920x1080, -2560x1080, -1920x1200 and -roster-off.
  2. Compare content with AOH-01.
**Expected Result**: All PNGs present and show the full HUD.
**Actual Result**: 
**Pass/Fail**: 

