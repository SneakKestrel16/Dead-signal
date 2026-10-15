# Evidence: lobby-role-assignment story 006, no name tags or role indicators on bodies

AC-LB-31, TR-lobby-010, ADR-0004. `RoundClient` (`src/feature/match_flow/round_client.gd`), launched by
`tests/manual/round_view.tscn` against `tests/manual/round_host.gd` (5 players, real ENet on 127.0.0.1),
Godot 4.7.2, windowed, `--write-movie <tmp>/f.avi --fixed-fps 30`, 2026-10-15. Each screenshot is the drawn
frame, saved after `RenderingServer.frame_post_draw`. No code changed for this story: the client scene
already draws a remote body as a capsule in its appearance colour plus a flashlight cone, nothing else.

## Captures (`no-role-indicators/`)

| Screenshot | View | What it shows |
|---|---|---|
| `survivor-client0-view.png` | Client0, a survivor (`--view=0`), frame 560 | Two other survivors (green, purple capsules), own flashlight cone on the green one. No text, icon or marker over any body |
| `survivor-client1-view.png` | Client1, a survivor (`--view=1`), separate round, frame 560 | Yellow survivor ahead, green one at the right edge. No tag |
| `survivor-client2-view.png` | Client2, a survivor (`--view=2`), separate round, frame 560 | Purple survivor ahead, yellow at the right edge. No tag |
| `survivor-sees-disguised-shapeshifter.png` | Client0, a survivor (`--view=survivor --bot=stage --disguise`), frame 1563 | Four bodies in a line: blue, green, green, yellow. One green is the shapeshifter disguised as appearance 3, standing next to the survivor it copied; the two greens are drawn alike and nothing marks either |

Each of the first three is a separate round with its own randomly picked shapeshifter (runs with
`--view=3` and `--view=4` drew the shapeshifter's own view and were discarded). In those three the
shapeshifter was not in the shown survivor's view at frame 560, so the fourth capture stages it in view.

Legend of the fourth capture (run printout, `DRAWN handle <h> appearance <a> at <pos>`): appearance 2 at
x 1.30 (blue), appearance 3 at x 2.53 and x 3.59 (green), appearance 4 at x 4.80 (yellow). Which green is
the shapeshifter is inference from `round_view.gd`'s stage layout (the shapeshifter takes line slot 1 of
4, the x 2.53 body); the client has no field that says so, which is what this story requires. A run
that also printed the composer's monster handle would settle it.

## Automated check

`tests/integration/lobby/no_role_indicators_test.gd` (7 cases, all pass):

- `test_client_draws_remote_bodies_by_appearance_only`: an offline `RoundClient` fed a survivor, the
  shapeshifter disguised as that survivor, and a true form. Every remote body is exactly Node3D + "Mesh"
  (MeshInstance3D) + "Cone" (SpotLight3D), with no script or meta; the disguised one has the survivor's
  colour; no Label3D, Sprite3D, AnimatedSprite3D, Decal or particle node in the client tree.
- `test_survivor_client_scene_shows_no_tag_or_identity`: a composed 5-player round over real ENet with
  rendering clients. On all four survivor clients, every remote body node passes the same structure
  check, no String or StringName property on it holds any player's display name or "shapeshifter",
  "survivor" or "monster", the replicated puppet state has only the remote snapshot fields, and the
  client tree holds no world-space tag node (AC 2: the remote scene tree).
- The five earlier cases (wire format, PuppetMap state, PlayerBody, captured survivor packets) were
  already in the suite.

Mutations, each caught and reverted: a Label3D added to every remote body (2 cases fail), a `role` meta on
every remote body (2 cases fail), remote body nodes renamed "monster"/"survivor" by appearance (the live
round case fails).

## Commands

```text
<godot> --headless --path . -s res://tests/manual/round_host.gd -- --port=<p> --players=5
<godot> --path . res://tests/manual/round_view.tscn --windowed --write-movie <tmp>/f.avi --fixed-fps 30 \
    --quit-after 600 -- --port=<p> --count=5 --view=<0|1|2> --bot=look --light --shot-at=560 --shots=<tmp>
<godot> --path . res://tests/manual/round_view.tscn --windowed --write-movie <tmp>/f.avi --fixed-fps 30 \
    --quit-after 2400 -- --port=<p> --count=5 --view=survivor --bot=stage --disguise --shots=<tmp>
```

## Sign-off

- [ ] Lead sign-off
