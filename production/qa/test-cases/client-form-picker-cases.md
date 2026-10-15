# Manual Test Cases: Client form picker (borrowed-face 011)

**Story**: `production/epics/borrowed-face/story-011-client-form-picker.md` | **Type**: UI | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/client-form-picker-evidence.md`
**Spec**: design/gdd/borrowed-face.md; HUD-3 labels
**Placeholders**: `$G` = Godot 4.7.2 console exe; run from repo root; use a free port for P; stop the host after each case.

## Test Case: CFP-01 - Picker contents and choosing
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=30782 --players=5`. View: `$G --path . --resolution 1280x720 --write-movie <tmp>.avi --quit-after 2400 res://tests/manual/round_view.tscn -- --port=30782 --count=5 --view=monster --bot=picker --shots=<dir>`. Hand play: hold T (form_picker).
**Steps**:
  1. Open the picker.
  2. Compare entries and availability with the S1 face list.
  3. Aim at an available form and release T.
**Expected Result**: 'True form (Current)' plus each observed survivor; unavailable ones greyed 'Unavailable'; release sends the request and the server starts the transformation (S4 bar, then S2 form cooldown).
**Actual Result**: 
**Pass/Fail**: 

## Test Case: CFP-02 - Refusal via HUD-3
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=30782 --players=5`. View: `$G --path . --resolution 1280x720 --write-movie <tmp>.avi --quit-after 2400 res://tests/manual/round_view.tscn -- --port=30782 --count=5 --view=monster --bot=picker --shots=<dir>`. Hand play: hold T (form_picker). Request again inside the form cooldown.
**Steps**:
  1. Request True form inside the cooldown.
  2. Read the label under the crosshair.
**Expected Result**: 'Not now' shows; no transformation starts. Stun and mid-lunge refusals are unit-tested only (see CONCERNS).
**Actual Result**: 
**Pass/Fail**: 

## Test Case: CFP-03 - Screenshots
**Precondition**: `production/qa/evidence/client-form-picker/` exists.
**Steps**:
  1. Open picker, disguised, picker-disguised, refused.
**Expected Result**: PNGs present (captured via round_view, not the lobby path).
**Actual Result**: 
**Pass/Fail**: 

