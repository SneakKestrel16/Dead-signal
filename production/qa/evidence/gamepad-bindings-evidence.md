# Evidence: hud-results/012 gamepad bindings

Story: `production/epics/hud-results/story-012-gamepad-bindings.md`. Date: 2026-10-15. Godot 4.7.2.

Host: `round_host.gd -- --port=30882 --players=5`. View:
`round_view.tscn --windowed --write-movie <tmp>/f.avi --fixed-fps 30 --quit-after 900 -- --port=30882 --count=5
--view=survivor --bot=hold --pad --shots=<tmp>`. `--pad` feeds a synthetic InputEventJoypadButton (A, bound to no game
action) through `Input.parse_input_event` each frame until the prompt shot.

| Shot | Shows |
|---|---|
| [prompt-pad.png](gamepad-bindings/prompt-pad.png) | Interaction prompt `Hold X  Hide`: the pad glyph X (interact on JOY_BUTTON_X), where the key glyph is `E` |

Log: `HUD prompt: 'Hold X  Hide' label ''`.

Not shown: the wheel on the right stick (AC2) has no new screenshot; the stick steering is the existing
PingCalloutHud.steer_wheel path, now reachable because callout_wheel is bound to LB.

- [ ] Lead sign-off
