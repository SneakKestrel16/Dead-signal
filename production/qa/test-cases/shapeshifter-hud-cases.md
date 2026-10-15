# Manual Test Cases: Shapeshifter HUD (hud-results 006)

**Story**: `production/epics/hud-results/story-006-shapeshifter-hud.md` | **Type**: UI | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/shapeshifter-hud-evidence.md`
**Spec**: design/ux/hud.md S1-S7
**Placeholders**: `$G` = Godot 4.7.2 console exe; run from repo root; use a free port for P; stop the host after each case.

## Test Case: SSH-01 - S1-S3 always, S4-S7 in trigger states
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=30682 --players=5`. View: `$G --path . --resolution 1280x720 --write-movie <tmp>.avi --quit-after 2400 res://tests/manual/round_view.tscn -- --port=30682 --count=5 --view=monster --bot=shifter --shots=<dir>`.
**Steps**:
  1. In true form read S1 face list, S2 form, S3 lunge/False Signal/Blackout.
  2. Watch the transform (S4), disguised (S2 cooldown), stunned (S5).
  3. Compare cooldown numbers with the host log.
**Expected Result**: S1-S3 always shown; S4 only transforming; S5 only stunned; values within 0.1 s of server. S6 install alert not live-reachable (see CONCERNS).
**Actual Result**: 
**Pass/Fail**: 

## Test Case: SSH-02 - Survivor HUD has no S1-S7
**Precondition**: Same host; view with `--view=survivor`; also run `tests/integration/hud-results/shapeshifter_hud_absence_test.gd`.
**Steps**:
  1. Watch each survivor client's HUD through a transform and a lunge.
  2. Run the integration test.
**Expected Result**: No S1-S7 element on any survivor; the tree check passes.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: SSH-03 - Retained screenshots
**Precondition**: `production/qa/evidence/shapeshifter-hud/` exists.
**Steps**:
  1. Open trueform, transforming, disguised.
**Expected Result**: Three PNGs present.
**Actual Result**: 
**Pass/Fail**: 

