# Evidence: match-flow story 011, client round scene

`RoundClient` (`src/feature/match_flow/round_client.gd`), launched by `tests/manual/round_view.tscn` against
`tests/manual/round_host.gd` (5 players, real ENet on 127.0.0.1). Greybox floors come from `MapGreybox`
(`src/core/facility/map_greybox.gd`). Godot 4.7.2, windowed, `--write-movie <tmp>/f.avi`, 2026-10-15.
Each screenshot is the drawn frame, saved after `RenderingServer.frame_post_draw`.

## Captures (`client-round-scene/`)

1. `survivor-view.png`: a survivor's predicted first-person view, 18.7 s into the round
   (`--fixed-fps 30`, frame 560, `--view=survivor --bot=look --light`). It shows two other survivors drawn
   in their appearance colours (green and purple), the greybox floor, and the own flashlight cone on the
   nearest body.
2. `monster-view.png`: the shapeshifter's view in the same kind of round (`--view=monster --bot=look`,
   frame 560). It shows the greybox floor, door posts (brown) and interactable posts (blue). No survivor
   is drawn: none was in the monster's replication scope at that moment. The client only draws handles
   the newest snapshot carries.
3. `hold-press-frame617.png` and `hold-bar-frame621.png`: the CI-16 capture (see
   `predicted-hold-bar-evidence.md`). The first is the frame of the press; the second shows the bar under
   the view centre 4 frames later.

4. `client-view-ci13-chain.png`: a survivor's view after the CI-13 wiring was added (camera chain
   body -> head -> CameraFx -> Camera3D, ClientEventRouter feeding ViewOffsetChanged and ScareTriggered,
   flinch toggle sent on join). It was taken at frame 560 at 30 fps and shows two survivors (green,
   yellow) and the own flashlight cone. It shows no flinch, flash or shake: the screenshots for those
   belong to CI-13.

## Commands

```text
<godot> --headless --path . -s res://tests/manual/round_host.gd -- --port=24742 --players=5
<godot> --path . res://tests/manual/round_view.tscn --windowed --write-movie <tmp>/f.avi --fixed-fps 30 \
    --quit-after 600 -- --port=24742 --count=5 --view=survivor --bot=look --light --shot-at=560 --shots=<tmp>
```

## Known gap

The server rejects every non-door hold Start a client sends. `HoldService._resolve` requires
`InputFrame.interact_target` to equal the HoldService net id under the server's ray
(`RoundComposer._aim`). Nothing sends that id table (map index to net ids, `RoundComposer._ids_at`) to
clients, so a client cannot fill it in. The predicted bar appears on the press tick and hides at the
acknowledging snapshot. Settling this needs a decision on the protocol: replicate the table at round
start, or let the client name the map index.
