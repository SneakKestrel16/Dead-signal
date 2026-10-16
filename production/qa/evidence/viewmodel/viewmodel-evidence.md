# Viewmodel evidence (ASSET-011..014)

Blender Cycles background renders from `tools/art/build_viewmodel.py` (camera at the eye, 75 degree vertical
FOV like the Godot Camera3D default, warm Bone Flashlight spot on the camera as in RoundClient, near-dark world).
Not an in-engine capture: no windowed Godot run was allowed for this story.

- `viewmodel_vm_idle.png`: flashlight left, taser right (look 2 sleeve), two cartridges in the window.
- `viewmodel_vm_idle_light.png`: no cartridges, flashlight only (look 3).
- `viewmodel_vm_reach.png`: interact reach, right hand open (look 4).
- `prop_flashlight.png`, `prop_taser.png`, `prop_dart.png`: the props alone.

Tris: arms 7839 (budget 8000), flashlight 592, taser 156 (with cartridges), dart 66.

- [ ] Lead sign-off (art-director)
- [ ] In-engine screenshot (round_view, survivor) once a windowed run is allowed
