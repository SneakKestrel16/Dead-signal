# Manual Test Cases: Prompt, hold ring, reject (hud-results 003)

**Story**: `production/epics/hud-results/story-003-prompt-hold-ring-reject.md` | **Type**: UI | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/prompt-hold-ring-reject-evidence.md`
**Spec**: design/ux/hud.md H7, H8, HUD-3 labels, Z4/Z5
**Placeholders**: `$G` = Godot 4.7.2 console exe; run from repo root; use a free port for P; stop the host after each case.

## Test Case: PHR-01 - Prompt and glyph device switch
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=P --players=5`. View: `$G --path . res://tests/manual/round_view.tscn --windowed --resolution 1152x648 --fixed-fps 30 --quit-after 900 -- --port=P --count=5 --view=survivor --bot=hold --target=fuse_box --shots=<dir>`.
**Steps**:
  1. Start host, then view.
  2. Wait until the bot's view ray picks the fuse box; read the prompt.
  3. Run again with `--pad`; read the glyph.
  4. Press a keyboard key; re-read.
**Expected Result**: Prompt shows verb + object + glyph + Hold/Press ('Hold E  Install fuse'). Glyph changes key <-> pad without restart ('Hold X' on pad).
**Actual Result**: 
**Pass/Fail**: 

## Test Case: PHR-02 - Hold ring and cancel cause
**Precondition**: As PHR-01 with `--release-at=0.5` and a hiding-spot target (port 30641 in evidence).
**Steps**:
  1. Observe the ring while held.
  2. Watch the bot release at half.
  3. Read the cause text and time it with `--write-movie`.
**Expected Result**: Ring follows the predicted hold and server echo; on release it breaks into segments and 'Released' shows. Break lasts 200 ms; cause label lasts 1 s (story says 200 ms - see CONCERNS).
**Actual Result**: 
**Pass/Fail**: 

## Test Case: PHR-03 - Refusal label and single Z4 element
**Precondition**: As PHR-01 (survivor holds no fuse).
**Steps**:
  1. Let the bot press Start on the fuse box.
  2. Time the Z5 label.
  3. While the ring is up, check whether the prompt also shows.
**Expected Result**: 'Not now' shows about 1.5 s then clears. Only one of prompt / ring / bleed-out / transforming bar is visible in Z4.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: PHR-04 - Retained screenshots
**Precondition**: `production/qa/evidence/prompt-hold-ring-reject/` exists.
**Steps**:
  1. Open 01-prompt, 02-ring, 03-cancel-released, 04-refusal.
**Expected Result**: All four PNGs present and match PHR-01..03.
**Actual Result**: 
**Pass/Fail**: 

