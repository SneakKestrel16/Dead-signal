# Manual Test Cases: SE-6 Facility scare state and RoundScript anchors

> **Story**: `production/epics/scare-events/story-006-facility-scare-state-roundscript.md`
> **Story type**: Integration | **Output**: automated `tests/integration/scare-events/facility_scare_state_roundscript_test.gd` (passing) + this file for the real-round run | **Gate**: BLOCKING
> **GDD**: `design/gdd/scare-events.md` rules 6, 22, 23; Acceptance Criteria (Emergency within one RTT; RoundScript only at anchors; reconnect)
> **Date written**: 2026-10-15 | **Tester**: ______ | **Build/commit**: ______

## DATA GAP - run these only after the anchors are added

`data/maps/research_facility.tres` has NO scare anchors. RoundScript scares can never fire in a real round until it gains 9 `MapMarker` entries (`type = &"scare_anchor"`): sd1 A3 (9.5,0,19), sd2 A4 (17.5,0,25.5), sd3 A6 (5.5,0,4.5), sd4 B1 (31.5,0,27.5), sd5 C2 (45.5,0,27.5), sd6 C5 (44.5,0,13.5), sg1 A3 (9.5,0,24), sg2 A4 (13.5,0,17), sg3 A7 (17.5,0,13.5); plus `&"scare_anchor"` in `MapData.MARKER_TYPES` and updated counts in `tests/integration/facility-map/map_data_test.gd`. Positions are inferred from the level doc; the edit awaits the user. Cases SE6-01 and SE6-02 do not need anchors; SE6-03 onward do.

## Shared setup

```
GODOT="C:/Users/Ockey/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"
```

- Host: `"$GODOT" --headless --path . -s res://tests/manual/round_host.gd -- --port=<P> --players=5 [--force=3:evac]` (host prints one line per round event).
- View: `"$GODOT" --path . res://tests/manual/round_view.tscn -- --port=<P> --count=5 --view=survivor [--bot=walk]` (windowed; log prints state records and `ScareTriggered`).
- Ports 30980-30989. Use a fresh port per run; read output before trusting a run.
- A real round with the real catalogue: RoundScript entries come from the shipped scare catalogue. Check it names anchors sd1-sd6, sg1-sg3 (SE6-03 precondition).

---

## Test Case: SE6-01 — Precondition check: anchors present in the shipped map
**Precondition**: Anchors change committed.
**Steps**:
  1. `Grep` `data/maps/research_facility.tres` for `scare_anchor` (expect 9 matches).
  2. Run `"$GODOT" --headless --path . -s res://tests/manual/round_host.gd -- --port=30980 --players=5 --self-clients` and confirm it still reaches RoundEnded with exit code 0 (net ids not shifted).
**Expected Result**: 9 anchors sd1-sd6, sg1-sg3 with the proposed ids; round runs to Results.
**Actual Result**:
**Pass Criteria**: 9 anchor markers found and host exit code 0. Pass/Fail: ______

## Test Case: SE6-02 — Emergency on all 5 clients within one round trip (AC-1)
**Precondition**: Port 30981. Automated coverage: 2 real-ENet integration cases; this is the real-round check.
**Steps**:
  1. Host: `... -- --port=30981 --players=5 --force=3:evac`
  2. View: `... -- --port=30981 --count=5 --view=survivor` (all 5 clients run in this process).
  3. Read each client's log for the facility scare state change to Emergency and its drawn frame / timestamp; read the host's RoundPhaseChanged-to-Evacuation line.
