# Manual test cases: FM-12 zone ambience

**Story**: `production/epics/facility-map/story-012-zone-ambience.md` | **Type**: Visual/Feel (audio) | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/zone-ambience-evidence.md` (sign-off open: a live listen)
**Tester**: designer with headphones, Git Bash at the repo root, `G` set as in `client-round-scene-cases.md`. Do not use `--write-movie`, which captures the audio to file instead of playing it.

## Already automated

- B3 masked footstep radius (AC2): `tests/unit/facility-map/zone_ambience_test.gd::test_listener_just_outside_the_masked_radius_hears_a_walk_in_b3_only_elsewhere`.

---

## Test Case: FM12-01: Each zone has its own bed, and the crossfade at the A1 / H-S1 border is smooth

**Preconditions**:
1. `"$G" --headless --path . -s res://tests/manual/round_host.gd -- --port=30251 --players=4`
2. `"$G" --path . res://tests/manual/round_view.tscn --windowed -- --port=30251 --count=4 --view=survivor --bot=walk`

**Steps**:
1. Listen at the A1 spawn. The overlay should show `zone A`.
2. Keep listening while the bot walks through the archway into H-S1.
3. Listen for 3 s after the border, until the overlay reads `A -inf dB`.

**Expected Result**: The A bed (110 Hz) is steady at the spawn. At the border the link bed (55 Hz) fades in while A fades out over about 1.5 s, with no click, gap or jump in loudness. After that only the link bed plays.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: FM12-02: The B and C zone beds are distinct (free walk)

**Preconditions**: Host on port 30252. Client: `... --port=30252 --count=4 --view=survivor` (no bot, WASD).

**Steps**:
1. Walk from A into a B-zone room, then into a C-zone room. Watch the overlay's zone name.

**Expected Result**: Each zone change brings a different tone: B 70 Hz, C 220 Hz. Each crossfade is as smooth as in FM12-01.
**Actual Result**:
**Pass/Fail**:

The beds are placeholder sines. This pass judges the switching and the crossfade, not the sound design.
