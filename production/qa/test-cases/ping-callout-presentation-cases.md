# Manual Test Cases: PC-8 Ping and callout presentation

> **Story**: `production/epics/pings-and-callouts/story-008-ping-callout-presentation.md`
> **Story type**: UI | **Output**: this file + retained screenshots in `production/qa/evidence/ping-callout-presentation/` | **Gate**: BLOCKING
> **GDD**: `design/gdd/pings-and-callouts.md` (rules 2, 10, 12, 28; Acceptance Criteria); **Sign-off**: designer
> **Date written**: 2026-10-15 | **Tester**: ______ | **Build/commit**: ______

## Shared setup

Shell: Git Bash, repo root `C:\Users\Ockey\dead-signal`. Define once per shell:

```
GODOT="C:/Users/Ockey/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"
```

- Host (terminal 1): `"$GODOT" --headless --path . -s res://tests/manual/round_host.gd -- --port=<P> --players=5`
- View (terminal 2, windowed, movie mode): `"$GODOT" --path . res://tests/manual/round_view.tscn --write-movie production/qa/evidence/ping-callout-presentation/run.avi --fixed-fps 60 --resolution 1280x720 -- --port=<P> --count=5 --view=survivor --bot=ping --shots=production/qa/evidence/ping-callout-presentation`
- Ports 30000-30999 only; use a fresh port per run (this file uses 30940-30949). Read the host and view output before trusting a run (a stale process holding the port fails silently). Do not kill a process you did not start.
- Interactive runs (PC8-06, PC8-09) omit `--bot` and `--write-movie`; mouse look and WASD drive the shown client. Bindings: ping = middle mouse, callout wheel = Q (hold).
- Note: the bot run produces `pending.png`, `markers.png`, `toofast.png`, `wheel.png`. Names are character ids (C1-C5), not display names (CharacterDef has no display name; known deviation, not a failure).

---

## Test Case: PC8-01 — Pending marker on press (AC-1)
**Precondition**: Host running on 30940 with 5 players; view started with `--bot=ping`; run reaches the shown survivor's first ping.
**Steps**:
  1. Start host: `"$GODOT" --headless --path . -s res://tests/manual/round_host.gd -- --port=30940 --players=5`
  2. Start view with `--port=30940` (command in Shared setup).
  3. Open `pending.png` (saved on the press frame).
**Expected Result**: A dimmed (about half alpha) marker owned by the shown survivor is drawn at the pinged point on the very frame of the press, before any server reply.
**Actual Result**:
**Pass Criteria**: `pending.png` shows the dimmed own marker; it is visible on the press frame (not a later frame). Pass/Fail: ______

## Test Case: PC8-02 — Pending becomes the server marker on acceptance (AC-1)
**Precondition**: PC8-01 run complete.
**Steps**:
  1. Open `markers.png` from the same run.
  2. Find the shown survivor's own marker.
