# Evidence: borrowed-face story 009, disguise and true-form rendering

`DisguisePresenter` (`src/feature/borrowed_face/disguise_presenter.gd`) is wired into `RoundClient`
(`src/feature/match_flow/round_client.gd`, MF-11). The body colour per appearance id is MF-11's
`colour_of`, unchanged. The captures come from `tests/manual/round_view.tscn` with the new `--bot=stage`
(`--disguise`, `--stun`), against `tests/manual/round_host.gd` with 5 players on real ENet over
127.0.0.1. Godot 4.7.2, windowed, `--write-movie <tmp>/f.avi --fixed-fps 30`, 2026-10-15. Each
screenshot is the drawn frame, saved after `RenderingServer.frame_post_draw`. The shown client is a
survivor. The other four clients stand in a line 3.5 m in front of it, with the shapeshifter in second place
next to its target.

## Captures (`disguise-rendering/`)

1. `01-two-copies-of-c3.png` (run A, frame 1145, 1 s after the disguise completed): from left to right, C2
   (blue), the **disguised shapeshifter as C3** (green), the **real C3** (green), C4 (yellow). The two C3
   bodies are drawn the same. `run-a-disguise-stun.txt` lists the handles of the frame: appearance 3 at x 2.52
   (copy) and at x 3.60 (real).
2. `02-disguised-stun-borrowed-stagger.png` (run A, frame 1202, 6 frames into the stagger): the survivor
   fired its taser at the disguised shapeshifter. The green C3 copy tilts in the greybox stagger, and the
   real C3 next to it stands upright. Cue printed: `CUE voice_c3.shocked_grunt`. No pain cry was printed.
3. `03-true-form-stun-monster-stagger.png` (run B, frame 1265): a separate round with no disguise. The
   true form (red, appearance 0) staggers. Cue printed: `CUE voice_c0.pain_cry`. The true form reads
   clearly against the greybox floor here. The darkness that the slice REPORT noted came from the
   prototype's lighting and is not present in this client scene.

The `.txt` files are the filtered console output of each run.

## Acceptance criteria

- AC1: "two copies of the same survivor both render as that survivor" is shown by capture 01. The
  greybox draws no carried items on any body, and the snapshot has no visible-items field yet. So "a
  disguised copy of a drive carrier shows no drive" holds trivially here, and no capture shows a drive
  carrier. **Inference:** this needs testing again once item attachments are drawn (ADR-0010 §7: the
  server leaves visible-items empty for a disguise).
- AC2: no body name labels exist (ADR-0010 §7, lobby-role-assignment rule 11), so the label clause is
  N/A. The footstep set is `c<appearance>.<gait>` server-side (`Footsteps`, story controller-interaction/014,
  `test_disguised_walking_monster_sounds_like_its_target_to_remote_clients`). The snapshot carries no
  Downed flag, and the server never sends one for a disguise, so a copy always stands upright. The greybox
  also draws no Downed pose for anyone yet.
- AC3: shown by captures 02 and 03 and their cues. The cue comes from the appearance the body shows at
  that moment, never from the event type (TR-defense-011). Unit tests:
  `tests/unit/borrowed-face/disguise_presenter_test.gd`.

## Commands

```text
<godot> --headless --path . -s res://tests/manual/round_host.gd -- --port=24794 --players=5
<godot> --path . res://tests/manual/round_view.tscn --windowed --write-movie <tmp>/f.avi --fixed-fps 30 \
    --quit-after 2400 -- --port=24794 --count=5 --view=survivor --bot=stage --disguise --stun --shots=<tmp>
# run B: same, port 24796, --quit-after 1500, without --disguise
```

## Known gaps

- The vocal cues are signal emissions with catalog ids (`<voice_set>.shocked_grunt`, `voice_c0.pain_cry`,
  inferred names). No client audio player exists yet, so nothing is heard.
- The stagger is a greybox tilt of the capsule for `stun_root_s` (inference: the body is rooted then). It
  will be replaced by the rig's stagger clip (ADR-0010 §3).
- The ADR-0010 transform warp (§6), the shared rig and the `appearances.tres` puppet are not in this story's
  acceptance criteria and are not built.

## Sign-off

- [ ] Lead sign-off: captures 01-03 reviewed.
