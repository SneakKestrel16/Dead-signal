# PA countdown lines

**Status:** approved by the designer, 2026-10-18: keep the pause line, keep the final count, "go with a generated
voice for now". Built: `tools/audio/sounds/pa.py` (bank ids `pa/<id without pa_>`), played by `ClientSfx`.

The facility's automated public-address system speaks during Evacuation (scare-events.md row "Evacuation –
Emergency": alarm loop, PA countdown). Every announcement
opens on `pa_chime` (picks.md, A); the countdown words come bare. Captions use the same text
(accessibility-requirements.md, captions for PA, off by default).

## Voice

A recorded, pre-crash facility system: flat, clinical, mid-pitch, no emotion and no urgency of its own. The horror
is the calm. Each line is short (under about 3 s), stays in the present tense and never names a person or a
monster. Grounded only (README rules): an old building PA through ceiling horns, slightly band-limited, with a
room tail.

Source (designer, 2026-10-18): a generated voice for now. `tools/audio/tts.py` renders every line with Windows
text-to-speech (Microsoft Zira and David, System.Speech) into `tools/audio/sources/tts/`, committed so the build
stays offline. This is a stand-in: an exception to the README's real-recordings rule until a recorded read
replaces it. Candidates on the review page (`uv run tools/audio/review.py pa`): A Zira through the ceiling horn
(ships), B David through the horn, C Zira through a smaller, harsher speaker.

## Lines

Triggers come from Match Flow (round clock, `round_duration_s` = 540, Evacuation 7:00-9:00, rule 6) and
Survivor Objectives (activation rules 19-20). Times are round-clock remaining.

| ID | Trigger | Line |
|---|---|---|
| pa_evac_timed | Evacuation starts at 7:00 (rule 6a) | "Attention. Facility evacuation is now in effect. All personnel proceed to the evacuation terminal." |
| pa_evac_armed | Evacuation starts early: terminal armed (rule 6b) | "Attention. Power restored. Evacuation terminal is armed." |
| pa_t_120 | 2:00 remaining (only when Evacuation started early) | "Two minutes to facility lockdown." |
| pa_t_60 | 1:00 remaining | "One minute to facility lockdown." |
| pa_t_30 | 0:30 remaining | "Thirty seconds." |
| pa_t_10 | 0:10 remaining | "Ten seconds." |
| pa_count_5 ... pa_count_1 | 0:05 to 0:01 remaining | "Five." "Four." "Three." "Two." "One." |
| pa_lockdown | Deadline reached (rule 8), no escape | "Lockdown complete. Evacuation is closed." |
| pa_activation_start | Activation countdown starts (rule 19) | "Evacuation sequence initiated. Remain at the terminal." |
| pa_activation_paused | Countdown pauses: no Healthy survivor in the zone (state table, Activating) | "Sequence paused. Operator absent." |
| pa_activation_done | Countdown reaches 0, exit opens (rule 20) | "Evacuation sequence complete. Exit doors open." |

"Lockdown" is the PA's word for the evacuation deadline. Match Flow calls it "Evacuation deadline expired"
(rule 23). It is a fiction word only and changes no rule.

## Decisions

- **pa_activation_paused** stays (designer, 2026-10-18), although it tells the shapeshifter the terminal is empty.
- **pa_count_5 to pa_count_1** stay (designer, 2026-10-18), over the alarm and the final-30 s tick.
- The 2:00 chime ClientSfx played before (pa_chime alone) is replaced: each announcement now opens on that chime.
- Captions: the Captions setting (off by default) puts each line in the feed as `PA: [text]`, no arrow (hud.md
  H18). The caption text is `ClientSfx.PA_TEXT`: change it with this page and `sounds/pa.py`.
