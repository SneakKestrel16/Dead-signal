# TRELLIS true-form source

`assets/art/characters/shapeshifter/source/true_scan.glb` comes from these two scripts. `tools/art/build_true_scan.py`
rigs, bakes and exports it.

- **Model:** [microsoft/TRELLIS-image-large](https://github.com/microsoft/TRELLIS), MIT licence, run locally on an
  RTX 5070 (12 GB; seed 1 peaks at 10 GB). Hunyuan3D 2.1 was set aside: its licence §5(c) bars using output in the
  EU, UK and South Korea (designer, 2026-10-18).
- **Input:** the front figure of `design/art/reference/true-form-concept-01.webp`.
- **Setup** (outside the repo, `C:/Users/Ockey/ai3d`): a TRELLIS checkout and its `.venv` (torch cu128); local-3dgen's
  `engine/shims` (xformers and kaolin stand-ins) first on `sys.path`; `ATTN_BACKEND=sdpa`,
  `SPARSE_ATTN_BACKEND=xformers`, `SPCONV_ALGO=native`.

Both scripts expect the TRELLIS checkout beside them: copy them into the setup directory to run.

```sh
TRELLIS/.venv/Scripts/python.exe -I gen_true_form.py <concept.webp> out 1     # out/true_form_s1.glb, vertex colour
TRELLIS/.venv/Scripts/python.exe -I open_mesh.py out/true_form_s1.glb true_scan.glb 384 2
```

`open_mesh.py` strips the concept's wisps, which TRELLIS turns into thin sheets: a voxel opening with a ball of radius
2 voxels at 384³. The decoder's skin is double-walled around a hollow core that opens to the outside, so the solid is
filled per horizontal slice, not in 3D. Each output vertex takes its colour from the nearest raw vertex. The mesh is
scaled to 1.8 m. Seeds 2 and 3 grew more sheets than seed 1. A radius of 3 cut a leg off.

The colour is sRGB. glTF vertex colour is read as linear, so `build_true_scan.py` gammas it before the bake.
