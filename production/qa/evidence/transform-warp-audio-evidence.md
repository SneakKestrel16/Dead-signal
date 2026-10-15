# Evidence: borrowed-face story 010, transformation warp and distortion audio

`TransformPresenter` (`src/feature/borrowed_face/transform_presenter.gd`) is wired into `RoundClient`
(`src/feature/match_flow/round_client.gd`). It draws the warp overlay
(`src/feature/borrowed_face/spatial_fx_transform_warp.gdshader`) on every drawn body whose snapshot says
Transforming. It also plays the distortion that `BorrowedFace` now sends when a transformation is accepted.
The captures come from `tests/manual/round_view.tscn` (`--bot=stage --disguise`) against
`tests/manual/round_host.gd`, with 5 players on real ENet over 127.0.0.1. Godot 4.7.2, windowed,
`--write-movie <tmp>/f.avi --fixed-fps 30`, 2026-10-15. The shown client is a survivor. The shapeshifter
(true form, red) stands second from the left and turns into the survivor beside it.

## Captures (`transform-warp-audio/`)

1. `01-warp-early.png` (run 3, frame 1287, 10 drawn frames into Transforming, `warp` 0.15): the red true
   form shows a cold rippled shimmer. The three survivors beside it have no overlay.
2. `02-warp-late.png` (run 3, frame 1322, `warp` 0.73): the same shimmer, still on the transforming body
   only.
3. `03-after-transform-no-warp.png` (run 3, frame 1547, 30 frames after the shapeshifter's own entry
   showed the new form): the copy is drawn as C4 (yellow) beside the real C4, and the overlay is gone.
4. `04-probe-zero-tint-overlay-invisible.png` (probe run, port 30411): the same overlay with `tint.a` and
   `refraction_strength` forced to 0. The body is drawn unchanged, so the screen texture holds the body
   and the overlay draws over it, not beside it (ADR-0010 Verification 2, greybox capsule only; not a
   skinned mesh).

`run-warp-distortion.txt` is the filtered console output of run 3. Its `warp-after.png` lines come from a
shot that was removed afterwards: drawn frames are not seconds under `--write-movie`, because the client
renders faster than the host's wall clock. 90 frames in, the body was still Transforming, with `warp`
held at 1.0 by the client's own clock. Capture 03 is the after frame instead.

## Acceptance criteria

- AC1 (distortion within 15 m, bearing within ±15°; not at 20 m):
  - Server: `BorrowedFace` sends one positional sound, set `distortion` with radius `distortion_radius_m`
    (15 m), at the shapeshifter's body when it accepts a transformation. The event names no body
    (ADR-0004 §6).
  - Unit tests (`tests/unit/borrowed-face/transform_warp_audio_test.gd`): the real `EventBatch.build` sends
    the distortion to a viewer 15 m away and not to one 20 m away. The client plays it from an
    `AudioStreamPlayer3D` at the event position with `max_distance` equal to the send radius, and its
    bearing from the listener equals the true bearing.
  - Live run 3: `DISTORTION ... bearing 0.1 deg, true bearing -8.9 deg, distance 4.28 m`. The "true
    bearing" is measured to the shapeshifter client's own predicted body, which is in the same process.
    The event is at the server's body position on the accept tick. **Inference:** the 9° gap is that
    predicted body's position differing from the server's, not a panning error. Logging the server-side
    position would settle it.
  - **Not verified:** that the engine's actual panning matches the player position, and the 20 m case on a
    live client (every staged client stands within about 5 m). The pan is a listening test; the 20 m cut
    is the server send, covered by the unit test.
- AC2 (the warp plays on every client in view for the whole Transforming state): captures 01-03 and the
  `WARP` lines (overlay present while `transforming` is true, on that body only). The unit test covers
  the overlay leaving when the flag clears and starting again on a new transformation. Only the
  survivor view was captured. Every `RoundClient` runs the same presenter from the same snapshot flag.

## Commands

```text
<godot> --headless --path . -s res://tests/manual/round_host.gd -- --port=30414 --players=5
<godot> --path . res://tests/manual/round_view.tscn --windowed --write-movie <tmp>/f.avi --fixed-fps 30 \
    --quit-after 1700 -- --port=30414 --count=5 --view=survivor --bot=stage --disguise --shots=<tmp>
```

## Known gaps (placeholders)

- **Audio placeholder:** no audio asset exists. The distortion is a generated 140 Hz tone with a 9 Hz
  pitch wobble, lasting `transform_duration_s` (`TransformPresenter.tone`). It plays on the default bus,
  with no `AudioDirector` pool, `AudioCatalog` or `GameplayCues` bus (ADR-0013 §1-3 are not built). The
  sound set name `distortion` is inferred; the catalog settles it.
- **Warp placeholder:** the tint colour and strength and the ripple constants are NOT SOURCEABLE greybox
  values, to be settled by the VFX pass. The GDD asks for a "subtle" warp (rule 8), and this one reads
  clearly on the greybox capsule: lead judgement needed. Reduced motion (static tint) is wired, but no
  settings store sets it yet. There is no pre-warm pass (ADR-0010 §5).
- **One sound at the start:** the distortion is sent once, at the body's position when the transformation
  is accepted. It does not follow the body, and a client that walks into range mid-transformation does not
  hear it. This is an inference from the GDD rule 8 wording; a designer ruling settles it.

## Sign-off

- [ ] Lead sign-off: captures 01-04 reviewed; warp strength judged "subtle" enough or retuned.
- [ ] Listening test: the distortion pans from the shapeshifter's direction within ±15°.
