# Manual Test Cases: Edge cues, items, progress (hud-results 005)

**Story**: `production/epics/hud-results/story-005-edge-cues-items-progress.md` | **Type**: UI | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/edge-cues-items-progress-evidence.md`
**Spec**: design/ux/hud.md Z7, Z8, P8, world progress bars
**Placeholders**: `$G` = Godot 4.7.2 console exe; run from repo root; use a free port for P; stop the host after each case.

## Test Case: ECI-01 - Lunge chevron 19 m vs 21 m
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=P --players=5`. View: `$G --path . res://tests/manual/round_view.tscn --windowed --resolution 1152x648 --fixed-fps 30 -- --port=P --count=5 --view=survivor --bot=lunge --shots=<dir>` (port 30660).
**Steps**:
  1. Observe the chevron during wind-up.
  2. Note its direction against the shapeshifter.
  3. Repeat with the survivor ~21 m away (distance is bot-set; see CONCERNS).
**Expected Result**: Chevron at the top edge toward the source at 19 m; absent at 21 m (lunge_cue_radius_m 20).
**Actual Result**: 
**Pass/Fail**: 

## Test Case: ECI-02 - Flinch-off pulse
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=P --players=5`. View: `$G --path . res://tests/manual/round_view.tscn --windowed --resolution 1152x648 --fixed-fps 30 -- --port=P --count=5 --view=survivor --bot=stage --scare-audio --no-flinch --shots=<dir>` (port 30663).
**Steps**:
  1. Trigger the Blackout scare.
  2. Observe the edge toward the origin.
  3. Compare with a run without `--no-flinch`.
**Expected Result**: A soft P8 pulse (150 ms fade-in) shows toward the origin instead of a flinch; server view-offset path unchanged.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: ECI-03 - Taser count and world bar
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=P --players=5`. View: `$G --path . res://tests/manual/round_view.tscn --windowed --resolution 1152x648 --fixed-fps 30 -- --port=P --count=5 --view=survivor --bot=stage --disguise --stun --shots=<dir>` (port 30661); then `--bot=hold --target=drive --fake-paused` (port 30664, synthetic).
**Steps**:
  1. Read 'Taser x N' in Z7 before and after the shot.
  2. Run the fake-paused case; read the world bar.
**Expected Result**: Count 2 -> 1 within one snapshot. Bar reads '[||||......] 40%  Paused' (synthetic data; no live server bar reachable).
**Actual Result**: 
**Pass/Fail**: 

## Test Case: ECI-04 - Retained screenshots
**Precondition**: `production/qa/evidence/edge-cues-items-progress/` exists.
**Steps**:
  1. Open lunge-chevron, transform-arc, taser-after-shot, flinch-off-pulse, world-bar-paused-synthetic.
**Expected Result**: All five PNGs present.
**Actual Result**: 
**Pass/Fail**: 

