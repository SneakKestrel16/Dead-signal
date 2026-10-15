# Evidence: Own-state vignettes, own bleed-out and the HUD state table (story hud-results/004)

**Story**: `production/epics/hud-results/story-004-own-state-and-hud-states.md` (UI)
**Spec**: `design/ux/hud.md` H15, H16, HUD States by Gameplay Context; interaction-patterns P11; ADR-0014 §6
**Captured**: 2026-10-15, Godot 4.7.2, 1280x720 windowed (no `--write-movie`: the capture waits out the real 60 s bleed-out)

## How it was captured

```
godot --headless --path . -s res://tests/manual/round_host.gd -- --port=30746 --players=5
godot --path . --resolution 1280x720 --quit-after 20000 res://tests/manual/round_view.tscn -- \
    --port=30746 --count=5 --view=survivor --bot=ownstate --shots=production/qa/evidence/own-state-and-hud-states
```

`--bot=ownstate` (added to `tests/manual/round_view.gd` for this story) reaches every state through the real
server: the shown survivor hides in the nearest hiding spot and leaves it, the shapeshifter's client walks at it
and lunges (Seized in the 1.5 s commit, then Downed), everyone else walks away so no camping slow stretches the
bleed-out, and after the 60 s bleed-out the server makes it a spectator. The host was stopped after the view quit.

## Screenshots

| File | State (flag) | What it shows | Printed at the shot |
|---|---|---|---|
| `own-state-and-hud-states/hidden.png` | Hidden (`--bot=ownstate` step 0) | Crosshair hidden, prompt "Hold E  Leave" only, no vignette, roster/clock/checklist stay. ("Released" under it is HUD-3's cause label for the hide hold the bot let go.) | `state hidden prompt 'Hold E  Leave' crosshair false` |
| `own-state-and-hud-states/seized.png` | Seized (step 2) | Tight dark edges and the word "Seized"; no prompt or ring; crosshair stays (state table: Seized hides prompt and ring only). The red shape is the shapeshifter's body in the face. | `word 'Seized' vignette 0.79 z4 ''` |
| `own-state-and-hud-states/downed.png` | Downed (step 3) | Wide grey edges, "Downed", own bleed-out "60 s" in the prompt's place, crosshair hidden, roster "✚ Downed" and checklist stay | `word 'Downed' bleed '60 s' z4 '' crosshair false` |
| `own-state-and-hud-states/spectating.png` | Spectating (step 4) | "Spectating: View2" under the clock; roster "○ Eliminated", clock, objectives; no prompt, ring or crosshair; `can_act` false (no ping, no wheel) | `'Spectating: View2' watched 2 can_act false z4 ''` |

## Known defects seen in the capture

- **The spectator's 3D view is black.** RoundClient has no spectator camera: OwnerPredictor replays the
  spectator's never-acknowledged inputs on top of the watched survivor's own entry, so the body falls away
  below the map (measured: y about -18000 m after 10 s). The bot tried to pin the head on the entry for the
  shot without success. The HUD under test draws correctly over it. A client spectator view is needed
  (hud.md "spectator spec: open gap").
- **Kit (H11) still shows while spectating** ("Taser × 2"): the spectator's stream carries the watched
  survivor's CHARGES. The state table says no kit; TaserCount does not read HudModel yet.
- Vignette look is a PLACEHOLDER (edge bands, not P11's desaturating shader); the art pass replaces it.

## Not shown

- Shocked: covered by `tests/unit/hud-results/own_state_and_hud_states_test.gd`
  (`test_shocked_shows_word_and_jitter_jitter_off_with_reduced_motion`) only.
- Rescue ring in H16: nobody rescues in the capture; unit-tested (`test_downed_shows_vignette_word_...`).
- The 250 ms transition and the reduced-motion cut: unit-tested (`test_vignette_takes_250_ms_and_cuts_with_reduced_motion`).

## Sign-off

- [ ] Lead sign-off (UI screenshots reviewed)
