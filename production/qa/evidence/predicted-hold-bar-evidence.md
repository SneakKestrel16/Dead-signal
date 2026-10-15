# Evidence: controller-interaction story 016, predicted hold bar

Greybox `PredictedHoldBar` (`src/core/controller/predicted_hold_bar.gd`), ADR-0008 §8.

## Captures (Godot 4.7.2, windowed 1280x720, 2026-10-14)

1. `predicted-hold-bar/01-predicted-bar-before-ack.png`: press with a local target on a 2 s hold, then
   18 ticks (150 ms each way at 60 Hz) with no snapshot. The bar is drawn at 19/120 = 0.158.
2. `predicted-hold-bar/02-rejected-start-bar-gone.png`: the same bar after an own snapshot that
   acknowledges the press and shows no hold. The bar is gone and never showed more than its predicted value.

The scene was built by a throwaway capture script (not committed). It added the bar, a crosshair
and a background to the root, called `advance()` and `on_snapshot()`, and saved the viewport after
30 rendered frames.

## Acceptance criteria

- AC1 (bar shows ≤ 100 ms after a valid Start under 150 ms latency): the bar is visible on the press tick
  itself, before any snapshot, so the delay is at most one physics tick (16.7 ms at 60 Hz). See
  `test_bar_appears_on_the_press_tick_under_150ms_latency`. The 240 fps capture measurement in the AC
  is manual and has not been done. It needs a two-client build with a client scene that wires the bar.
- AC2 (a rejected Start cancels at the ack with no progress flash): see
  `test_rejected_start_cancels_at_the_ack_without_progress_flash` and capture 02.

## Sign-off

- [ ] Lead sign-off: pending