**Expected Result**: All 5 clients log Emergency; each appears in the same reliable batch as, or the next batch after, the Evacuation phase event (delivery in the same tick; the story reads "one round trip" as same-tick delivery).
**Actual Result**:
**Pass Criteria**: 5 of 5 clients in Emergency, none later than one network round trip (loopback: <= 1 sim tick after host's event). Pass/Fail: ______

## Test Case: SE6-03 — RoundScript fires at an authored anchor in a real round (AC-2)
**Precondition**: Anchors added (SE6-01 passed); catalogue has RoundScript entries naming anchors; the scare is not blocked by gating (story 002: first scare after round start has no cooldown). Port 30982.
**Steps**:
  1. Host: `... -- --port=30982 --players=5`
  2. Interactive view: `... -- --port=30982 --count=5 --view=survivor` (no `--bot`).
  3. Walk the shown survivor into the sd1 volume (A3, approx x 9.5, z 19) in a phase listed for that anchor in the catalogue; watch the client log for `ScareTriggered`.
  4. Note scare_id, origin and the host log line.
**Expected Result**: One `ScareTriggered` from RoundScript (server source RoundScript) with an origin at/near the anchor; it fires once on entry, not every tick.
**Actual Result**:
**Pass Criteria**: Exactly one scare on entry with the anchor's origin; none while standing in the volume afterwards beyond gating limits. Pass/Fail: ______

## Test Case: SE6-04 — RoundScript does not fire away from anchors (AC-2)
**Precondition**: SE6-03 setup, port 30983.
**Steps**:
  1. Walk the shown survivor through the whole of A-zone corridors avoiding the 9 anchor volumes for 60 s.
  2. Watch the log for any `ScareTriggered` with RoundScript source.
**Expected Result**: None.
**Actual Result**:
**Pass Criteria**: Zero RoundScript scares outside anchor volumes. Pass/Fail: ______

## Test Case: SE6-05 — Phase filter and gating in a real round (AC-2, story 002)
**Precondition**: Port 30984; catalogue entry with a phase list.
**Steps**:
  1. Enter an anchor in a phase NOT in its list (read the catalogue entry first); expect nothing.
  2. Re-enter it in a listed phase: fires.
  3. Leave and re-enter the same anchor within 120 s: expect no second firing (same id and location).
  4. Enter a second anchor within 10 s of a first scare on the same client: expect blocked.
**Expected Result**: Each gate (phase list, 120 s same id/location, 10 s any scare) blocks as stated.
**Actual Result**:
**Pass Criteria**: All four sub-checks match. Pass/Fail: ______

## Test Case: SE6-06 — All 9 anchors fire (data coverage)
**Precondition**: Anchors added; port 30985; can take several runs to avoid cooldowns (reset per round).
**Steps**:
  1. For each anchor sd1-sd6, sg1-sg3: start a fresh round, walk to it in a listed phase, record whether a scare fired and its origin.
**Expected Result**: Each anchor that has a catalogue entry fires; each origin is inside its room.
**Actual Result**:
**Pass Criteria**: 9 of 9 anchors fire or are documented as lacking a catalogue entry. Pass/Fail: ______

## Test Case: SE6-07 — Reconnect shows current state, replays nothing (AC-3)
**Precondition**: Port 30986. Automated: 1 real-ENet case. Real-round variant.
**Steps**:
  1. Host `--port=30986 --players=5 --force=3:evac`, start the view; after Emergency, close the view process (ask nothing to be killed that you did not start).
  2. Start the view again on 30986 (rejoin) before the round ends.
  3. Check the log: facility scare state on join; any `ScareTriggered` from before the drop.
**Expected Result**: The rejoined client shows Emergency (current state) within one round trip and logs no scares that fired while away.
**Actual Result**:
**Pass Criteria**: State = Emergency on rejoin; zero replayed `ScareTriggered`. Rejoin may not be supported by `round_view` today; if the host rejects the same player slot, record BLOCKED and rely on the integration test. Pass/Fail: ______

## Test Case: SE6-08 — Scare never writes lighting (manifest rule)
**Precondition**: Port 30987.
**Steps**:
  1. Run SE6-03 with the log capturing `LIGHT` records.
  2. Compare lighting records before/after a RoundScript scare.
**Expected Result**: No lighting state record caused by the scare (only the flicker/dim presentation on the client).
**Actual Result**:
**Pass Criteria**: No server-sourced lighting change timed to the scare. Pass/Fail: ______

---

## Sign-off

- [ ] Anchors committed and SE6-01 passed
- [ ] Log excerpts for SE6-02, SE6-03, SE6-07 pasted into the story's evidence
- QA lead: ______ Date: ______
