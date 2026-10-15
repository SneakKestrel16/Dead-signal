# Manual test cases: FM-11 surveillance cameras at the C1 monitor

**Story**: `production/epics/facility-map/story-011-surveillance-cameras.md` | **Type**: Visual/Feel | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/surveillance-cameras-evidence.md` (captures 01-11, sign-off open)
**Tester**: designer, Git Bash at the repo root, `G` set as in `client-round-scene-cases.md`.

## Already automated

- Press cycle, relevance and the camera's lighting set: `tests/unit/facility-map/surveillance_test.gd`, `surveillance_feed_test.gd`, `lighting_replication_test.gd::test_a_viewed_cameras_volumes_are_sent_like_visible_ones`.

## Common preconditions

1. `"$G" --headless --path . -s res://tests/manual/round_host.gd -- --port=30241 --players=5 --place=monitor --force=3:power,20:blackout,30:blackout,40:blackout,50:blackout,60:blackout`
2. `"$G" --path . res://tests/manual/round_view.tscn --windowed -- --port=30241 --count=5 --view=monitor --bot=monitor`

---

## Test Case: FM11-01: The four feeds cycle from the level-doc positions, then off

**Steps**:
1. Watch the monitor screen while the bot presses interact: c1, c2, c3, c4, then off.
2. For each feed, check what it covers against the level doc's "Covers" column.

**Expected Result**: c1 shows B1 toward the Core. c2 shows H-S facing east. c3 shows C4 facing south. c4 shows the A2 spine facing south. After the fifth press the screen is hidden. The facings are inferred, so record any feed that frames the wrong area.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: FM11-02: The disguised shapeshifter shows as its disguise on the feed

**Steps**:
1. On c1, before the disguise, find the red body next to the green survivor in B1.
2. Keep watching c1 until the red body becomes green.

**Expected Result**: After the change, the feed shows two identical green bodies. Red never reappears on the feed.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: FM11-03: A feed follows its volume's lighting during a Blackout

**Steps**:
1. Restart both commands with port 30242. Wait until the feed is back on c1 after 20 s (a Blackout in B1).
2. Compare with `09-feed-cam1-b1-blackout.png` and `04-feed-cam1-disguise.png`.

**Expected Result**: On c1, B1's overheads are off and only the red strips are lit. The rooms behind B1 stay lit. The c2 feed (H-S) is lit normally.
**Actual Result**:
**Pass/Fail**:
