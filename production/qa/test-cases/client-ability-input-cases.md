# Manual Test Cases: Client ability input and S7 preview (monster-abilities 011)

**Story**: `production/epics/monster-abilities/story-011-client-ability-input.md` | **Type**: UI | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/client-ability-input/client-ability-input-evidence.md`
**Spec**: design/gdd/monster-abilities.md; hud.md S7
**Placeholders**: `$G` = Godot 4.7.2 console exe; run from repo root; use a free port for P; stop the host after each case.

## Test Case: CAI-01 - Lunge press reaches the server
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=30762 --players=5`. View: `$G --path . --resolution 1280x720 --write-movie <tmp>/aim.avi --quit-after 900 res://tests/manual/round_view.tscn -- --port=30762 --count=5 --view=monster --bot=aim --shots=<dir>`. Lunge run: port 30763, `--view=survivor --bot=lunge --via-input --quit-after 1500`. (lunge run)
**Steps**:
  1. Let the bot press the lunge action (right mouse).
  2. Watch wind-up/dash in the view and the host log.
**Expected Result**: Host logs a Lunge request; presenter and server state run as with the old bot.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: CAI-02 - False Signal / Blackout preview and release
**Precondition**: Host: `$G --headless --path . -s res://tests/manual/round_host.gd -- --port=30762 --players=5`. View: `$G --path . --resolution 1280x720 --write-movie <tmp>/aim.avi --quit-after 900 res://tests/manual/round_view.tscn -- --port=30762 --count=5 --view=monster --bot=aim --shots=<dir>`. Lunge run: port 30763, `--view=survivor --bot=lunge --via-input --quit-after 1500`. (aim run); for hand play use the lobby-to-round build as shapeshifter.
**Steps**:
  1. Hold False Signal (R): observe snapped ring and 12 m footstep path.
  2. Look at the sky and hold: observe crossed-out preview; release.
  3. Hold Blackout (X): observe volume outline; release.
**Expected Result**: Valid preview while held, request sent at that aim on release; invalid preview crossed out and nothing sent; server accepts/rejects by its rules.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: CAI-03 - Survivor never sends or shows S7
**Precondition**: Same host; `--view=survivor`.
**Steps**:
  1. As a survivor press right mouse, R and X.
  2. Check the host log and the screen.
**Expected Result**: No ability request logged; no S7.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: CAI-04 - Screenshots in the shipped path
**Precondition**: `production/qa/evidence/client-ability-input/` exists; shipped path = lobby then round (two windows + bots as in RES-03).
**Steps**:
  1. Open fs_preview, invalid, bo_preview, bo_dark, windup, dash, hit.
  2. Repeat CAI-01..03 from the real lobby.
**Expected Result**: PNGs present; behaviour matches from the lobby path (evidence was captured via round_view only).
**Actual Result**: 
**Pass/Fail**: 

