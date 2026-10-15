# Evidence: facility-map story 011, surveillance cameras at the C1 monitor

The server side is `Surveillance` (`src/core/facility/surveillance.gd`). It is the monitor's instant
Interactable: each press cycles c1 -> c4 -> off. It also adds the viewed camera's volumes to body relevance
and to lighting replication (`LightingReplication.extra_volumes`, ADR-0009 §8), and it sends
`EventBatch.CAMERA` to the viewer. The client side is `SurveillanceFeed`
(`src/core/facility/surveillance_feed.gd`), wired into `RoundClient`. It is one `SubViewport` that shares
the main World3D, and it renders only while a camera is viewed.

The captures were made with `tests/manual/round_view.tscn --bot=monitor --view=monitor` against
`tests/manual/round_host.gd --place=monitor --force=3:power,20:blackout,...`: 5 players on real ENet over
127.0.0.1, Godot 4.7.2, windowed, `--write-movie <tmp>/f.avi --fixed-fps 30`, 2026-10-15, after merging
main 541a1b9 (FM-10 lighting, AD-217).

- The host spawns the first survivor in front of the monitor in C1. It spawns the shapeshifter next to
  another survivor in B1, in c1's view.
- The shown client is the survivor at the monitor. Its presses resolve through AD-217 (the map index on
  the wire), with no net-id override.
- The bot hides the other in-process clients' remote bodies and their LightingPresenters. Every body and
  light on screen therefore comes from what the shown client received.
- `run-view.txt` lists that client's lighting records for B1 and H-S3 at each shot.

## Captures (`surveillance-cameras/`)

1. `01-main-view-cam1-trueform.png` and `02-feed-cam1-trueform.png` (frame 63, Low Power): the monitor
   screen in C1 shows c1 (B1). The shapeshifter is red (appearance 0) next to its target (appearance 3,
   green). Neither body is in C1's visibility set, so they reach this client only through the camera.
2. `03-main-view-cam1-disguise.png` and `04-feed-cam1-disguise.png` (frame 663, Power Restored, B1 record
   `base 1, dark_until 0`): the shapeshifter now wears its target's form and is drawn as appearance 3,
   the same as the real target (DRAWN: appearance 3 at x 28.6 and at x 30.0). It is never drawn as the true
   form.
3. `05`, `06` and `07-feed-cam2/3/4.png`: c2 (H-S, facing east), c3 (C4, facing south) and c4 (A2 spine,
   facing south), lit by Power Restored.
4. `08-main-view-off.png`: the fifth press turns the feed off. The screen is hidden and the viewport is
   `UPDATE_DISABLED`.
5. `09-feed-cam1-b1-blackout.png` and `10-main-view-cam1-b1-blackout.png` (frame 2412, B1 record
   `dark_until 1561`): c1 again during a Blackout in B1. Compared with 04, B1's warm overheads are off and
   only the red emergency strips stay on. The rooms beyond B1 in the back of the frame keep their overheads,
   so the feed shows lit and dark rooms side by side. The B1 record came in after the feed returned to c1
   while the client stood in C1, which is the camera's lighting set at work (the client was off-camera, so
   B1 was outside its own set).
6. `11-feed-cam2-during-b1-blackout.png`: c2 (H-S) while B1 is still dark: H-S is lit (record `base 1,
   dark_until 0`).

The lit-versus-dark difference was measured as mean luminance (Godot `Image`), 04 against 09:
- whole frame: 0.2265 against 0.2033;
- lower floor band (rows 200-360, B1 floor): 0.1769 against 0.1226;
- centre: 0.1799 against 0.1552.

The same comparison under Low Power (an earlier run, not kept) differed by only 0.1334 against 0.1217.
B1's Low Power preset is dim by design (Zone B, scale 0.5).

The thin blue and brown posts are `MapGreybox` marker posts. The greybox has floors only and no walls, so
each feed looks across the whole map. **Inference:** the feeds will be framed by walls once the level
geometry exists.

## Feed render cost (ADR-0009 Implementation Notes)

The cost was measured with `RenderingServer.viewport_set_measure_render_time` over the 45 drawn frames
before each shot, at 480x360, on an RTX 5070 with Vulkan Forward+. The FM-10 dynamic lights were on and the
feed had no shadows.

| Capture | feed CPU ms | feed GPU ms | main CPU ms | main GPU ms |
|---|---|---|---|---|
| cam1 true form | 0.116 | 0.066 | 0.205 | 0.318 |
| cam1 disguise | 0.099 | 0.081 | 0.204 | 0.299 |
| cam2 | 0.071 | 0.072 | 0.213 | 0.297 |
| cam3 | 0.079 | 0.079 | 0.192 | 0.264 |
| cam4 | 0.093 | 0.093 | 0.196 | 0.294 |
| cam1, B1 Blackout | 0.088 | 0.082 | 0.194 | 0.291 |

The "off" row in `run-view.txt` reads the last measurement taken before the viewport was disabled, so it
is not a cost. The ADR-0009 spike (Verification 7, 8 and 10) still has to measure with shadowed fixtures.

## Acceptance criteria

- AC1, four feeds at the level-doc positions that follow each volume's lighting: shown by captures 01-11.
  Lighting is shown by 04 against 09 and by 11. The camera positions are the map markers c1-c4. Their
  facings (`yaw_deg`, new on camera markers) are **inferred** from the level doc's "Covers" column: c1
  faces the Core (-160), c2 faces east toward C3 (-90), c3 faces south down C4 (180) and c4 faces south down
  the spine (180). The pitch (-25), FOV (75) and mount height (0.3 m under the volume ceiling) are greybox
  guesses.
- AC2, a disguise appears as its disguise: shown by captures 02 against 04. The server sends every
  snapshot entry with `appearance_of`, and the feed draws the client's own remote bodies, so the feed has no
  separate path that could show the true form. Unit tests are in
  `tests/unit/facility-map/surveillance_test.gd`, `surveillance_feed_test.gd` and
  `lighting_replication_test.gd` (`test_a_viewed_cameras_volumes_are_sent_like_visible_ones`).

## Commands

```text
<godot> --headless --path . -s res://tests/manual/round_host.gd -- --port=30115 --players=5 --place=monitor \
    --force=3:power,20:blackout,30:blackout,40:blackout,50:blackout,60:blackout
<godot> --path . res://tests/manual/round_view.tscn --windowed --write-movie <tmp>/f.avi --fixed-fps 30 \
    --quit-after 4000 -- --port=30115 --count=5 --view=monitor --bot=monitor --shots=<tmp>
```

`--force` emits the events on the host bus directly, skipping the objective and ability rules. It is for
manual capture only.

## Known gaps

- The run printed `10 ObjectDB instances were leaked at exit` from the windowed round_view, which exits
  through `--quit-after`. Whether this is new was not checked against a run without the feed.
- The impossible-image scare overlay is out of scope (Scare Events).

## Sign-off

- [ ] Lead sign-off: captures 01-11 reviewed.
