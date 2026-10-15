# Manual Test Cases: Gamepad bindings (hud-results 012)

**Story**: `production/epics/hud-results/story-012-gamepad-bindings.md` | **Type**: UI | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/gamepad-bindings-evidence.md`
**Spec**: design/ux/hud.md controls; project.godot input map
**Placeholders**: `$G` = Godot 4.7.2 console exe; run from repo root; use a free port for P; stop the host after each case.

## Test Case: GPB-01 - Binding coverage and glyph device
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=30882 --players=5`. View: `$G --path . res://tests/manual/round_view.tscn --windowed --write-movie <tmp>/f.avi --fixed-fps 30 --quit-after 900 -- --port=30882 --count=5 --view=survivor --bot=hold --pad --shots=<dir>`. Real XInput pad for GPB-02.
**Steps**:
  1. Open Project Settings > Input Map; confirm every gameplay and UI action has a joypad event.
  2. Run the view; read the prompt after `--pad`.
  3. Press a keyboard key; re-read.
**Expected Result**: Every action has a pad binding. Prompt 'Hold X  Hide' after pad input, 'Hold E ...' after key input.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: GPB-02 - Callout wheel on right stick
**Precondition**: Real pad connected; Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=30882 --players=5`. View: `$G --path . res://tests/manual/round_view.tscn --windowed --write-movie <tmp>/f.avi --fixed-fps 30 --quit-after 900 -- --port=30882 --count=5 --view=survivor --bot=hold --shots=<dir>`. Real XInput pad for GPB-02.
**Steps**:
  1. Hold LB (callout_wheel).
  2. Move the right stick through each sector.
  3. Release.
**Expected Result**: Wheel opens on LB and the right stick steers it (no screenshot exists).
**Actual Result**: 
**Pass/Fail**: 

## Test Case: GPB-03 - Retained screenshot
**Precondition**: `production/qa/evidence/gamepad-bindings/` exists.
**Steps**:
  1. Open prompt-pad.png.
**Expected Result**: PNG shows a pad glyph in the prompt.
**Actual Result**: 
**Pass/Fail**: 

