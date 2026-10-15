# Manual test cases: MA-7 lunge presentation

**Story**: `production/epics/monster-abilities/story-007-lunge-presentation.md` | **Type**: Visual/Feel | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/lunge-presentation-evidence.md` (sign-off open)
**Tester**: designer with headphones, Git Bash at the repo root, `G` set as in `client-round-scene-cases.md`.

## Already automated

- Cue position, radius and 0.6 s lead: `lunge_presenter_test.gd`, `lunge_cue_test.gd`.
- Miss stumble (not captured): `lunge_presenter_test.gd`.
- Hit-stop is presentation-only (no simulation pause, no input lock): `lunge_presenter_test.gd`.

## Common preconditions

1. `"$G" --headless --path . -s res://tests/manual/round_host.gd -- --port=30261 --players=5`
2. `"$G" --path . res://tests/manual/round_view.tscn --windowed -- --port=30261 --count=5 --view=survivor --bot=lunge`

Run without `--write-movie` so that the cue is heard live. Use a new port (30262, 30263, and so on) for each rerun.

---

## Test Case: MA7-01: Wind-up cue, coil and dash read in order

**Steps**:
1. Watch the red body walk at the view and lunge. Listen for the cue beep.
2. Note the order of cue, coil (squashed body) and dash.

**Expected Result**: The cue is heard and the coil shows together with it. The dash follows about 0.6 s later. The cue comes from the red body's side.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: MA7-02: The hit shows a short hit-stop, and the view stays live

**Steps**:
1. At the hit, watch the frame and move the mouse.

**Expected Result**: A brief freeze of about 80 ms reads as impact. Mouse look still responds during and right after it. The host console logs `SurvivorDowned`.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: MA7-03: A miss stumble is visible

**Steps**:
1. Rerun on a new port until a run prints `STUMBLE seen at frame`. The bot sometimes misses.
2. Watch the red body after the dash.

**Expected Result**: The body tilts forward during the miss slow, then recovers.
**Actual Result**:
**Pass/Fail**:

Limit: the 20 m bearing check needs a listener 20 m away. The bot stages within about 3 m, so the bearing stays covered by the unit tests.
