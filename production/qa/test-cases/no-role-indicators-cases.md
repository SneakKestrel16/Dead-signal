# Manual test cases: LB-6 no name tags or role indicators

**Story**: `production/epics/lobby-role-assignment/story-006-no-role-indicators.md` | **Type**: UI | **Gate**: BLOCKING
**Evidence**: `production/qa/evidence/no-role-indicators-evidence.md` (sign-off open)
**Tester**: designer, Git Bash at the repo root, `G` set as in `client-round-scene-cases.md`.

## Already automated

- AC2, the remote scene tree carries no role, ID or name property: `tests/integration/lobby/no_role_indicators_test.gd` (`test_client_draws_remote_bodies_by_appearance_only`, `test_survivor_client_scene_shows_no_tag_or_identity`).

---

## Test Case: LB6-01: No body shows a tag or a role marker in free play

**Preconditions**:
1. `"$G" --headless --path . -s res://tests/manual/round_host.gd -- --port=30501 --players=5`
2. `"$G" --path . res://tests/manual/round_view.tscn --windowed -- --port=30501 --count=5 --view=survivor`

**Steps**:
1. Walk (WASD) until each of the other bodies has been in view at near (2 m) and far (10 m) range.
2. Look for any text, icon, outline or colour that differs from a plain capsule.

**Expected Result**: Every body is a plain coloured capsule. Nothing names it or marks its role.
**Actual Result**:
**Pass/Fail**:

---

## Test Case: LB6-02: A disguised shapeshifter cannot be told from its target

**Preconditions**: Host on port 30502. Client: `... --port=30502 --count=5 --view=survivor --bot=stage --disguise`

**Steps**:
1. After the disguise, look at the two bodies of the same colour.

**Expected Result**: The two are drawn alike, and nothing on screen marks either one.
**Actual Result**:
**Pass/Fail**:
