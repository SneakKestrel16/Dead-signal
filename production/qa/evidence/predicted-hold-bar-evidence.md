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

- [x] Lead sign-off: designer, 2026-10-15 (captures 01 and 02 reviewed). The 240 fps capture for AC1 is still not done: it needs a client round scene.

## 240 fps capture for AC1 (match-flow story 011, 2026-10-15)

Run: `round_host.gd --players=5` and `round_view.tscn --windowed --write-movie <tmp>/f.avi --fixed-fps 240
--quit-after 2400 -- --count=5 --view=0 --bot=hold --light --latency-ms=150`. Client 0 joins through
`UdpLink` (tests/helpers/udp_link.gd) at 75 ms each way, so the round trip is 150 ms. The bot walks a
survivor to the nearest hiding spot, aims at it and holds interact.

The launcher printed:

```text
PRESS frame 617 target 27
BAR frame 621: 4 drawn frames after the press
```

4 frames at 240 fps is 16.7 ms, one 60 Hz physics tick. The limit is 100 ms. Frames:
`client-round-scene/hold-press-frame617.png` (no bar) and `client-round-scene/hold-bar-frame621.png`
(bar under the view centre). Two other runs gave 621 -> 625 and 1101 -> 1105.

Caveats:

- Movie mode ran at 32% of real time, but the 150 ms shim delays packets in real time. This makes no
  difference to the result, because the bar never waits for the network.
- The server did not accept the Start, so the press was not *valid* in the AC's sense. The client sends
  no `interact_target` net id (see `client-round-scene-evidence.md`, Known gap), so the bar hides at the
  ack. The measured delay is the same for an accepted Start: the bar appears on the press tick from the
  local target query alone.

## Accepted Start, bar completes (AD-217, 2026-10-15)

AD-217 makes a non-body `interact_target` the map interactable index; the client now stamps it, and the
server picks the first eligible hold at that object. Rerun (real time, not movie mode; host on
`--port=24790`, which is now outside the manual-capture range 30000-30999: use that range for reruns):
`round_view.tscn --windowed --quit-after 3000 -- --count=5 --view=0 --bot=hold --light --latency-ms=150`.

```text
PRESS frame 365 target 27
BAR frame 366: 1 drawn frames after the press
SERVER HOLD net id 45 at frame 391 (bar visible true)
BAR FULL at frame 485 (server hold net id 45)
```

The server accepted the Start on map index 27 as hold net id 45 (the spot's Hide; index and net id
differ), the bar stayed visible at the ack and filled. Frame: `client-round-scene/hold-bar-full-frame485.png`
(the full bar under the view centre). The caveat above that the press was not valid no longer applies.
