# Evidence: hud-results story 005, edge cues, flinch-off pulse, taser count and world progress bars

`EdgeCues`, `TaserCount`, `WorldProgress` (server provider) and `WorldProgressBars` in
`src/feature/hud_results/`, wired in `RoundClient` and `RoundComposer`. Design: `design/ux/hud.md` H11, H13, H14
(I28, I32); `design/ux/interaction-patterns.md` P4, P8; ADR-0014, ADR-0015 §4.

## Captures (Godot 4.7.2, windowed 1152x648, `--write-movie <tmp>/f.avi --fixed-fps 30`, 2026-10-15)

Host: `round_host.gd -- --port=<p> --players=5`. View:
`round_view.tscn --windowed --write-movie <tmp>/f.avi --fixed-fps 30 --quit-after <n> -- --port=<p> --count=5
--view=survivor --shots=<tmp> [...]`.

1. `edge-cues-items-progress/lunge-chevron.png` (`--bot=lunge`, port 30660): the lunge wind-up chevron at the
   top edge, toward the shapeshifter (red body ahead) mid wind-up (the bot's `windup.png`).
2. `edge-cues-items-progress/transform-arc.png` (`--bot=stage --disguise --stun`, port 30661): the transform
   arc at the top edge while the shapeshifter in the line ahead transforms (`warp-early.png`).
3. `edge-cues-items-progress/taser-after-shot.png` (same run): "Taser × 1" in Z7 after the shown survivor's
   shot (`stagger.png`); every earlier capture shows "Taser × 2" (`stun_item_charges`).
4. `edge-cues-items-progress/flinch-off-pulse.png` (`--bot=stage --scare-audio --no-flinch`, port 30663): the
   soft-glow pulse at the top edge toward the Blackout scare origin (launcher log: `SCARE blackout intensity 0
   ... bearing -8.8 deg`), the frame after the pulse finished its 150 ms fade-in.
5. `edge-cues-items-progress/world-bar-paused-synthetic.png` (`--bot=hold --target=drive --fake-paused`, port
   30664): **synthetic entry**, not server data: `--fake-paused` feeds one PROGRESS payload (activation, 40 %,
   paused) to the shown client's `WorldProgressBars` to capture the label render, "[||||......] 40%  Paused".

## Acceptance criteria

- AC1 (chevron at 19 m, not at 21 m, toward the source): capture 1;
  `test_lunge_chevron_shows_at_19_m_and_not_at_21_m`, `test_lunge_chevron_points_toward_the_source`.
- AC2 (flinch off: P8 pulse instead, server view offset path unchanged): capture 4;
  `test_flinch_off_major_scare_shows_the_pulse_toward_the_origin`,
  `test_server_view_offset_path_is_unchanged_with_flinch_off`.
- AC3 (taser count within one snapshot; world bar with percent and "Paused"): captures 3 and 5;
  `test_taser_count_follows_the_charges_entry_in_the_same_batch`, the three provider tests and
  `test_bars_show_percent_and_paused_from_server_progress`.

## Gaps

- No capture of a live server-driven world bar: no bot reaches a real objective hold in the greybox round
  (`--target=drive` picks an inactive console and is refused, "Not now"; hiding holds are deliberately not
  sent). A bot walking to an active drive console, or to the armed terminal, would settle it.
- Layout: the top-edge cues sit over the H1 clock (Z2) when the source is straight ahead (capture 4). Greybox
  placement; the art pass decides whether Z8 insets past Z2.

## Sign-off

- [ ] Lead sign-off
