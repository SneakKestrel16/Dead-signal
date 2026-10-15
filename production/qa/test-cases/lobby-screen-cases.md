# Manual test cases: LB-5 lobby screen

**Story**: `production/epics/lobby-role-assignment/story-005-lobby-screen.md` | **Type**: UI | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/lobby-screen-evidence.md` (screenshots 01-06, sign-off open)
**Tester**: designer, Git Bash at the repo root, `G` set as in `client-round-scene-cases.md`.

## Already automated

- Values displayed from `LobbySync` only, and the client sends only the Ready request: `tests/unit/lobby/lobby_screen_test.gd`.

Launch each instance in its own terminal: `"$G" --path . res://src/main.tscn --windowed --resolution 1280x720`

---

## Test Case: LB5-01: A join on a non-default port appears on every peer

**Preconditions**: Three instances running.

**Steps**:
1. Instance 1: name `Ann`, port `30291`, press Host.
2. Instance 2: name `Bob`, host `127.0.0.1`, port `30291`, press Join.
3. Instance 3: name `Cy`, the same address and port, press Join.

**Expected Result**: All three lists show Ann, Bob and Cy. Only Ann's view has Kick buttons and an enabled proximity-voice toggle. On Bob and Cy the toggle is disabled and there is no Kick.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: LB5-02: Ready and the countdown follow server state

**Preconditions**: LB5-01 done. Start a fourth instance and join as `Dee` on port 30291.

**Steps**:
1. Press Ready on all four.
2. Watch the countdown on a client, then let it reach 0.
3. On a new run, press Ready on one client only.

**Expected Result**: Step 2: every peer shows "Starting in N", counting down together, then "Starting". The round start is not wired yet (a known deviation). Step 3: no countdown starts anywhere.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: LB5-03: A rejected join shows its reason

**Preconditions**: A host on port 30292.

**Steps**:
1. On another instance, enter the 17-character name `ABCDEFGHIJKLMNOPQ` and press Join on port 30292.

**Expected Result**: The join form stays up and shows readable reason text for the bad name.
**Actual Result**:
**Pass/Fail**:
