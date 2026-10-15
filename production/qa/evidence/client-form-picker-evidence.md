# Evidence: Shipped client form picker (story borrowed-face/011)

**Story**: `production/epics/borrowed-face/story-011-client-form-picker.md` (UI)
**Spec**: `design/gdd/borrowed-face.md` rules 6-9, 14; `design/ux/hud.md` S1; `design/ux/interaction-patterns.md` P6, P10; ADR-0014 §1-§3
**Captured**: 2026-10-15, Godot 4.7.2, 1280x720, `--write-movie` (drawn frames, not wall seconds)

## How it was captured

```
godot --headless --path . -s res://tests/manual/round_host.gd -- --port=30782 --players=5
godot --path . --resolution 1280x720 --write-movie <tmp>.avi --quit-after 2400 res://tests/manual/round_view.tscn -- \
    --port=30782 --count=5 --view=monster --bot=picker --shots=production/qa/evidence/client-form-picker
```

`--bot=picker` (added to `tests/manual/round_view.gd` for this story) drives the shown shapeshifter client's
shipped `FormPicker` (mounted by `RoundClient`): `open()`, `aim()` and `close(true)` are what holding and
releasing the `form_picker` action (T; was R, moved because MA-11 bound False Signal to R) call. The request goes out through the picker's own send path, not a raw
packet from the harness. This is round_host + round_view, not the lobby-to-round path; both build the same
`RoundClient`.

## Screenshots

| File | State | What it shows | Printed value at the shot |
|---|---|---|---|
| `client-form-picker/picker.png` | True form, picker open | Wheel: "True form Current" (top, grey), C2 and C5 available (white), C1 and C3 "Unavailable" (grey, matching S1 bars not yet full); C2 aimed (box) | entries with available = [false, false, true, false, true], selection 2 |
| `client-form-picker/disguised.png` | Disguise complete | S2 "Form: C2 12" (form cooldown running), picker closed | form cooldown 11.5 s |
| `client-form-picker/picker-disguised.png` | Disguised, picker open | "C2 Current" greyed, True form, C1, C3, C5 available; True form aimed | entries with C2 current |
| `client-form-picker/refused.png` | True form requested inside the cooldown | HUD-3 label "Not now" under the crosshair; no transformation started | label at 11 drawn frames after the send, transform progress -1 |

## Observations

- The top segment (True form) sits over the H1 phase line in Z2 while the wheel is open; the callout wheel uses
  the same radius. A layout ruling (ux-designer) settles whether the wheel should shrink or the HUD dim under it.
- The S1 face list and the H4 roster overlap in Z1 (pre-existing, hud-results 002/006), visible in every shot.
- Only the cooldown refusal is shown live. Stun and lunge refusals go through the same inferred path (no
  transformation by the deadline) and are covered by
  `tests/unit/borrowed-face/client_form_picker_test.gd` only.

## Sign-off

- [ ] Lead sign-off (UI screenshots reviewed)
