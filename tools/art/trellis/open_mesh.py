"""Strip thin sheets off a raw mesh: voxelize solid, binary opening (ball radius r voxels), keep the largest piece,
marching cubes back to a mesh.

  python -I open_mesh.py <in.glb> <out.glb> <res> <r>
"""
import sys

import numpy as np
import trimesh
from scipy import ndimage
from scipy.spatial import cKDTree
from skimage import measure

src, out, res, r = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
mesh = trimesh.load(src, force="mesh")
pitch = mesh.extents.max() / res
vox = mesh.voxelized(pitch)
ball = np.linalg.norm(np.indices((2 * r + 1,) * 3) - r, axis=0) <= r
# TRELLIS skins are double-walled round a hollow core open to the outside, so a 3D fill leaks: fill each
# horizontal (glTF Y-up) cross-section in 2D instead
shell = np.pad(vox.matrix, r + 2)
solid = shell.copy()
for y in range(shell.shape[1]):
	solid[:, y, :] = ndimage.binary_fill_holes(shell[:, y, :])
solid = ndimage.binary_opening(solid, structure=ball)
solid = ndimage.binary_fill_holes(ndimage.binary_closing(solid, iterations=2))  # pinholes where a slice ring broke
lab, n = ndimage.label(solid)
keep = lab == (np.argmax(np.bincount(lab.ravel())[1:]) + 1)
v, f, _, _ = measure.marching_cubes(keep.astype(np.float32), 0.5)
v = (v - (r + 2)) * pitch + vox.transform[:3, 3]
m = trimesh.Trimesh(v, f[:, ::-1], process=True)
trimesh.smoothing.filter_taubin(m, iterations=40)
# colour from the nearest raw vertex; then 1.8 m tall, feet at y=0, centred in x/z (glTF Y-up)
col = mesh.visual.vertex_colors[cKDTree(mesh.vertices).query(m.vertices)[1]]
lo, hi = m.bounds
k = 1.8 / (hi[1] - lo[1])
m.vertices = (m.vertices - [(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2]) * k
m.visual.vertex_colors = col
m.export(out)
print("OUT", out, len(m.faces), "faces", n, "pieces")
