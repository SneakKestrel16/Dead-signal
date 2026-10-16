# Character animation clips (ASSET-008, ASSET-010): evidence

Contact sheets rendered by `tools/art/build_anims.py` in Blender `--background` (Workbench, LOD0 only, side
view from the body's left), from the exported `char_survivor_body.glb` and `char_shapeshifter_true.glb`. Each
png shows 4 frames evenly spaced over the clip, left to right. No in-engine capture was taken: the run
environment allowed no windowed Godot.

| Clip | Source | Sheet | Driven in game by |
|------|--------|-------|-------------------|
| Downed (loop) | authored | `char_survivor_body_Downed.png` | crawl gait, still |
| Crawl (loop) | authored | `char_survivor_body_Crawl.png` | crawl gait, moving |
| Stand_Up | authored | `char_survivor_body_Stand_Up.png` | crawl gait ends (rescued) |
| Hit_Chest | UAL library | `char_survivor_body_Hit_Chest.png` | shock stagger (survivor or disguise) |
| Call_Help | authored | `char_survivor_body_Call_Help.png` | not driven: no client state |
| Seized (loop) | authored | `char_survivor_body_Seized.png` | not driven: no client state |
| Hide_Enter, Hide_Exit | authored | `char_survivor_body_Hide_Enter.png`, `_Hide_Exit.png` | not driven: no client state |
| Death01 (Eliminated) | UAL library | `char_survivor_body_Death01.png` | not driven: body removed at once |
| Fixing_Kneeling (kneel rescue) | UAL library | `char_survivor_body_Fixing_Kneeling.png` | not driven: no remote hold state |
| Push (barricade build) | UAL library | `char_survivor_body_Push.png` | not driven: no remote hold state |
| Interact | UAL library | `char_survivor_body_Interact.png` | not driven: no remote hold state |
| Lunge_Coil | authored | `char_shapeshifter_true_Lunge_Coil.png` | LungePresenter coil |
| Lunge_Dash | authored | `char_shapeshifter_true_Lunge_Dash.png` | follows the coil |
| Lunge_Stumble | authored | `char_shapeshifter_true_Lunge_Stumble.png` | LungePresenter stumble (miss) |
| Punch_Cross (lunge hit) | UAL library | `char_shapeshifter_true_Punch_Cross.png` | LungePresenter hit-stop |
| Hit_Head (stun stagger) | UAL library | `char_shapeshifter_true_Hit_Head.png` | stun stagger (true form) |
| Takedown_Pin (loop) | authored | `char_shapeshifter_true_Takedown_Pin.png` | not driven: no client state |

- [ ] Lead sign-off (art-director): poses read at gameplay distance
