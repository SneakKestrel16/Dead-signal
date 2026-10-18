# Designer picks

What the designer picked on the review pages (`tools/audio/review/<family>/index.html`, `uv run tools/audio/review.py
<family>`) and what each note asks of the next round. The picks themselves live in `tools/audio/picks.py` (`SHIP`),
which `tools/audio/export.py` reads: a picked candidate ships with the bytes it was heard with (it seeds from the name
it was heard under, `Sound.heard_as`); `before` ships the pre-pipeline take from `tools/audio/sources/legacy/` as
built. Source: the seven `picks.json` exports of 2026-10-16.

## Round 1 (2026-10-16)

| Sound | Ships | Designer's note | Round 2 |
|---|---|---|---|
| amb_a | B | | |
| amb_b | A | | |
| amb_c | B | on "before": should be quieter with more emphasis on the location | |
| amb_link | B | on A: good for silent ambience | |
| callout_c1 | B | | |
| callout_c2 - c5 | A | | |
| grunt_c1 - c5 | A (no pick) | "more like where it's a grunt but more audible and less muffled" | yes |
| pain_cry_true_form | C | | |
| scare_transformation_reveal | B | | |
| scare_door_burst | C | | |
| scare_ambush_lunge | C | | |
| scare_blackout | B | | |
| scare_slammed_door | C | | |
| scare_glass_break | B | on B: "add more variety to it instead of the same sound twice" | yes |
| scare_alarm_fuse | C | | |
| scare_alarm_evacuation | A (no pick) | "more like the first where it's an actual alarm" | yes |
| scare_recording_room | B | | |
| scare_recording_script | C | | |
| scare_surveillance_image | A | | |
| scare_stinger | B | | |
| ui_click | A | | |
| ping_rejected | C | | |
| step_tile | A (no pick) | none | yes |
| step_concrete | B | | |
| step_metal | C | | |
| step_rubber | A | | |
| step_true_form | C | | |
| lunge_cue | C | "they all sound the same and none sound like a lunge" | yes |
| lunge_scrape | A | | |
| lunge_hit | A (no pick) | "should sound like a survivor being hit, a low thud with cloth being moved" | yes |
| taser_crackle | B | | |
| taser_fizz | before | | |
| hide_cue | C + B | final: "C for final choice but keep B" | |
| distortion | A (no pick) | on A: "sounds like crunching on a chip, should be flesh and bone moving" | yes |
| fuse_install | A (no pick) | "all bad, redo" | yes |
| hide_enter | B | | |
| hide_exit | C | | |
| door_open, door_close | before | | |
| barricade_build | A (no pick) | none | yes |
| barricade_break | B | | |
| objective_dock | before | | |
| objective_alarm | B | | |

Open (not decided by the notes):

- **hide_cue "keep B"**: settled 2026-10-16, the designer said yes to B playing too. `picks.py` ships `"CB"`: two
  takes, `hide_cue_0` (C) and `hide_cue_1` (B), picked at random by the AudioStreamRandomizer (not strictly alternating).
- **amb_link A "good for silent ambience"**: no silent-ambience slot exists in the game; A's builder stays in
  `sounds/ambience.py` for one.
- **amb_c note** is on the pre-pipeline take, not on the picked B.

## Round 2 (2026-10-16)