**Expected Result**: The own marker is full alpha (the server's marker), not dimmed, and no duplicate pending marker sits beside it.
**Actual Result**:
**Pass Criteria**: Own marker is full alpha and appears once per accepted ping. Pass/Fail: ______

## Test Case: PC8-03 — Rejection removes pending and shows "Too fast" (AC-1)
**Precondition**: Same run; the bot spams 8 pings past the bucket (3 tokens).
**Steps**:
  1. Open `toofast.png`.
  2. In the view terminal output, count rejections for the shown client.
  3. If rejections < 8 minus accepted, and pendings remain at quit, repeat with a longer run (bot unchanged; hold the run open longer or re-run twice) and record counts. See PC8-04.
**Expected Result**: "Too fast" appears under the crosshair for about 1.5 s after a rejection; the rejected ping's pending marker is gone.
**Actual Result**:
**Pass Criteria**: `toofast.png` shows the tick, and no pending marker remains for a rejected ping. Pass/Fail: ______

## Test Case: PC8-04 — Known gap: rapid pings leave pending markers (open question)
**Precondition**: Interactive run on port 30941 (no `--bot`, no `--write-movie`), view as in Shared setup with `--port=30941 --count=5 --view=survivor`.
**Steps**:
  1. Press middle mouse 8+ times within 1 s, then stop and wait 5 s without quitting.
  2. Count markers still dimmed (pending) and "Too fast" ticks seen.
  3. Wait 15 s more and look again.
**Expected Result**: After replies settle, no pending marker remains: each press is either a full-alpha marker or removed with a tick. (Evidence run quit with 1 rejection and 5 pending; the story infers replies were in flight. A pending marker that never resolves confirms the story-004 no-echo gap.)
**Actual Result**:
**Pass Criteria**: Zero dimmed pending markers 5 s after the last press. A stuck pending marker = FAIL; file a bug (System: Pings & Callouts). Pass/Fail: ______

## Test Case: PC8-05 — Markers through walls with name, colour, direction, distance (AC-2)
**Precondition**: Bot run on port 30942 with a wall between the shown survivor and at least one pinging teammate.
**Steps**:
  1. Run host and view on `--port=30942`.
  2. Open `markers.png`.
  3. For each marker check: sender name (C1-C5), distinct colour per sender, metres value, and for off-screen markers an edge-clamped arrow.
**Expected Result**: Four senders' markers draw through geometry with name, colour and metres; off-screen ones clamp to the screen edge as arrows pointing toward the target.
**Actual Result**:
**Pass Criteria**: All four teammate markers show name, colour and distance; at least one marker is behind a wall and still drawn; off-screen markers are arrows. Pass/Fail: ______

## Test Case: PC8-06 — Marker fades at expiry (AC-2)
**Precondition**: Interactive run on port 30943 with two clients (shown + another) or the bot teammates. Marker lifetime is `ping_lifetime_s` (read the knob in the knobs data file before the run) and fade-out is 150 ms (inference).
**Steps**:
  1. Start host and an interactive view on `--port=30943 --count=5 --view=survivor`.
  2. Wait for a teammate marker (or ping yourself and read your own).
  3. Watch the marker from appearance to `ping_lifetime_s` plus 1 s.
**Expected Result**: The marker stays full alpha until expiry, fades out over about 150 ms, then is gone (no lingering ghost).
**Actual Result**:
**Pass Criteria**: Marker is absent within 1 s after `ping_lifetime_s` and fades rather than popping. Pass/Fail: ______ (unit test only so far; this is the first on-screen check)

## Test Case: PC8-07 — Callout wheel lists the 8 lines (AC-3)
**Precondition**: Bot run on port 30944.
**Steps**:
  1. Run host and view on `--port=30944`.
  2. Open `wheel.png`.
  3. Count entries and read each label against GDD rule 10's list of 8 callouts.
**Expected Result**: 8 lines shown; the aimed one ("Fuse here" in the evidence run) is boxed.
**Actual Result**:
**Pass Criteria**: Exactly 8 labels matching the GDD set; the aimed line is visibly highlighted. Pass/Fail: ______

## Test Case: PC8-08 — Wheel input context and cursor (AC-3, control manifest)
**Precondition**: Interactive run on port 30945.
**Steps**:
  1. Start host and interactive view (`--port=30945 --count=5 --view=survivor`).
  2. Hold Q; move the mouse; observe look and cursor.
  3. Release Q.
**Expected Result**: While held, the wheel shows, mouse look is masked (camera does not turn) and the mouse steers the wheel; on release look returns and the cursor is captured again.
**Actual Result**:
**Pass Criteria**: Camera yaw unchanged while Q held and mouse moved; look works within one second of release. Pass/Fail: ______

## Test Case: PC8-09 — Callout feed text, arrow, 8 s minimum, 10-line scrollback (AC-3)
**Precondition**: Interactive run on port 30946 so you can send callouts; teammates (bot clients) also call out.
**Steps**:
  1. Start host and interactive view on `--port=30946`, or use `--bot=ping` for the teammates' lines and read `markers.png`.
  2. Read the feed in `markers.png`: each line `[Name]: [text]` with a direction arrow.
  3. Interactive: send callouts spaced to satisfy the callout limits until the feed holds more than 10 lines (use several teammates or repeated runs; each different line needs 3 s spacing, same line 8 s). Time one line from appearance with a stopwatch.
  4. Count visible lines once more than 10 have been sent.
**Expected Result**: Lines read `[Name]: [text]` plus an arrow; each line stays on screen at least 8 s; at most 10 lines are kept (oldest dropped first).
**Actual Result**:
**Pass Criteria**: Format and arrow correct; no line gone before 8 s; the 11th line pushes out the 1st and count never exceeds 10. If 10+ lines cannot be produced by hand, mark the scrollback part BLOCKED and rely on the unit test. Pass/Fail: ______

## Test Case: PC8-10 — Callout audio is positional and not ducked (AC-3)
**Precondition**: Interactive run on port 30947, headphones, a teammate calling out from a different side of the shown survivor (bot teammates call "Danger" and "Wait").
**Steps**:
  1. Start the bot run without `--write-movie` (so audio plays at real time): view with `--bot=ping --port=30947`.
  2. Listen as teammates call out; note whether direction matches the feed arrow.
  3. Overlap a scare (not required) only if available; otherwise confirm the voice is audible over ambience.
**Expected Result**: Voice comes from the speaker's side and gets quieter with distance; callouts are not ducked by ambience.
**Actual Result**:
**Pass Criteria**: Tester can name the side of each callout and it matches the arrow. Placeholder voice lines are acceptable. Pass/Fail: ______

## Test Case: PC8-11 — Known gap: speaker gesture on screen (AC-4)
**Precondition**: Real callout from a teammate with line of sight to the shown survivor; shown client facing the speaker. The evidence run did NOT capture this (unit test only). The bot does not aim at the speaker, so use an interactive run with a second windowed view if possible.
**Steps**:
  1. Start host `--port=30948 --players=5`; start the bot view with `--bot=ping --port=30948` and note which teammate calls out; or run interactively and have the shown client look at a speaker (use `--bot=look` for a view toward the nearest body: `... -- --port=30948 --count=5 --view=survivor --bot=look --shots=production/qa/evidence/ping-callout-presentation`).
  2. At the moment of a callout, take a screenshot of the speaker's body (F12 or movie frame) and save it as `production/qa/evidence/ping-callout-presentation/gesture.png`.
  3. Repeat with the speaker out of line of sight (behind a wall).
**Expected Result**: A placeholder gesture sphere shows over the speaker for about 0.5 s on a real callout with line of sight; none when the view is blocked.
**Actual Result**:
**Pass Criteria**: `gesture.png` shows the sphere over the speaker; the out-of-sight shot shows none. If the bot cannot be made to align the camera, record BLOCKED with the reason (do not pass on the unit test). Pass/Fail: ______

## Test Case: PC8-12 — No gesture on a hidden survivor's or fake callout (AC-4 / GDD rule 28)
**Precondition**: A survivor hiding in a hiding spot, and a False Signal source. Probably not reachable from the manual launchers today.
**Steps**:
  1. Check whether `round_host`/`round_view` can place a hidden survivor or send a fake callout (read their headers; neither lists a flag).
  2. If not reachable, mark BLOCKED and rely on `tests/unit/pings-and-callouts/ping_callout_presentation_test.gd` (mutation "every callout given a gesture" is caught).
**Expected Result**: Hidden survivor's callout plays from the spot with no gesture; fake callout has none.
**Actual Result**:
**Pass Criteria**: No gesture visible in either case, or recorded BLOCKED. Pass/Fail: ______

## Test Case: PC8-13 — "(not you)" label (rule 28)
**Precondition**: Needs a disguised monster copying the shown survivor; probably unreachable manually.
**Steps**:
  1. Run `--bot=stage --disguise` (disguise.png after 1 s) with the shapeshifter copying the shown client's form and issue a callout if the launcher allows it; else mark BLOCKED.
**Expected Result**: The copied survivor's feed line has "(not you)" appended.
**Actual Result**:
**Pass Criteria**: Label visible, or BLOCKED (unit-tested). Pass/Fail: ______

---

## Sign-off

- Evidence retained in `production/qa/evidence/ping-callout-presentation/`: [ ] pending.png [ ] markers.png [ ] toofast.png [ ] wheel.png [ ] gesture.png
- Designer: ______ Date: ______
