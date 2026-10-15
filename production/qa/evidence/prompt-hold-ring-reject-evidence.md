# Evidence: hud-results story 003, interaction prompt, hold ring, reject label and input glyphs

`InteractionHud` (`src/feature/hud_results/interaction_hud.gd`) and `InputGlyphs`
(`src/core/ui/input_glyphs.gd`), wired in `RoundClient` in place of the greybox hold bar. Design:
`design/ux/hud.md` H7-H9 and the Z4 rule; `design/ux/interaction-patterns.md` P2, P3, P10, P18; ADR-0014 §6, §8.

## Captures (Godot 4.7.2, windowed 1152x648, `--write-movie <tmp>/f.avi --fixed-fps 30`, 2026-10-15)

Host: `round_host.gd -- --port=<p> --players=5`. View:
`round_view.tscn --windowed --write-movie <tmp>/f.avi --fixed-fps 30 --quit-after <n> -- --port=<p> --count=5
--view=survivor --bot=hold --shots=<tmp> [...]`.

1. `prompt-hold-ring-reject/01-prompt.png` (`--target=fuse_box`, port 30642): "Hold E  Install fuse" under the
   crosshair once the bot's view ray picks the fuse box, 10 drawn frames after it appeared (past the 150 ms fade-in).
2. `prompt-hold-ring-reject/02-ring.png` (hiding spot, `--release-at=0.5`, port 30641): the hold ring at half,
   driven by `PredictedHoldBar`; the prompt is replaced by the ring (Z4 holds one element).
3. `prompt-hold-ring-reject/03-cancel-released.png` (same run): the bot released interact at half; the ring is
   broken into segments (shape, not colour) and the cause "Released" shows below.
4. `prompt-hold-ring-reject/04-refusal.png` (`--target=fuse_box`): the survivor holds no fuse, so the server
   refuses the Start; the acknowledging snapshot shows no hold and "Not now" shows in Z5. Launcher log:
   `PRESS frame 592`, `HUD label 'Not now' at frame 600`. The prompt stays, because the target is still in range.

## Acceptance criteria

- AC1 (prompt with verb, object, glyph, Hold or Press; glyph follows the device): capture 01;
  `test_prompt_shows_verb_object_glyph_and_hold_or_press_and_switches_glyph` and the three InputGlyphs tests.
  Not captured in game: `project.godot` binds no gamepad event to any action, so a pad shows the
  `InputGlyphs.UNBOUND` glyph "?" until a controls pass adds pad bindings.
- AC2 (ring from the predicted hold, corrected by the echo; a cancel shows its cause): captures 02 and 03;
  `test_release_breaks_the_ring_for_200_ms_and_shows_its_cause`,
  `test_server_cancel_after_ack_is_interrupted_and_completion_has_no_label`. The broken ring lasts 200 ms; the cause
  label lasts 1 s per P3 (the story reads "200 ms", which is H8's animation column; inference, a ux-designer ruling
  settles it). The server sends no cancel reason, so a server cancel reads "Interrupted" (inference).
- AC3 (refusal label 1.5 s; one Z4 element): capture 04; `test_refused_start_shows_the_reject_label_for_1_5_s`,
  `test_ring_replaces_the_prompt_and_another_z4_element_replaces_both`, `test_wheel_suppresses_prompt_and_reject_label`.

## Sign-off

- [ ] Lead sign-off
