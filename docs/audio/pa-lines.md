# PA countdown lines (draft)

**Status:** draft for designer approval, 2026-10-18. No audio is made until the text is approved.

The facility's automated public-address system speaks during Evacuation (scare-events.md row "Evacuation –
Emergency": alarm loop, PA countdown). Every line follows `pa_chime` (picks.md, A). Captions use the same text
(accessibility-requirements.md, captions for PA, off by default).

## Voice

A recorded, pre-crash facility system: flat, clinical, mid-pitch, no emotion and no urgency of its own. The horror
is the calm. Each line is short (under about 3 s), stays in the present tense and never names a person or a
monster. Grounded only (README rules): an old building PA through ceiling horns, slightly band-limited, with a
room tail. No synthetic robot voice.

Source route, to settle after approval: a CC0 / CC BY recorded voice reading these lines, or the designer's own
read, processed through a PA horn chain. A text-to-speech voice would break the "real recordings" rule; that is
inference from the README rule and a designer ruling settles it.

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

## Open choices

- **pa_activation_paused** speaks the pause aloud to the whole map, the shapeshifter included. That tells it the
  terminal is empty. Cut the line if that is too much information; the HUD activation countdown (hud.md H3)
  still shows the pause.
- **pa_count_5 to pa_count_1** overlap the alarm and the final seconds of play. Drop them if the last five seconds
  read better with the alarm alone.
