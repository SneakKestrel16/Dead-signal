"""Crop the concept's front figure and run TRELLIS image-large on it; writes a raw mesh per seed.

  TRELLIS/.venv/Scripts/python.exe -I gen_true_form.py <concept.webp> <outdir> [seed ...]
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TRELLIS = os.path.join(HERE, "TRELLIS")
os.environ.setdefault("ATTN_BACKEND", "sdpa")
os.environ.setdefault("SPARSE_ATTN_BACKEND", "xformers")  # served by the SDPA shim
os.environ.setdefault("SPCONV_ALGO", "native")
sys.path.insert(0, os.path.join(HERE, "local-3dgen", "engine", "shims"))
sys.path.insert(0, TRELLIS)

import numpy as np  # noqa: E402
import torch  # noqa: E402
import trimesh  # noqa: E402
from PIL import Image  # noqa: E402

src, out = sys.argv[1], sys.argv[2]
seeds = [int(s) for s in sys.argv[3:]] or [1]
os.makedirs(out, exist_ok=True)

# the concept sheet is two figures side by side; the front one stands in x 0-315 of 768
img = Image.open(src).convert("RGB")
w, h = img.size
crop = img.crop((0, 0, int(w * 315 / 768), h))
side = max(crop.size)
sq = Image.new("RGB", (side, side), crop.getpixel((4, 4)))
sq.paste(crop, ((side - crop.size[0]) // 2, 0))
sq = sq.resize((1024, 1024), Image.LANCZOS)
sq.save(os.path.join(out, "input.png"))

torch.hub.set_dir(os.path.join(TRELLIS, ".torch_hub"))
from trellis.pipelines import TrellisImageTo3DPipeline  # noqa: E402

pipe = TrellisImageTo3DPipeline.from_pretrained("microsoft/TRELLIS-image-large")
pipe.cuda()
pre = pipe.preprocess_image(sq)
pre.save(os.path.join(out, "input_cut.png"))
to_gltf = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]], dtype=np.float32)  # Z-up -> glTF Y-up
for seed in seeds:
	o = pipe.run(sq, seed=seed, formats=["mesh"], preprocess_image=True,
		sparse_structure_sampler_params={"steps": 25, "cfg_strength": 7.5},
		slat_sampler_params={"steps": 25, "cfg_strength": 3.0})
	m = o["mesh"][0]
	v = m.vertices.detach().float().cpu().numpy() @ to_gltf
	f = m.faces.detach().cpu().numpy()
	c = m.vertex_attrs[:, :3].detach().float().cpu().numpy()  # decoder colour (the other 3 are a normal)
	print("COLOUR range", c.min(0), c.max(0), flush=True)
	c = (np.clip(c, 0, 1) * 255).astype(np.uint8)
	mesh = trimesh.Trimesh(v, f, vertex_colors=np.concatenate([c, np.full((len(c), 1), 255, np.uint8)], 1), process=True)
	path = os.path.join(out, "true_form_s%d.glb" % seed)
	mesh.export(path)
	print("MESH", path, len(mesh.faces), "faces", torch.cuda.max_memory_allocated() // 2**20, "MiB peak", flush=True)