Pages: `uv run tools/audio/review.py <family> --round 2` writes `tools/audio/review/<family>/r2/index.html`
(voices, scares, cues, world, steps). Each sound shows what ships **now**, then D, E, F (the module's `ROUND2`); the
page exports `picks_<family>_r2.json`. A pick of D, E or F goes in `picks.py` like A-C; "now" keeps the current one.
New recordings: the round-2 rows of `tools/audio/sources/*.toml` (all CC0, 28).

Picked 2026-10-16 (the five `picks_<family>_r2.json` exports): every round-2 sound has a pick, so no round 3. Only
note: grunt_c3 D "its bad but funny so keep it".

| Sound | What round 2 tries | Picked |
|---|---|---|
| grunt_c1 - c5 | Clean recorded grunts, varispeeded a few percent toward the survivor; no contour, formant shift, tremor or 7 kHz low-pass (round 1's muffle). D as recorded, E with a 2.5 kHz presence lift and light drive, F another take with a quick jolt. The women's takes (c3, c4) hold their pitch (analyze lists a line 17-23 dB over its neighbours): a voiced grunt, judged by ear. | c1 F, c2 E, c3 D, c4 D, c5 F |
| scare_glass_break | Every crack from a different recording or moment. D: B's crack, then three different shard cracks running. E: a hard hit on glass with cracks forming after. F: B's crack over ice, one long settling crack. | E |
| scare_alarm_evacuation | Real building fire alarms through the horns, no bells. D: a high-rise whoop (620-870 Hz rising), close. E: a university fire-drill sounder, slowed a fifth (less piercing). F: the whoop far down the corridors, the sounder under it. | F |
| lunge_cue | Three different things, none breath-and-bone. D: a creature's snarl rising into a swoosh. E: an effort grunt with a push-off stomp. F: no voice, the body: clothes, push-off scrape, swoosh. | F |
| lunge_hit | A low thud with cloth. D: punch, collapse thud, jacket. E: heavier slowed thud, cloth dragged. F: dulled blow, thump, two jacket moves. | E |
| distortion | Flesh and bone moving, no celery or crisp cracks. D: wet sponge squelches slowed, deep back pops. E: real joints slowed and rolled off at 1.8 kHz over the squelch. F: wet-led, one deep crack, a settling thud. | E |
| fuse_install | A fuse pushed into its clips, not a door. D: slide, clip snap, a breaker's clack. E: clip snap, a dual-pole breaker thrown. F: clip snap, a fuse switch, a short spark. | F |
| barricade_build | D: a plank slapped on, three blows. E: two planks clatter, a fast nail run. F: two mallet blows, the plank rattling, settling. | D |
| step_tile | New tile recordings. D: boots on tile, close mic. E: heavy boots on tile. F: D with a scrape just ahead. | D |

## States (2026-10-17)

`ClientSfx` sounds, family `state` (`tools/audio/review/states/`). Source: `picks (7).json`, 2026-10-17. Every sound
was picked and none has a note, so there is no next round.

| Sound | Ships |
|---|---|
| heartbeat | A |
| breath_sprint | A |
| flashlight_click | A |
| generator_spinup | B |
| terminal_tone | B |
| pa_chime | A |
| phase_investigation | B |
| phase_tick | A |
| phase_win | A |
| phase_loss | A |

## Events (2026-10-17)

Event and action sounds, family `event` (`tools/audio/review/events/`): `WorldSfx` (drive clatter and eject,
install alert, relay clack, rescue relief, eliminated sting), `HidingSpots` (search rattle), `BodySfx` (takedown
struggle, release gasp, collapse, interact, barricade and rescue loops) and `ClientSfx` (face unlock, ping tick and warning).
Source: `picks (8).json`, 2026-10-17. Every sound was picked and none has a note, so there is no next round.
`body_collapse` (BodySfx, a takedown completing) was added after that page and ships A until picked.

| Sound | Ships |
|---|---|
| drive_clatter | A |
| drive_eject | B |
| install_alert | A |
| relay_clack | B |
| rescue_relief | A |
| eliminated_sting | C |
| search_rattle | B |
| takedown_struggle | B |
| release_gasp | C |
| interact_loop | C |
| barricade_loop | A |
| rescue_loop | A |
| face_unlock | A |
| ping_tick | C |
| ping_warning | B |
| body_collapse | A (unpicked) |

## PA lines (2026-10-18)

Generated-voice stand-in (designer: "go with a generated voice for now"); page `tools/audio/review/pa/`. A Zira
through the ceiling horn, B David through the horn, C Zira through a smaller, harsher speaker.

| Sound | Ships |
|---|---|
| pa_evac_timed - pa_activation_done (15 lines) | A (unpicked) |
