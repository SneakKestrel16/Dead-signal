# Evidence: interactable and hero props (ASSET-052..064)

Spec: `design/assets/specs/research-facility-assets.md` (ASSET-052..064); art bible §3, §4, §6, §8.
Built by `tools/art/build_props.py` (Blender 5.2, background). Each PNG is a Cycles render in near-dark
(ambient Void Charcoal `#14181A`) under one warm Bone Flashlight `#F2E6C8` spot from about eye height.
The steel bodies show the shared steel-plate tileable box-projected; in game they get `mat_steel_plate_a.tres`.

| Prop | Tris | Budget | Render |
|---|---|---|---|
| prop_data_drive | 116 | 800 | prop_data_drive.png |
| prop_fuse | 456 | 600 | prop_fuse.png |
| prop_fuse_box | 336 | 1500 | prop_fuse_box.png |
| prop_terminal (hero) | 640 | 8000 | prop_terminal.png |
| prop_exit_door (hero frame) + prop_exit_lamp | 500 + 44 | 8000 | prop_exit_door.png (lens shown lit) |
| prop_hide_cabinet | 308 | 1500 | prop_hide_cabinet.png |
| prop_hide_locker | 280 | 1500 | prop_hide_locker.png |
| prop_light_switch | 96 | 300 | prop_light_switch.png |
| prop_camera | 180 | 800 | prop_camera.png |
| prop_monitor_wall (hero) | 832 | 8000 | prop_monitor_wall.png |
| prop_core (hero) | 708 | 8000 | prop_core.png |
| prop_breaker_wall (hero) | 1844 | 8000 | prop_breaker_wall.png |

Placement: `tests/unit/facility-map/map_props_test.gd`. In-game screenshots: still to be taken (orchestrator).

- [ ] Lead sign-off (art-director)
