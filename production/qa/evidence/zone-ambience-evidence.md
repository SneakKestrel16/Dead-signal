# Evidence: facility-map story 012, zone ambience and B3 footstep masking

`ZoneAmbience` (`src/core/facility/zone_ambience.gd`), wired into `RoundClient` (`src/feature/match_flow/round_client.gd`).
It was launched by `tests/manual/round_view.tscn --bot=walk` against `tests/manual/round_host.gd` (4 players, real
ENet on 127.0.0.1). Godot 4.7.2, windowed, `--write-movie <tmp>/movie.avi`, 2026-10-15.

Audio cannot be judged from a screenshot. The overlay in the top-left corner prints the presenter's state each
frame: the active zone, the listener's volume, the bus, and each of the two bed players' levels. The beds are
**placeholder** generated sines (A 110 Hz, B 70 Hz, C 220 Hz, link 55 Hz). No audio assets exist yet.

## Captures (`zone-ambience/`)

1. `zone_a.png` (frame 121): a survivor at the A1 spawn. Overlay: `zone A, volume A1, bus Ambience [- -inf dB | A 0.0 dB]`.
   Only the zone A bed plays.
2. `crossfade.png` (frame 382): 0.75 s (half of `CROSSFADE_S`) after the bot walked through the A1-H-S archway
   into H-S1. Overlay: `zone link, volume H-S1 [link -5.8 dB | A -6.2 dB]`. Both beds sit near -6 dB (linear 0.5).
3. `link.png` (frame 458): 2.0 s after the border. Overlay: `[link 0.0 dB | A -inf dB]`. The A bed has faded out
   and stopped.

The log lines for the same run (`BORDER`, `CROSSFADE`, `LINK`) carry the same text.

## AC 2 (B3 masking)

This AC is server-side and has no visual. It is covered by
`tests/unit/facility-map/zone_ambience_test.gd::test_listener_just_outside_the_masked_radius_hears_a_walk_in_b3_only_elsewhere`.
A walk in B3 is sent with `footstep_radius_walk_m * 0.5`. A listener between the masked and full radius gets no
sound from B3, and does get one at the same distance in B1.

## Commands

```text
<godot> --headless --path . -s res://tests/manual/round_host.gd -- --port=24814 --players=4
<godot> --path . --write-movie <tmp>/movie.avi --quit-after 1800 res://tests/manual/round_view.tscn -- \
    --port=24814 --count=4 --view=survivor --bot=walk --shots=production/qa/evidence/zone-ambience
```

## Notes

- Under `--write-movie`, the view process reports 8 leaked `AudioStreamWAV` / `AudioStreamPlaybackWAV` at exit
  (4 clients x one playing bed). The same run without `--write-movie` reports none. Inference: the movie writer
  stops mixing at quit, so the playbacks are never released; a Godot movie-writer source read would settle it.
- Not here: the B3 machinery positional loop and the Evacuation alarm bed, both still to come.

## Sign-off

- [ ] Lead sign-off: listened in a live round; each zone's bed is distinct and the crossfade at a volume border is smooth
