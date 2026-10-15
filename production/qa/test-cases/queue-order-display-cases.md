# Manual test cases: LB-12 queue order display

**Story**: `production/epics/lobby-role-assignment/story-012-queue-order-display.md` | **Type**: UI | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/lobby-queue-order-evidence.md` (screenshots 01-04, sign-off open)
**Tester**: designer, Git Bash at the repo root, `G` set as in `client-round-scene-cases.md`.

## Already automated

- Picker requests refused while Ready, and queue encode/decode: `tests/unit/lobby/queue_order_display_test.gd`.

## Preconditions (four terminals, in this order)

```bash
"$G" --path . res://src/main.tscn --windowed --resolution 1280x720 -- --lobby-host --lobby-name=Ann --lobby-port=30311 --lobby-ready --lobby-seed=3 --lobby-cancel-round
"$G" --path . res://src/main.tscn --windowed --resolution 1280x720 -- --lobby-join=127.0.0.1 --lobby-name=Bob --lobby-port=30311 --lobby-ready
"$G" --path . res://src/main.tscn --windowed --resolution 1280x720 -- --lobby-join=127.0.0.1 --lobby-name=Cy --lobby-port=30311 --lobby-ready
"$G" --path . res://src/main.tscn --windowed --resolution 1280x720 -- --lobby-join=127.0.0.1 --lobby-name=Dee --lobby-port=30311 --lobby-ready
```

Flags are parsed by `src/ui/lobby/lobby_screen.gd` (`--lobby-join=ADDR`, `--lobby-port=N`, `--lobby-name=NAME`).

---

## Test Case: LB12-01: The picker is disabled while Ready

**Steps**:
1. During the countdown, look at Bob's Character picker and try to click it.

**Expected Result**: The picker is greyed out and does not open.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: LB12-02: With an absent head, every client shows the same queue and names the first present player

**Steps**:
1. Let the countdown lock and the round cancel. All instances return to Waiting.
2. Close Dee's window.
3. Read the queue on Ann, Bob and Cy.
4. On Bob, check the picker again (he is no longer Ready).

**Expected Result**: All three show `1. Dee (away), 2. Bob (next shapeshifter), 3. Ann, 4. Cy`, with "(you)" on the viewer's own row. Bob's picker is enabled.
**Actual Result**:
**Pass/Fail**:
