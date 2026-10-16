"""Build the research-facility environment textures (ASSET-015..030).

Run from the repo root (re-runnable; downloads are cached):
    blender --background --factory-startup --python tools/art/build_textures.py

CC0 sources (Poly Haven, ambientCG; AD-248) are downloaded to tools/art/.cache/
(gitignored), then processed to art bible §4/§6/§8: albedo desaturated and
clamped to sRGB 32-225, normals OpenGL (Y+), ORM packed R=occlusion
G=roughness B=metallic. What no source covers is procedural (numpy).
Every source is written to assets/art/CREDITS.md.

Scale: tileables are 1024 px = 4 m (256 px/m, art bible §6). Trims are
2048 px = 8 m. Value ranges per surface are the art bible §4 inference ranges.
"""
import bpy
import colorsys
import json
import os
import urllib.request
import zipfile

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CACHE = os.path.join(ROOT, "tools", "art", ".cache")
ENV = os.path.join(ROOT, "assets", "art", "environment")
FETCH_DATE = "2026-10-15"
UA = {"User-Agent": "DeadSignal-art-pipeline/1.0"}
TILE_MM = 4000.0  # 1024 px tileable covers 4 m

# id -> (site, assumed size in mm when the API gives none)
SOURCES = {
    "dirty_tiles": ("polyhaven", None),
    "concrete_floor_worn_001": ("polyhaven", None),
    "concrete_block_wall_03": ("polyhaven", None),
    "blue_metal_plate": ("polyhaven", None),
    "OfficeCeiling006": ("ambientcg", None),
    # ambientCG lists 0 x 0 mm for these; sizes are inference (a 2 m plate
    # sheet, a 1 m walkway panel). Settle by eye in the greybox.
    "DiamondPlate008A": ("ambientcg", 2000.0),
    "MetalWalkway010": ("ambientcg", 1000.0),
}
credits = []

# ---------------------------------------------------------------- I/O


def fetch(url, dest):
    if not os.path.exists(dest):
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=300) as r, open(dest + ".part", "wb") as f:
            f.write(r.read())
        os.replace(dest + ".part", dest)
    return dest


def fetch_json(url, dest):
    with open(fetch(url, dest), encoding="utf-8") as f:
        return json.load(f)


def load(path, size):
    """Image file -> float32 HxWx4 in 0..1, top row first, resized to size."""
    img = bpy.data.images.load(path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    if tuple(img.size) != (size, size):
        img.scale(size, size)
    a = np.empty(size * size * 4, np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    return a.reshape(size, size, 4)[::-1].copy()


written = []


def save(name, sub, a):
    """Write HxWx{3,4} 0..1 array as PNG under assets/art/environment/<sub>/."""
    h, w = a.shape[:2]
    if a.shape[2] == 3:
        a = np.dstack([a, np.ones((h, w))])
    path = os.path.join(ENV, sub, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = bpy.data.images.new("out", w, h, alpha=True)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(np.ascontiguousarray(a[::-1], np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    write_import_stub(path, normal=name.split("_")[-2] == "normal")
    written.append((path, w, h))


def write_import_stub(path, normal):
    """Pre-seed Godot import params (art bible §8): VRAM compressed, mipmaps on,
    BC7 (high quality) for albedo/ORM, normal-map (RGTC/BC5) for normals.
    Godot keeps existing [params] and fills in uid/dest on import."""
    imp = path + ".import"
    if os.path.exists(imp):
        return
    hq = "false" if normal else "true"
    nm = 1 if normal else 2
    with open(imp, "w", newline="\n") as f:
        f.write(
            '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
            f"compress/mode=2\ncompress/high_quality={hq}\ncompress/normal_map={nm}\n"
            "mipmaps/generate=true\ndetect_3d/compress_to=0\nprocess/fix_alpha_border=true\n"
        )


def source(sid, px=1024):
    """Download a CC0 texture set; return maps resized so the 1024 tile is 4 m."""
    site, assumed = SOURCES[sid]
    c = os.path.join(CACHE, sid)
    files = {}
    if site == "polyhaven":
        info = fetch_json(f"https://api.polyhaven.com/info/{sid}", os.path.join(c, "info.json"))
        fl = fetch_json(f"https://api.polyhaven.com/files/{sid}", os.path.join(c, "files.json"))
        for key, m in (("Diffuse", "albedo"), ("nor_gl", "normal"), ("arm", "arm")):
            url = fl[key]["1k"]["jpg"]["url"]
            files[m] = fetch(url, os.path.join(c, url.rsplit("/", 1)[1]))
        mm = float(info["dimensions"][0])
        name, page = info["name"], f"https://polyhaven.com/a/{sid}"
    else:
        meta = fetch_json(
            f"https://ambientcg.com/api/v2/full_json?id={sid}&include=downloadData",
            os.path.join(c, "info.json"),
        )["foundAssets"][0]
        dl = next(
            d
            for d in meta["downloadFolders"]["default"]["downloadFiletypeCategories"]["zip"]["downloads"]
            if d["attribute"] == "1K-JPG"
        )
        z = fetch(dl["downloadLink"], os.path.join(c, dl["fileName"]))
        with zipfile.ZipFile(z) as zf:
            for member in zf.namelist():
                base = os.path.basename(member)
                for suffix, m in (("_Color.jpg", "albedo"), ("_NormalGL.jpg", "normal"),
                                  ("_Roughness.jpg", "rough"), ("_AmbientOcclusion.jpg", "ao"),
                                  ("_Metalness.jpg", "metal"), ("_Opacity.jpg", "opacity")):
                    if base.endswith(suffix):
                        out = os.path.join(c, base)
                        if not os.path.exists(out):
                            with open(out, "wb") as f:
                                f.write(zf.read(member))
                        files[m] = out
        mm = assumed or float(meta.get("dimensionX") or 1000)
        name, page = meta["displayName"], f"https://ambientcg.com/view?id={sid}"
    if (name, page, site) not in credits:
        credits.append((name, page, site))
    tiles = max(1, round(TILE_MM / mm))
    size = px // tiles
    s = {}
    for m, p in files.items():
        a = np.tile(load(p, size), (tiles, tiles, 1))
        s[m] = a[..., :3] if m in ("albedo", "normal", "arm") else a[..., 0]
    if "arm" in s:
        arm = s.pop("arm")
        s["ao"], s["rough"], s["metal"] = arm[..., 0], arm[..., 1], arm[..., 2]
    s["normal"] = s["normal"] * 2 - 1
    s.setdefault("ao", np.ones((px, px)))
    s.setdefault("metal", np.zeros((px, px)))
    return s


# ---------------------------------------------------------------- maths

LUMA = np.array([0.2126, 0.7152, 0.0722])


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def vnoise(size, cells, seed):
    """Tileable value noise, size x size, cells per side."""
    g = np.random.default_rng(seed).random((cells, cells))
    t = np.arange(size) * cells / size
    i0 = t.astype(int)
    f = t - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % cells
    fx, fy = f[None, :], f[:, None]
    a, b = g[np.ix_(i0, i0)], g[np.ix_(i0, i1)]
    c, d = g[np.ix_(i1, i0)], g[np.ix_(i1, i1)]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(size, cells, octaves, seed):
    out, amp, tot = np.zeros((size, size)), 1.0, 0.0
    for o in range(octaves):
        out += amp * vnoise(size, cells * 2 ** o, seed + o)
        tot += amp
        amp *= 0.5
    return out / tot


def grade(rgb, lo, hi, sat=0.30, tint=None):
    """Remap luminance 2-98th percentile into sRGB [lo, hi], cap saturation,
    optional tint (sRGB 0-255 tuple), clamp to the art bible 32-225."""
    lum = rgb @ LUMA
    p2, p98 = np.percentile(lum, [2, 98])
    ln = (lo + np.clip((lum - p2) / max(p98 - p2, 1e-4), 0, 1) * (hi - lo)) / 255
    chroma = rgb - lum[..., None]
    s = (rgb.max(-1) - rgb.min(-1)) / np.maximum(rgb.max(-1), 1e-4)
    k = min(1.0, sat / max(float(np.percentile(s, 98)), 1e-4))
    out = ln[..., None] + chroma * k * (ln / np.maximum(lum, 1e-4))[..., None]
    if tint is not None:
        t = np.array(tint) / 255
        out = out * t / (t @ LUMA)
    return clamp_albedo(out)


def clamp_albedo(a):
    return np.clip(a, 32 / 255, 225 / 255)


def col(hexrgb, max_sat=None):
    """sRGB hex -> 0..1 array, optionally desaturated to max_sat (HSV)."""
    r, g, b = (int(hexrgb[i:i + 2], 16) / 255 for i in (0, 2, 4))
    if max_sat is not None:
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        r, g, b = colorsys.hsv_to_rgb(h, min(s, max_sat), v)
    return np.array([r, g, b])


def h2n(h, strength):
    """Height field -> unit normals, OpenGL convention (green = up the image)."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    n = np.dstack([-dx, dy, np.ones_like(h)])
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def blend_n(a, b):
    n = np.dstack([a[..., 0] + b[..., 0], a[..., 1] + b[..., 1], a[..., 2] * b[..., 2]])
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def flat_n(shape):
    n = np.zeros(shape + (3,))
    n[..., 2] = 1
    return n


def scale_n(n, k):
    n = np.dstack([n[..., 0] * k, n[..., 1] * k, n[..., 2]])
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def enc_n(n):
    return n * 0.5 + 0.5


def orm(ao, rough, metal):
    return np.dstack([np.clip(ao, 0, 1), np.clip(rough, 0, 1), np.clip(metal, 0, 1)])


def remap(x, lo, hi):
    p2, p98 = np.percentile(x, [2, 98])
    return lo + np.clip((x - p2) / max(p98 - p2, 1e-4), 0, 1) * (hi - lo)


def write_set(name, sub, size, albedo, normal, ormm):
    save(f"tex_{name}_albedo_{size}.png", sub, albedo)
    save(f"tex_{name}_normal_{size}.png", sub, enc_n(normal))
    save(f"tex_{name}_orm_{size}.png", sub, ormm)


def seg_dist(px, py, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = np.clip(((px - a[0]) * dx + (py - a[1]) * dy) / max(dx * dx + dy * dy, 1e-9), 0, 1)
    return np.hypot(px - a[0] - t * dx, py - a[1] - t * dy)


def strokes(h, w, polylines, width):
    """Anti-aliased coverage of polylines (pixel coords) drawn at width px."""
    py, px = np.mgrid[0:h, 0:w] + 0.5
    d = np.full((h, w), 1e9)
    for pl in polylines:
        for a, b in zip(pl, pl[1:]):
            d = np.minimum(d, seg_dist(px, py, a, b))
    return np.clip(width / 2 - d + 0.5, 0, 1)


def rect(h, w, x0, y0, x1, y1, soft=1.0):
    py, px = np.mgrid[0:h, 0:w] + 0.5
    d = np.minimum.reduce([px - x0, x1 - px, py - y0, y1 - py])
    return np.clip(d / soft + 0.5, 0, 1)


# ---------------------------------------------------------------- tileables (1024 = 4 m)
N = 1024


def floor_tile():
    s = source("dirty_tiles")
    alb = grade(s["albedo"], 52, 90, sat=0.08, tint=(222, 220, 210))  # off-white vinyl, floor range
    rough = remap(s["rough"], 0.55, 0.85)
    write_set("floor_tile_a", "tileable", N, alb, s["normal"], orm(s["ao"], rough, 0 * rough))


def concrete():
    s = source("concrete_floor_worn_001")
    # Form lines every 1 m (rows): shallow grooves.
    y = np.arange(N)[:, None] % 256
    groove = 1 - smooth(0, 3, np.minimum(y, 256 - y)).repeat(N, 1)
    n = blend_n(s["normal"], h2n(-groove, 1.5))
    alb = grade(s["albedo"], 52, 100, sat=0.10)  # serves floor (45-90) and wall (80-140)
    alb = clamp_albedo(alb * (1 - 0.12 * groove[..., None]))
    rough = remap(s["rough"], 0.75, 0.95)
    write_set("concrete_a", "tileable", N, alb, n, orm(s["ao"] * (1 - 0.3 * groove), rough, 0 * rough))


def painted_block():
    s = source("concrete_block_wall_03")
    yy, xx = np.mgrid[0:N, 0:N] + 0.5
    r = yy / 51.2  # 0.2 m courses
    row = np.floor(r)
    fy = r - row
    xs = xx / 102.4 + 0.5 * (row % 2)  # 0.4 m blocks, running bond
    fx = xs - np.floor(xs)
    d = np.minimum(np.minimum(fy, 1 - fy) * 51.2, np.minimum(fx, 1 - fx) * 102.4)
    block = smooth(1.5, 5.0, d)
    lum = s["albedo"] @ LUMA
    h = block + 0.15 * (lum - lum.mean())
    n = blend_n(scale_n(s["normal"], 0.5), h2n(h, 2.0))
    paint = 0.85 + 0.15 * remap(lum, 0, 1)
    # Lower band below 1.2 m: world-triplanar maps world y=0..1.2 m to the
    # bottom 30% of the image (Godot flips V), so the band sits at rows >= 717.
    band = (yy >= 717).astype(float)
    divider = ((yy >= 712) & (yy < 717)).astype(float)
    mortar = 1 - block
    ao = (1 - 0.45 * mortar) * s["ao"]
    rough = 0.62 + 0.15 * mortar + 0.08 * remap(s["rough"], 0, 1)
    nrm_written = False
    for name, lower in (("painted_block_a", "8A8D8C"), ("painted_block_zone_a", "A9C4B8"),
                        ("painted_block_zone_c", "B3342E")):
        upper = col("C9C6BC")
        low = col(lower, max_sat=0.30) * (0.62 if lower != "A9C4B8" else 0.72)
        base = upper[None, None] * (1 - band[..., None]) + low[None, None] * band[..., None]
        base = base * (1 - 0.45 * divider[..., None])
        alb = base * paint[..., None] * (1 - 0.35 * mortar[..., None])
        alb = clamp_albedo(alb * (135 / 255) / max(float(np.percentile(alb @ LUMA, 98)), 1e-4))
        if not nrm_written:
            write_set(name, "tileable", N, alb, n, orm(ao, rough, 0 * rough))
            nrm_written = True
        else:  # zone variants share normal/ORM with painted_block_a
            save(f"tex_{name}_albedo_{N}.png", "tileable", alb)


def steel_plate(s):
    yy, xx = np.mgrid[0:N, 0:N] + 0.5
    # 2 x 1 m plates, seams + rivets 14 px in from each seam every 32 px.
    sy, sx = yy % 256, xx % 512
    seam_d = np.minimum.reduce([sy, 256 - sy, sx, 512 - sx])
    seam = 1 - smooth(0.5, 3.0, seam_d)
    rx = np.hypot((xx % 32) - 16, np.minimum(np.abs(sy - 14), np.abs(sy - 242)))
    ry = np.hypot((yy % 32) - 16, np.minimum(np.abs(sx - 14), np.abs(sx - 498)))
    rr = np.minimum(rx, ry)
    rivet = np.sqrt(np.clip(1 - (rr / 5.0) ** 2, 0, 1))
    h = rivet * 1.0 - seam * 1.0
    n = blend_n(scale_n(s["normal"], 0.6), h2n(h, 3.0))
    alb = grade(s["albedo"], 82, 125, sat=0.10, tint=(176, 184, 186))
    alb = clamp_albedo(alb * (1 - 0.35 * seam[..., None]) * (1 + 0.1 * rivet[..., None]))
    rough = remap(s["rough"], 0.45, 0.75)
    write_set("steel_plate_a", "tileable", N, alb, n,
              orm(s["ao"] * (1 - 0.4 * seam), rough, 0.15 + 0.6 * rivet))


def ceiling_panel():
    s = source("OfficeCeiling006")
    yy, xx = np.mgrid[0:N, 0:N] + 0.5
    # One 1.2 x 0.6 m light-fixture gap per 4 m tile, framed in metal.
    gap = rect(N, N, 358, 435, 666, 589, 1.5)
    frame = rect(N, N, 350, 427, 674, 597, 1.5) - gap
    alb = grade(s["albedo"], 46, 80, sat=0.05)
    alb = alb * (1 - gap[..., None]) + gap[..., None] * (36 / 255)
    alb = clamp_albedo(alb * (1 - frame[..., None]) + frame[..., None] * (78 / 255))
    h = -gap + 0.3 * frame
    n = blend_n(s["normal"], h2n(h, 3.0))
    rough = remap(s["rough"], 0.75, 0.95) * (1 - frame) + 0.45 * frame
    write_set("ceiling_panel_a", "tileable", N, alb, n,
              orm(s["ao"] * (1 - 0.6 * gap), rough, 0.9 * frame))


def rubber_mat():
    """Procedural: ribbed matting, ribs every 16 px (~6 cm) across the run."""
    yy = np.arange(N)[:, None] + 0.5
    rib = (0.5 + 0.5 * np.cos(2 * np.pi * yy / 16)) ** 2 * np.ones((1, N))
    grain = fbm(N, 64, 3, 11)
    wear = fbm(N, 8, 4, 12)
    h = rib + 0.08 * grain
    v = 38 + 10 * rib + 14 * smooth(0.55, 0.8, wear) + 6 * grain  # floor, >=32 (spec)
    alb = clamp_albedo(np.dstack([v, v, v * 1.02]) / 255)
    write_set("rubber_mat_a", "tileable", N, alb, h2n(h, 2.5),
              orm(0.75 + 0.25 * rib, 0.88 - 0.15 * smooth(0.55, 0.8, wear), 0 * h))


def checker_plate():
    s = source("DiamondPlate008A")
    alb = grade(s["albedo"], 55, 92, sat=0.06)
    rough = remap(s["rough"], 0.35, 0.7)
    write_set("checker_plate_a", "tileable", N, alb, s["normal"],
              orm(s["ao"], rough, np.maximum(s["metal"], 0.85)))


def server_rack(s):
    """Procedural rack fronts over painted-metal grain: 1 m bays, blades, vents,
    dim amber LED dots (never cyan, art bible §6)."""
    yy, xx = np.mgrid[0:N, 0:N] + 0.5
    bx = xx % 256
    post = 1 - smooth(10, 14, np.minimum(bx, 256 - bx))
    by = yy % 128
    rng = np.random.default_rng(7)
    unit_h = np.array([22, 22, 44, 22, 18])  # blades in a 128 px block
    edges = np.concatenate([[0], np.cumsum(unit_h)])[:-1]
    blade_d = np.full((N, N), 64.0)
    for e in list(edges) + [128]:
        blade_d = np.minimum(blade_d, np.abs(by - e))
    seam = 1 - smooth(0.5, 2.0, blade_d)
    vent = ((xx % 6 < 3) & (yy % 6 < 3) & (bx > 120) & (bx < 236)).astype(float)
    led = np.zeros((N, N))
    for cx in range(0, N, 256):
        for cy0 in range(0, N, 128):
            for e in edges:
                if rng.random() < 0.6:
                    r = np.hypot(xx - (cx + 30 + 8 * rng.integers(0, 3)), yy - (cy0 + e + 9))
                    led = np.maximum(led, 1 - smooth(1.2, 2.5, r))
    base = grade(s["albedo"], 50, 82, sat=0.05, tint=(150, 152, 156))
    alb = base * (1 - 0.35 * vent[..., None]) * (1 - 0.3 * seam[..., None])
    alb = alb * (1 - post[..., None]) + post[..., None] * (70 / 255)
    amber = col("D98A2B", max_sat=0.55) * 0.85  # dim amber, decor indicators
    alb = clamp_albedo(alb * (1 - led[..., None]) + amber[None, None] * led[..., None])
    h = -0.6 * vent - seam + 0.5 * post + 0.3 * led
    n = blend_n(scale_n(s["normal"], 0.4), h2n(h, 2.0))
    write_set("server_rack_a", "tileable", N, alb, n,
              orm(1 - 0.5 * vent - 0.3 * seam, 0.55 - 0.2 * post + 0.2 * vent, 0.3 + 0.6 * post))


def metal_grate():
    s = source("MetalWalkway010")
    op = s.get("opacity", np.ones((N, N)))
    alb = grade(s["albedo"], 55, 92, sat=0.06)
    # Opaque floor: gaps read as a dark void below (>=32, never pure black).
    alb = clamp_albedo(alb * op[..., None] + (34 / 255) * (1 - op[..., None]))
    rough = remap(s["rough"], 0.4, 0.75)
    n = blend_n(s["normal"], h2n(op, 2.0))
    write_set("metal_grate_a", "tileable", N, alb, n,
              orm(s["ao"] * (0.25 + 0.75 * op), rough, np.maximum(s["metal"], 0.8) * op))


# ---------------------------------------------------------------- trims (2048 = 8 m)
T = 2048
# Shared strip layout (rows, top to bottom) for all four trim sheets; listed in
# assets/art/materials/README.md so modellers can UV to it.
ROWS = [(0, 64), (64, 128), (128, 256), (256, 384), (384, 640), (640, 896), (896, 1408), (1408, 2048)]


def strip_fields(bevel=6):
    """Per-row bevel height (0 at strip edges, 1 inside) and edge distance."""
    prof = np.zeros(T)
    edge = np.zeros(T)
    sidx = np.zeros(T, int)
    for i, (a, b) in enumerate(ROWS):
        y = np.arange(a, b) + 0.5
        d = np.minimum(y - a, b - y)
        prof[a:b] = smooth(0, bevel, d)
        edge[a:b] = d
        sidx[a:b] = i
    return prof[:, None] * np.ones((1, T)), edge[:, None] * np.ones((1, T)), sidx


def tile2(a):
    return np.tile(a, (2, 2, 1)) if a.ndim == 3 else np.tile(a, (2, 2))


def trim_concrete(s):
    prof, edge, sidx = strip_fields(8)
    chip_n = fbm(T, 64, 4, 21)
    chip = smooth(0.52, 0.62, chip_n) * (1 - smooth(3, 14 + 10 * chip_n, edge))
    yy = np.arange(T)[:, None] * np.ones((1, T))
    groove = np.zeros((T, T))
    for i in (3, 5, 7):  # inset groove in some strips (wall caps, column faces)
        a, b = ROWS[i]
        m = (b + a) / 2
        groove = np.maximum(groove, 1 - smooth(1, 4, np.abs(yy - m)))
    h = prof - 0.6 * chip - 0.5 * groove
    n = blend_n(tile2(s["normal"]), h2n(h, 4.0))
    alb = grade(tile2(s["albedo"]), 82, 135, sat=0.10, tint=(200, 194, 182))  # grey-beige walls
    alb = clamp_albedo(alb * (1 + 0.18 * chip[..., None]) * (1 - 0.25 * groove[..., None]))
    ao = tile2(s["ao"]) * (0.55 + 0.45 * prof) * (1 - 0.35 * groove)
    write_set("trim_concrete", "trim", T, alb, n, orm(ao, remap(tile2(s["rough"]), 0.75, 0.95), 0 * ao))


def trim_metal(s):
    prof, edge, sidx = strip_fields(5)
    yy, xx = np.mgrid[0:T, 0:T] + 0.5
    h = prof.copy()
    a, b = ROWS[1]  # rounded rail
    t = np.clip(((yy - a) / (b - a)) * 2 - 1, -1, 1)
    h = np.where(sidx[:, None] == 1, np.sqrt(np.clip(1 - t * t, 0, 1)) * 3, h)
    a, b = ROWS[2]  # bolt row
    bolt = np.sqrt(np.clip(1 - (np.hypot((xx % 64) - 32, yy - (a + b) / 2) / 9) ** 2, 0, 1))
    h += np.where(sidx[:, None] == 2, bolt, 0)
    a, b = ROWS[4]  # vent louvres
    lou = ((yy - a) % 32) / 32
    h = np.where((sidx[:, None] == 4) & (edge > 16), lou * 1.5, h)
    a, b = ROWS[5]  # door jamb with stop groove
    h -= np.where(sidx[:, None] == 5, 1 - smooth(2, 6, np.abs(yy - (a + 96))), 0)
    a, b = ROWS[6]  # plate with rivet border
    riv = np.sqrt(np.clip(1 - (np.hypot((xx % 48) - 24, np.minimum(np.abs(yy - a - 20), np.abs(yy - b + 20))) / 6) ** 2, 0, 1))
    h += np.where(sidx[:, None] == 6, riv, 0)
    # Wear at touch points: edges and random rub patches expose bare steel.
    wn = fbm(T, 48, 4, 31)
    wear = smooth(0.5, 0.62, wn) * (1 - smooth(2, 10 + 14 * wn, edge))
    wear = np.maximum(wear, smooth(0.72, 0.8, fbm(T, 16, 3, 32)) * 0.7)
    n = blend_n(scale_n(tile2(s["normal"]), 0.5), h2n(h, 3.0))
    paint = grade(tile2(s["albedo"]), 78, 122, sat=0.12, tint=(150, 162, 152))  # institutional grey-green
    bare = np.full_like(paint, 150 / 255)
    alb = clamp_albedo(paint * (1 - wear[..., None]) + bare * wear[..., None])
    ao = (0.6 + 0.4 * np.clip(prof, 0, 1)) * tile2(s["ao"])
    rough = remap(tile2(s["rough"]), 0.45, 0.7) * (1 - wear) + 0.35 * wear
    write_set("trim_metal", "trim", T, alb, n, orm(ao, rough, 0.1 + 0.9 * wear))


def trim_glass():
    """Procedural: strips 0-3 dark mullions (opaque), 4-7 blue-green glass
    (alpha 0.3, see-through at flashlight angle, art bible §3) with thin edge
    mullions. Material uses alpha transparency."""
    prof, edge, sidx = strip_fields(4)
    glass = (sidx[:, None] >= 4) & (edge > 10)
    glass = glass * np.ones((1, T))
    smudge = fbm(T, 24, 4, 41)
    mull = col("4A5253") * (0.9 + 0.2 * fbm(T, 128, 2, 42))[..., None]
    tint = col("6E8F8A", max_sat=0.25)
    alb = clamp_albedo(mull * (1 - glass[..., None]) + tint[None, None] * glass[..., None])
    alpha = 1 - glass * (0.7 - 0.12 * smooth(0.55, 0.8, smudge))
    h = prof * (1 - glass) + 0.02 * smudge * glass
    rough = 0.4 * (1 - glass) + glass * (0.06 + 0.3 * smooth(0.55, 0.8, smudge))
    write_set("trim_glass", "trim", T, np.dstack([alb, alpha]), h2n(h, 3.0),
              orm(0.6 + 0.4 * prof, rough, 0.8 * (1 - glass)))


def trim_markings(conc, metal):
    """Floor markings and pipes: 0 hazard edge (wide), 1 hazard (thin), 2 floor
    arrows, 3 painted line, 4 pipe, 5 large pipe with flanges, 6 cable tray,
    7 cable bundle."""
    prof, edge, sidx = strip_fields(4)
    yy, xx = np.mgrid[0:T, 0:T] + 0.5
    base = grade(tile2(conc["albedo"]), 52, 90, sat=0.08)
    alb = base.copy()
    h = np.zeros((T, T))
    rough = remap(tile2(conc["rough"]), 0.75, 0.95)
    metal_m = np.zeros((T, T))
    ao = tile2(conc["ao"]).copy()
    wear = smooth(0.55, 0.7, fbm(T, 64, 4, 51))
    amber = col("D98A2B", max_sat=0.35) * 0.95
    dark = col("2E3031")
    pale = col("C8C4B8")
    for i in (0, 1):  # hazard diagonals
        m = (sidx[:, None] == i) & (edge > 3)
        diag = ((xx + yy) % 64) < 32
        c = np.where(diag[..., None], amber, dark)
        alb = np.where(m[..., None], c * (1 - 0.3 * wear[..., None]) + base * 0.3 * wear[..., None], alb)
        rough = np.where(m, 0.6, rough)
    a, b = ROWS[2]  # arrows every 1 m
    lx = xx % 256
    arrows = strokes(T, 256, [[(40, a + 64), (200, a + 64)], [(150, a + 24), (200, a + 64), (150, a + 104)]], 18)
    arrows = np.tile(arrows, (1, T // 256))
    alb = alb * (1 - arrows[..., None]) + pale * (1 - 0.4 * wear[..., None]) * arrows[..., None]
    m3 = (sidx[:, None] == 3) & (edge > 30)
    alb = np.where(m3[..., None], pale * (1 - 0.4 * wear[..., None]) + base * 0.4 * wear[..., None], alb)
    mpaint = grade(tile2(metal["albedo"]), 70, 118, sat=0.12, tint=(150, 162, 152))
    for i, flange in ((4, False), (5, True)):  # pipes: cylinder across the strip
        a, b = ROWS[i]
        t = np.clip((yy - a) / (b - a) * 2 - 1, -1, 1)
        cyl = np.sqrt(np.clip(1 - t * t, 0, 1))
        m = sidx[:, None] == i
        fl = (np.abs((xx % 512) - 256) < 14) if flange else np.zeros((T, T), bool)
        h = np.where(m, cyl * 4 + fl * 0.5, h)
        alb = np.where(m[..., None], mpaint * (0.8 + 0.2 * fl[..., None]), alb)
        ao = np.where(m, 0.5 + 0.5 * cyl, ao)
        rough = np.where(m, 0.5, rough)
        metal_m = np.where(m, 0.2 + 0.6 * fl, metal_m)
    a, b = ROWS[6]  # cable tray: perforated steel slots
    m = sidx[:, None] == 6
    slot = ((xx % 64) > 12) & ((xx % 64) < 52) & ((yy - a) % 64 > 22) & ((yy - a) % 64 < 42) & (edge > 20)
    alb = np.where(m[..., None], np.where(slot[..., None], 36 / 255, 96 / 255), alb)
    h = np.where(m, prof - slot, h)
    metal_m = np.where(m, 0.85 * (1 - slot), metal_m)
    rough = np.where(m, 0.45, rough)
    a, b = ROWS[7]  # cable bundle: 8 round cables
    m = sidx[:, None] == 7
    ct = ((yy - a) % 80) / 80 * 2 - 1
    cab = np.sqrt(np.clip(1 - ct * ct, 0, 1))
    shade = 42 + 18 * ((yy - a) // 80 % 3)
    alb = np.where(m[..., None], (shade / 255)[..., None] * np.ones(3) * (0.8 + 0.2 * cab[..., None]), alb)
    h = np.where(m, cab * 3, h)
    ao = np.where(m, 0.45 + 0.55 * cab, ao)
    rough = np.where(m, 0.7, rough)
    n = blend_n(scale_n(tile2(conc["normal"]), 0.5), h2n(h, 3.0))
    write_set("trim_markings", "trim", T, clamp_albedo(alb), n, orm(ao, rough, metal_m))


# ---------------------------------------------------------------- decals (4x4 x 256)
C = 256


def decals():
    alb = np.zeros((N, N, 4))
    hgt = np.zeros((N, N))
    rgh = np.full((N, N), 0.8)
    rng = np.random.default_rng(61)
    yy, xx = np.mgrid[0:C, 0:C] + 0.5
    rad = np.hypot(xx - 128, yy - 128) / 128

    def put(r, c, rgb, a, h=None, rough=None):
        sl = (slice(r * C, r * C + C), slice(c * C, c * C + C))
        alb[sl] = np.dstack([np.broadcast_to(rgb, (C, C, 3)), a])
        if h is not None:
            hgt[sl] = h
        if rough is not None:
            rgh[sl] = rough

    for c in range(4):  # row 0: water stains, darker tide-line ring
        n = fbm(C, 4, 5, 100 + c)
        blob = smooth(0.95, 0.55, rad + 0.6 * (n - 0.5))
        ring = blob * (1 - smooth(0.0, 0.12, blob)) + blob * 0.25
        a = np.clip(0.2 * blob + 0.55 * ring * smooth(0, 0.05, blob), 0, 0.7)
        put(0, c, col("5C5446") * (1 - 0.3 * ring[..., None]), a, rough=0.55 + 0 * a)
    for c in range(4):  # row 1: cracks (random walk + branches)
        lines = []
        for k in range(3):
            p = np.array([128.0, 128.0]) if k == 0 else np.array(lines[0][rng.integers(3, 10)])
            ang = rng.uniform(0, 2 * np.pi)
            pl = [tuple(p)]
            for _ in range(14):
                ang += rng.normal(0, 0.45)
                p = np.clip(p + 9 * np.array([np.cos(ang), np.sin(ang)]), 12, 244)
                pl.append(tuple(p))
            lines.append(pl)
        a = strokes(C, C, lines, 2.2 + 0.3 * c)
        put(1, c, col("2A2C2C"), a * 0.95, h=-a)
    for c in range(4):  # row 2: scuffs (rubber streaks), last one grime corner
        if c < 3:
            n = fbm(C, 2, 4, 200 + c)
            ang = rng.uniform(0, np.pi)
            u = (xx - 128) * np.cos(ang) + (yy - 128) * np.sin(ang)
            v = -(xx - 128) * np.sin(ang) + (yy - 128) * np.cos(ang)
            streak = smooth(0.4, 0.75, fbm(C, 16, 3, 220 + c))
            env = smooth(110, 60, np.abs(u)) * smooth(40, 10, np.abs(v + 20 * (n - 0.5)))
            put(2, c, col("34322F"), np.clip(env * (0.3 + 0.5 * streak), 0, 0.75))
        else:
            g = smooth(1.3, 0.2, np.hypot(xx, yy) / 128) * fbm(C, 8, 5, 230)
            put(2, c, col("40382E"), np.clip(g * 1.2, 0, 0.8))
    for c in range(4):  # row 3: taped notes (illegible scribble) x2, drip streak, small note
        if c in (0, 1, 3):
            sz = 150 if c < 3 else 110
            ang = rng.uniform(-0.12, 0.12)
            u = (xx - 128) * np.cos(ang) + (yy - 128) * np.sin(ang)
            v = -(xx - 128) * np.sin(ang) + (yy - 128) * np.cos(ang)
            paper = np.clip(np.minimum(sz / 2 - np.abs(u), sz * 0.65 - np.abs(v)) + 0.5, 0, 1)
            tape = np.clip(np.minimum(22 - np.abs(u), 10 - np.abs(v + sz * 0.62)) + 0.5, 0, 1)
            lines = []
            for k in range(6 if c < 3 else 4):
                y0 = 128 - sz * 0.45 + k * 18
                xs = np.arange(128 - sz * 0.38, 128 + sz * rng.uniform(0.1, 0.38), 5)
                lines.append([(x, y0 + 3 * np.sin(x * 0.7 + k) + rng.normal(0, 1)) for x in xs])
            ink = strokes(C, C, lines, 1.6) * paper
            rgb = col("D2CDBE")[None, None] * (1 - 0.6 * ink[..., None])
            rgb = rgb * (1 - tape[..., None]) + col("B8AE90") * tape[..., None]
            put(3, c, rgb, np.maximum(paper, tape * 0.8), h=0.4 * paper, rough=0.85 + 0 * paper)
        else:
            drip = smooth(14, 4, np.abs(xx - 128 - 6 * np.sin(yy / 30))) * smooth(250, 40, yy)
            put(3, c, col("4C463A"), np.clip(drip * (0.4 + 0.4 * fbm(C, 8, 3, 240)), 0, 0.7))
    rgb = clamp_albedo(alb[..., :3])
    save(f"tex_decal_set_albedo_{N}.png", "decals", np.dstack([rgb, alb[..., 3]]))
    save(f"tex_decal_set_normal_{N}.png", "decals", enc_n(h2n(hgt, 2.0)))
    save(f"tex_decal_set_orm_{N}.png", "decals", orm(1 + 0.6 * np.minimum(hgt, 0), rgh, 0 * rgh))


# ---------------------------------------------------------------- signage (4 x 8 cells of 256 x 128)
# Stroke font in a 0.6 x 1.0 box (y down). Squared-off utility lettering.
GLYPHS = {
    "A": [[(0, 1), (0.3, 0), (0.6, 1)], [(0.11, 0.64), (0.49, 0.64)]],
    "B": [[(0, 0.5), (0.45, 0.5), (0.6, 0.62), (0.6, 0.88), (0.46, 1), (0, 1), (0, 0), (0.4, 0), (0.54, 0.12), (0.54, 0.38), (0.42, 0.5)]],
    "C": [[(0.6, 0.12), (0.48, 0), (0.12, 0), (0, 0.12), (0, 0.88), (0.12, 1), (0.48, 1), (0.6, 0.88)]],
    "H": [[(0, 0), (0, 1)], [(0.6, 0), (0.6, 1)], [(0, 0.5), (0.6, 0.5)]],
    "N": [[(0, 1), (0, 0), (0.6, 1), (0.6, 0)]],
    "S": [[(0.6, 0.12), (0.48, 0), (0.12, 0), (0, 0.12), (0, 0.38), (0.12, 0.5), (0.48, 0.5), (0.6, 0.62), (0.6, 0.88), (0.48, 1), (0.12, 1), (0, 0.88)]],
    "1": [[(0.12, 0.16), (0.34, 0), (0.34, 1)], [(0.1, 1), (0.58, 1)]],
    "2": [[(0, 0.12), (0.12, 0), (0.48, 0), (0.6, 0.12), (0.6, 0.4), (0, 1), (0.6, 1)]],
    "3": [[(0, 0), (0.6, 0), (0.25, 0.44), (0.48, 0.44), (0.6, 0.56), (0.6, 0.88), (0.48, 1), (0.12, 1), (0, 0.88)]],
    "4": [[(0.45, 1), (0.45, 0), (0, 0.68), (0.6, 0.68)]],
    "5": [[(0.6, 0), (0, 0), (0, 0.44), (0.48, 0.44), (0.6, 0.56), (0.6, 0.88), (0.48, 1), (0, 1)]],
    "6": [[(0.54, 0), (0.14, 0), (0, 0.16), (0, 0.88), (0.12, 1), (0.48, 1), (0.6, 0.88), (0.6, 0.62), (0.48, 0.5), (0, 0.5)]],
    "7": [[(0, 0), (0.6, 0), (0.2, 1)]],
    "-": [[(0.08, 0.5), (0.52, 0.5)]],
}


def text_lines(s, x0, y0, hgt):
    out, x = [], x0
    for ch in s:
        for pl in GLYPHS[ch]:
            out.append([(x + px * hgt, y0 + py * hgt) for px, py in pl])
        x += 0.85 * hgt
    return out


def text_width(s, hgt):
    return (0.85 * len(s) - 0.25) * hgt


def shape_lines(kind, cx, cy, r):
    """Zone shape backup for colour (art bible §4): A circle, B triangle,
    C square, H-N solid bar, H-S dashed bar."""
    if kind == "circle":
        return [[(cx + r * np.cos(t), cy + r * np.sin(t)) for t in np.linspace(0, 2 * np.pi, 33)]]
    if kind == "triangle":
        return [[(cx, cy - r), (cx + r, cy + r * 0.8), (cx - r, cy + r * 0.8), (cx, cy - r)]]
    if kind == "square":
        return [[(cx - r, cy - r), (cx + r, cy - r), (cx + r, cy + r), (cx - r, cy + r), (cx - r, cy - r)]]
    if kind == "solid":
        return [[(cx - r, cy), (cx + r, cy)]]
    return [[(cx - r + i * r * 0.7, cy), (cx - r + i * r * 0.7 + r * 0.4, cy)] for i in range(3)]


def signage():
    W, H = 256, 128
    zones = {
        "A": (col("A9C4B8", 0.30), "circle"),
        "B": (col("D98A2B", 0.35), "triangle"),
        "C": (col("B3342E", 0.35) * 1.15, "square"),
        "HN": (col("3F7FA6", 0.35), "solid"),
        "HS": (col("D98A2B", 0.35), "dashed"),
    }
    cells = [(f"A{i}", "A") for i in range(1, 8)] + [(f"B{i}", "B") for i in range(1, 4)]
    cells += [(f"C{i}", "C") for i in range(1, 6)] + [("H-N", "HN"), ("H-S", "HS")]
    cells += [("A", "A"), ("B", "B"), ("C", "C")]
    cells += [("<", None), (">", None), ("^", None), ("v", None)]
    cells += [("", "A"), ("", "B"), ("", "C"), ("", "HN"), ("", "HS")] + [("", None)] * 3
    assert len(cells) == 32
    alb = np.zeros((N, N, 3))
    hgt = np.zeros((N, N))
    ink_c, frame_c = col("26292A"), col("3A3D3E")
    for k, (label, zone) in enumerate(cells):
        r, c = divmod(k, 4)
        plate = rect(H, W, 6, 6, W - 6, H - 6, 1.5)
        bg = zones[zone][0] if zone else col("4A4E50")
        cell = bg[None, None] * plate[..., None] + frame_c * (1 - plate[..., None])
        h = plate * 0.6
        ink = np.zeros((H, W))
        if label in ("<", ">", "^", "v"):  # evacuation arrows: pale chevron, amber band
            band = rect(H, W, 6, H - 22, W - 6, H - 6, 1.0)
            cell = cell * (1 - band[..., None]) + col("D98A2B", 0.35) * band[..., None]
            pts = {">": [[(60, 52), (196, 52)], [(150, 16), (196, 52), (150, 88)]],
                   "<": [[(60, 52), (196, 52)], [(106, 16), (60, 52), (106, 88)]],
                   "^": [[(128, 92), (128, 14)], [(92, 46), (128, 14), (164, 46)]],
                   "v": [[(128, 14), (128, 92)], [(92, 60), (128, 92), (164, 60)]]}[label]
            arr = strokes(H, W, pts, 14)
            cell = cell * (1 - arr[..., None]) + col("D8D4C8") * arr[..., None]
            h += arr * 0.3
        elif label:
            shape = zones[zone][1]
            ink = strokes(H, W, shape_lines(shape, 50, 64, 26), 9)
            th = 72 if len(label) <= 2 else 60
            tx = 96 + (150 - text_width(label, th)) / 2
            ink = np.maximum(ink, strokes(H, W, text_lines(label, tx, 64 - th / 2, th), 11))
        cell = cell * (1 - ink[..., None]) + ink_c * ink[..., None]
        alb[r * H:(r + 1) * H, c * W:(c + 1) * W] = cell
        hgt[r * H:(r + 1) * H, c * W:(c + 1) * W] = h + 0.15 * ink
    wear = fbm(N, 32, 4, 71)
    alb = clamp_albedo(alb * (0.92 + 0.12 * wear[..., None]))
    write_set("signage", "decals", N, alb, h2n(hgt, 2.0), orm(0.85 + 0.15 * hgt, 0.55 + 0.2 * wear, 0 * hgt))


# ---------------------------------------------------------------- stripes (256)


def stripes():
    """Corridor floor stripes, albedo only (roughness scalar in the material).
    U across the stripe, V along it; 256 px = 1 m. H-N solid blue (darker
    Signal Cyan value, art bible §4); H-S dashed orange 0.6 m on / 0.4 m off."""
    yy, xx = np.mgrid[0:C, 0:C] + 0.5
    wear = smooth(0.55, 0.75, fbm(C, 16, 4, 81))
    for name, hexc, dashed in (("stripe_hn", "2B6E8F", False), ("stripe_hs", "B8742A", True)):
        c = col(hexc)[None, None] * (1 - 0.25 * wear[..., None])
        a = np.ones((C, C))
        if dashed:
            a = rect(C, C, -10, 2, C + 10, 152, 1.5)
        save(f"tex_{name}_albedo_{C}.png", "decals", np.dstack([clamp_albedo(c), a]))


# ---------------------------------------------------------------- main


def write_credits():
    path = os.path.join(ROOT, "assets", "art", "CREDITS.md")
    lines = [
        "# Art credits",
        "",
        "All third-party sources are CC0 1.0 (public domain); no attribution is required,",
        "it is recorded here for provenance (AD-248). Processed by `tools/art/build_textures.py`",
        "(desaturated, value-clamped, ORM packed, composited with procedural detail).",
        "Everything not listed is procedural from that script.",
        "",
        "| Asset | Source | URL | Licence | Fetched | Used in |",
        "|---|---|---|---|---|---|",
    ]
    use = {
        "Dirty Tiles": "tex_floor_tile_a",
        "Concrete Floor Worn 001": "tex_concrete_a, tex_trim_concrete, tex_trim_markings",
        "Concrete Block Wall 03": "tex_painted_block_* (surface detail under procedural block grid)",
        "Blue Metal Plate": "tex_steel_plate_a, tex_server_rack_a, tex_trim_metal, tex_trim_markings (pipes)",
    }
    for name, page, site in credits:
        site_name = "Poly Haven" if site == "polyhaven" else "ambientCG"
        u = use.get(name, {"Office Ceiling 006": "tex_ceiling_panel_a", "Diamond Plate 008 A": "tex_checker_plate_a",
                           "Metal Walkway 010": "tex_metal_grate_a"}.get(name, ""))
        lines.append(f"| {name} | {site_name} | {page} | CC0 1.0 | {FETCH_DATE} | {u} |")
    with open(path, "w", newline="\n", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def report():
    """Albedo legality and VRAM estimate (BC7 and BC5 are both 8 bpp, +1/3 mips)."""
    vram = 0
    for path, w, h in written:
        vram += w * h * 4 / 3
    print(f"TEXTURES {len(written)}  est VRAM {vram / 2**20:.1f} MiB (art bible §8 budget 1024 MiB)")


def main():
    os.makedirs(CACHE, exist_ok=True)
    open(os.path.join(CACHE, ".gdignore"), "w").close()  # keep Godot out of downloads
    floor_tile()
    concrete()
    painted_block()
    plate = source("blue_metal_plate")
    steel_plate(plate)
    ceiling_panel()
    rubber_mat()
    checker_plate()
    server_rack(plate)
    metal_grate()
    conc = source("concrete_floor_worn_001")
    trim_concrete(conc)
    trim_metal(plate)
    trim_glass()
    trim_markings(conc, plate)
    decals()
    signage()
    stripes()
    write_credits()
    report()


main()
