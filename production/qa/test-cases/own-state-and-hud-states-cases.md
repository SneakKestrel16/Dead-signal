# Manual Test Cases: Own state and HUD states (hud-results 004)

**Story**: `production/epics/hud-results/story-004-own-state-and-hud-states.md` | **Type**: UI | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/own-state-and-hud-states-evidence.md`
**Spec**: design/ux/hud.md HUD States table, P11 vignette
**Placeholders**: `$G` = Godot 4.7.2 console exe; run from repo root; use a free port for P; stop the host after each case.

## Test Case: OSH-01 - Downed
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=30746 --players=5`. View: `$G --path . --resolution 1280x720 --quit-after 20000 res://tests/manual/round_view.tscn -- --port=30746 --count=5 --view=survivor --bot=ownstate --shots=<dir>` (real time; includes the 60 s bleed-out).
**Steps**:
  1. Wait for bot step 3 (Downed).
  2. Inspect edges, word, crosshair, Z4, roster, checklist.
**Expected Result**: Wide grey vignette and 'Downed'; crosshair hidden; own bleed-out seconds ('60 s') in the prompt's place; roster and checklist remain.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: OSH-02 - Seized, shocked, hidden
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=30746 --players=5`. View: `$G --path . --resolution 1280x720 --quit-after 20000 res://tests/manual/round_view.tscn -- --port=30746 --count=5 --view=survivor --bot=ownstate --shots=<dir>` (real time; includes the 60 s bleed-out).
**Steps**:
  1. Observe Hidden (step 0) and Seized (step 2).
  2. Shocked is not reached by the bot (see CONCERNS).
  3. Time each transition on a movie, then rerun with `--reduced-motion`.
**Expected Result**: Each state shows only its table row (Hidden: crosshair hidden, 'Hold E  Leave'; Seized: tight dark edges + 'Seized', no prompt/ring, crosshair stays). 250 ms transition; a cut with reduced motion.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: OSH-03 - Spectating
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=30746 --players=5`. View: `$G --path . --resolution 1280x720 --quit-after 20000 res://tests/manual/round_view.tscn -- --port=30746 --count=5 --view=survivor --bot=ownstate --shots=<dir>` (real time; includes the 60 s bleed-out).
**Steps**:
  1. Wait for bot step 4.
  2. Check roster, clock, objectives, watched survivor's view.
  3. Press the callout wheel / ping input.
**Expected Result**: Roster, clock, objectives and 'Spectating: <name>' with the watched survivor's feed/markers; wheel does not open; no ping sent.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: OSH-04 - Retained screenshots
**Precondition**: `production/qa/evidence/own-state-and-hud-states/` exists.
**Steps**:
  1. Open hidden, seized, downed, spectating.
**Expected Result**: All four PNGs present.
**Actual Result**: 
**Pass/Fail**: 

