# Manual test cases: FM-10 lighting replication, render and blackout

**Story**: `production/epics/facility-map/story-010-lighting-render-blackout.md` | **Type**: Visual/Feel | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/lighting-render-evidence.md`
**Tester**: designer, Git Bash at the repo root, `G` set as in `client-round-scene-cases.md`.

## Already automated

- Same-tick delivery to every viewer: `lighting_replication_test.gd::test_evacuation_reaches_every_viewer_in_the_same_tick`.
- One volume dark, strips kept: `lighting_presenter_test.gd::test_blackout_darkens_one_volume_except_emergency_strips`, `test_every_light_stays_inside_its_volume`.
- Reduced-flash variants: `test_evacuation_beacons_use_the_steady_variant_under_reduced_flash`, `test_reduced_flash_alarm_holds_steady`.

---

## Test Case: FM10-01: Low Power, Power Restored and Evacuation read as distinct states on all clients within 1 s

**Preconditions**:
1. `"$G" --headless --path . -s res://tests/manual/round_host.gd -- --port=30231 --players=5 --force=10:power,20:evac`
2. `"$G" --path . res://tests/manual/round_view.tscn --windowed -- --port=30231 --count=5 --view=survivor --yaw=-90 --pitch=-10`

**Steps**:
1. Watch the view for 25 s from round start.
2. Read the `LIGHT` lines for the power tick and the evac tick: the times of clients 0-4.

**Expected Result**: The overhead pools get brighter at about 10 s and drop to about half at about 20 s. The red floor strips glow throughout. For each state, the `LIGHT` times of the 5 clients are within 1000 ms of each other. The scene is readable enough to walk in Low Power. Record any judgement on darkness.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: FM10-02: A Blackout darkens only the shapeshifter's volume and keeps the strips

**Preconditions**: Host on port 30232 (no `--force`). Client: `... --port=30232 --count=5 --view=monster --blackout`

**Steps**:
1. Wait for the Blackout request (the `LIGHT` line with `dark_until`).
2. Look around the own volume (B2), then toward the corridor beyond.

**Expected Result**: In B2, only the red emergency strip stays lit. The corridor beyond keeps its overhead pools and strips.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: FM10-03: Reduced flash shows the steady beacon variant during Evacuation

**Preconditions**: Host on port 30233 with `--force=5:evac`. Client: `... --port=30233 --count=5 --view=survivor --reduced-flash`

**Steps**:
1. After Evacuation, walk (mouse and WASD) into a corridor until a beacon is in view.
2. Watch it for 5 s, then take a screenshot (Win+Shift+S) and save it to `production/qa/evidence/lighting-render/reduced-flash.png`.

**Expected Result**: The beacon glows steadily with no strobe or pulse. No light on screen flashes.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: FM10-04: Frame budget measured

**Preconditions**: Host on port 30234. Client: `... --port=30234 --count=5 --view=survivor --measure` (without `--write-movie`).

**Steps**:
1. Read the printed mean frame time and GPU time. Record them, and the renderer backend, in the evidence page.

**Expected Result**: A number is recorded. The B1 rack lanes and glass partitions do not exist in the greybox yet, so this AC clause stays open until they do.
**Actual Result**:
**Pass/Fail**:
