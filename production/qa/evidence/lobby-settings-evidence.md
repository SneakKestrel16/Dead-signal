# Lobby settings screen

`settings.png`: the Settings screen opened from the lobby form (interaction-patterns.md P15 / P21), 1280x720,
captured 2026-10-17 by the `--lobby-settings` autorun:

```bash
timeout 60 "$G" --path . --windowed --resolution 1280x720 -- --lobby-settings --lobby-shots=production/qa/evidence/lobby-settings
```

Two faults seen in the screenshot agent's earlier capture and fixed here:

- The 0.8-alpha backing let the lobby form (name, address, port, Host/Join) read through the settings rows. Over
  the lobby the backing is now opaque; over a round it stays 0.8 so the round shows (P15).
- HUD scale read 101% at its default: the slider step was range / 20 = 0.0375 from 0.75, which has no stop at 1.0,
  so the slider snapped to 1.0125. Percent-of-1 sliders now step 0.05 (5%); mouse and stick keep range / 20.

Tests: `tests/unit/settings/settings_screen_test.gd` `test_every_slider_opens_on_its_default`,
`test_backing_is_opaque_over_the_lobby_and_dim_over_a_round` (both fail without the fix).
