# Evidence: survivor-defense story 011, shock presentation per form and cosmetic flashlight

`ShockPresenter` (`src/feature/survivor_defense/shock_presenter.gd`) is wired into `RoundClient`
(`src/feature/match_flow/round_client.gd`). It sends the shock events to BF-9's `DisguisePresenter`
for the stagger and vocal cue, and adds the arc, spark, own jitter, jolt and blue edge. `PlaceholderAudio`
(`src/core/audio/placeholder_audio.gd`) plays every cue and server sound (including SD-10's `hide_enter`,
`hide_exit` and `hide_cue`) as a placeholder beep, because no audio assets exist yet. `SurvivorDefense`
lets the shapeshifter toggle a cosmetic flashlight, which is shown only while it is disguised (rule 6).

The captures come from `tests/manual/round_view.tscn` with `--bot=stage`, run against
`tests/manual/round_host.gd` with 5 players on real ENet over 127.0.0.1. Settings: Godot 4.7.2,
windowed, `--write-movie <tmp>/f.avi --fixed-fps 30`, 2026-10-15. The shown client is a survivor. Each
screenshot is the drawn frame on which the effect first lit (`arc`, `spark`, `edge`), or 6 frames into
the stagger. The `run-*.txt` files hold each run's console output, filtered to cues, fires, shots and
drawn handles with their appearance.

## Captures (`per-form-presentation/`)

1. `01-survivor-shocked-arc.png` (run r1, `--stun=survivor`): the shown survivor shoots the last
   survivor in the line (C5, purple). The blue arc shows on it, and the cues are
   `voice_c5.shocked_grunt` and `taser_crackle`.
2. `02-survivor-shocked-stagger.png` (run r1, 6 frames later): the same survivor, mid-stagger.
3. `03-disguised-copy-cosmetic-cone.png` (run r2, 1 s after the disguise): the shapeshifter, disguised
   as C3 (second from left, green), has turned its flashlight on. **Inference:** the glow on the real C3
   next to it is the copy's cone, since the copy stands facing its target. The capture log does not
   record the cone flag. The unit check is `test_disguised_monster_toggles_a_cosmetic_cone_hidden_in_true_form`.
4. `04-disguised-monster-shocked.png` (run r2): the disguised copy is shot. It tilts in the stagger with
   the arc on it, and the cues are `voice_c3.shocked_grunt` and `taser_crackle`. These are the same
   cues as in capture 1, and no pain cry plays (AC-1).
5. `05-true-form-stun.png` (run r3, `--stun --twice`): the true form (red) is stunned. The cues are
   `voice_c0.pain_cry` and `taser_crackle`, with the arc and the stagger (AC-2).
6. `06-true-form-resisted-spark.png` (run r3, 3 s later, inside `stun_immunity_s`): the second hit is
   resisted. A small orange spark shows on the true form, the only cue is `taser_fizz`, and there is no
   stagger (AC-2).
7. `07-own-shock-blue-edge.png` (run r4, `--stun=me`): a line survivor shoots the shown client. The
   blue screen edge and the crackle play. The jitter is a `CameraFx` offset that goes back to rest after
   `stun_root_s` (unit test). A still image cannot show it.

## Acceptance criteria

- AC-1: an observer receives the same `PlayerShocked {body}` for a survivor, a stunned disguise and an
  immune disguise (the `EvPlayerShocked` / `EvMonsterStunned` projections), and the presentation is
  chosen only from the appearance the body shows. Captures 1, 2 and 4. Unit test:
  `test_survivor_shock_and_disguised_hit_look_and_sound_the_same`, which shows that cues, stagger, mesh
  pose, arc and spark are equal when position is taken out.
- AC-2: captures 5 and 6, plus `test_true_form_stun_plays_the_pain_cry_stagger_and_arc` and
  `test_resisted_true_form_hit_plays_the_spark_and_fizz_only`.
- AC-3: capture 3 (inference, see above) and the integration test.
- Reduced-flash and reduced-motion variants: `flash_scale` and the `FlashLimiter` refuse or scale the
  arc, spark and edge, and the stagger and sounds still play. These are covered by unit tests, not by
  captures. `CameraFx.enabled` zeroes the jitter and jolt.

## Known gaps

- Every sound is the same placeholder beep, pitched per id (`taser_crackle` and `taser_fizz` are
  inferred catalog names). Footsteps and lunge sounds beep too. The ADR-0013 AudioDirector replaces this.
- No barricade sounds are sent by the server yet, so none are presented.
- The shapeshifter's own client gets both own events on a disguised stun, so it sees jitter, edge and
  jolt together (inference). Only that client sees this.

## Sign-off

- [ ] Lead sign-off: captures 01-07 reviewed.
