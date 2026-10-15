# Manual Test Cases: Lobby Last round (hud-results 009)

**Story**: `production/epics/hud-results/story-009-lobby-last-round.md` | **Type**: UI | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/lobby-last-round/lobby-last-round-evidence.md`
**Spec**: design/ux/results.md Entry & Exit; lobby-role-assignment.md line 222
**Placeholders**: `$G` = Godot 4.7.2 console exe; run from repo root; use a free port for P; stop the host after each case.

## Test Case: LLR-01 - Open and close, focus restored
**Precondition**: `$G --path . --windowed --resolution 1280x720 res://tests/manual/lobby_last_round.tscn -- --lobby-host --lobby-port=30860 --lobby-name=Host --shots=<abs dir>` (shipped LobbyScreen with an injected finished round).
**Steps**:
  1. Find 'Last round' between Ready and Leave.
  2. Activate it.
  3. Read the view.
  4. Press Esc / Back.
**Expected Result**: Opens stored results titled 'Last round', no countdown, no Leave session, Back focused; closing returns to the lobby with focus on 'Last round'.
**Actual Result**: 
**Pass/Fail**: 

## Test Case: LLR-02 - Absent before a round and after host leaves
**Precondition**: Fresh lobby: `$G --path . --windowed -- --lobby-host --lobby-port=30861 --lobby-name=Host`, plus a guest joined.
**Steps**:
  1. Check the room before any round.
  2. After a round, have the host leave; check the guest's room.
**Expected Result**: No 'Last round' button before any round or after the host leaves (host-leave path is unit-tested only).
**Actual Result**: 
**Pass/Fail**: 

## Test Case: LLR-03 - Retained screenshots
**Precondition**: `production/qa/evidence/lobby-last-round/` exists.
**Steps**:
  1. Open lobby.png, view.png, back.png.
**Expected Result**: Three PNGs present.
**Actual Result**: 
**Pass/Fail**: 

