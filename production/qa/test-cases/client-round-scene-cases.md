# Manual test cases: MF-11 client round scene

**Story**: `production/epics/match-flow/story-011-client-round-scene.md` | **Type**: Integration | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/client-round-scene-evidence.md`, `predicted-hold-bar-evidence.md`
**Tester**: designer, one Windows PC, Git Bash at the repo root.

## Common setup

```bash
G="C:/Users/Ockey/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"
cd C:/Users/Ockey/dead-signal
```

The host runs until its round ends. Close it (Ctrl+C) after each case. Ports 30000-30999 only.

## Already automated

- Join, prediction and remote-body handling over real ENet: `tests/integration/match-flow/client_round_scene_test.gd`.
- Bar on the press tick under 150 ms: `test_bar_appears_on_the_press_tick_under_150ms_latency`. The 240 fps capture result is recorded in `predicted-hold-bar-evidence.md`. MF11-03 rechecks it by eye.

---

## Test Case: MF11-01: A human drives the predicted view with mouse and WASD

**Preconditions**:
1. `"$G" --headless --path . -s res://tests/manual/round_host.gd -- --port=30201 --players=5`
2. `"$G" --path . res://tests/manual/round_view.tscn --windowed -- --port=30201 --count=5 --view=survivor`

**Steps**:
1. Wait for the round to start. The greybox floor should appear.
2. Move the mouse left, right, up and down.
3. Hold W, then A, S and D, about 1 s each.
4. Walk until another survivor's capsule is in view. Watch it for 5 s.
5. Press F twice.

**Expected Result**: The view turns with the mouse at once. WASD moves the camera without rubber-banding or snapping back. The other survivors are coloured capsules that move smoothly, with no teleporting. F turns the own flashlight cone on and then off.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: MF11-02: The monster view shows the round and draws no hidden survivor

**Preconditions**: Same host on port 30202. Client: `"$G" --path . res://tests/manual/round_view.tscn --windowed -- --port=30202 --count=5 --view=monster`

**Steps**:
1. Look around the spawn for 10 s, then walk to a survivor capsule.
2. Compare with `production/qa/evidence/client-round-scene/monster-view.png`.

**Expected Result**: The greybox floor is drawn, with the brown door posts and the blue interactable posts. Survivors appear only when the server's scope includes them. No body flickers in and out at the edge of the screen.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: MF11-03: Under 150 ms latency, the hold bar appears on the press and fills when the server accepts

**Preconditions**: Host on port 30203. Client: `"$G" --path . res://tests/manual/round_view.tscn --windowed --quit-after 3000 -- --port=30203 --count=5 --view=0 --bot=hold --light --latency-ms=150` (the UdpLink uses port 30303).

**Steps**:
1. Watch the view centre while the bot walks to the hiding spot and holds interact.
2. Read the console lines `PRESS`, `BAR`, `SERVER HOLD` and `BAR FULL`.

**Expected Result**: The bar appears under the view centre with no visible delay after the press. `BAR` comes 1-4 frames after `PRESS`, `SERVER HOLD` is printed, and the bar stays visible and reaches full (`BAR FULL`).
**Actual Result**:
**Pass/Fail**:

---

## Test Case: MF11-04: A flashlight cone shows on another client

**Preconditions**: Host on port 30204. Client: `"$G" --path . res://tests/manual/round_view.tscn --windowed -- --port=30204 --count=5 --view=survivor --bot=look --light`

**Steps**:
1. Wait until the view faces the nearest survivor.
2. Compare with `client-round-scene/survivor-view.png`.

**Expected Result**: The own flashlight cone lights the nearest body. The bodies are drawn in their appearance colours.
**Actual Result**:
**Pass/Fail**:

Limit: the remote cone of another *player* toggling is shown only by the integration test. No harness bot toggles a remote client's light while it is in view.
