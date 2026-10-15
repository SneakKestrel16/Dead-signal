# Manual test cases: BF-10 transformation warp and distortion audio

**Story**: `production/epics/borrowed-face/story-010-transform-warp-audio.md` | **Type**: Visual/Feel | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/transform-warp-audio-evidence.md` (sign-off and listening test open)
**Tester**: designer with stereo headphones, Git Bash at the repo root, `G` set as in `client-round-scene-cases.md`.

## Already automated

- 15 m sent, 20 m not sent, player placed at the event with `max_distance` = radius: `tests/unit/borrowed-face/transform_warp_audio_test.gd`.
- Overlay leaves when Transforming clears and restarts on a new transformation: the same file.

Do **not** use `--write-movie` in BF10-01. The movie writer captures the audio to file, so you would hear nothing live.

---

## Test Case: BF10-01: The distortion pans from the shapeshifter's bearing (listening test)

**Preconditions**:
1. `"$G" --headless --path . -s res://tests/manual/round_host.gd -- --port=30221 --players=5`
2. `"$G" --path . res://tests/manual/round_view.tscn --windowed -- --port=30221 --count=5 --view=survivor --bot=stage --disguise`
3. Headphones on, Windows spatial sound off.

**Steps**:
1. When the line forms, note which side of the screen centre the red body (second from left) stands on.
2. Listen for the 140 Hz wobbling tone when it starts to transform.
3. Read the console line `DISTORTION ... bearing <b> deg, true bearing <t> deg`.

**Expected Result**: The tone is heard, and it leans toward the side the red body is on, not centred and not from the other side. |b - t| ≤ 15°.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: BF10-02: The warp covers the whole Transforming state on the transforming body only

**Preconditions**: Host on port 30222. Client as in BF10-01 (port 30222).

**Steps**:
1. Watch the red body from the start of the transformation until it shows the new colour.
2. Compare with `transform-warp-audio/01-warp-early.png`, `02-warp-late.png` and `03-after-transform-no-warp.png`.
3. Judge the strength. The GDD asks for a "subtle" warp (rule 8).

**Expected Result**: The shimmer starts when the transformation starts and stays on without gaps until the new form shows, then it is gone. No other body shimmers. Record whether the strength reads as subtle or needs retuning. That ruling is the lead sign-off.
**Actual Result**:
**Pass/Fail**:

Limit: no live check of a 20 m listener, because every staged client stands within about 5 m. That case is covered by the unit test.
