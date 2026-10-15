"""HUD budget and accessibility measurements on retained screenshots (story hud-results/010).

Stdlib only (PIL is not installed here): a minimal 8-bit non-interlaced PNG reader and writer.
Commands (every number printed, one line each):
  coverage <hud_only.png> [rects.json]   share of pixels that differ from the background colour (the most
                                         common colour: the harness draws the HUD over a flat colour), with
                                         the json's "markers" rects [x, y, w, h] excluded (world markers)
  cvd <in.png> <out_dir> [rects.json]    protanopia / deuteranopia / tritanopia simulations (Machado,
                                         Oliveira and Fernandes 2009, severity 1.0, applied in linear RGB),
                                         plus the contrast of every named rect before and after each
  ink <in.png> <rects.json>              ink height of every named text rect (rows holding bright pixels)
  motion [--rect=x,y,w,h] <a.png> <b.png> [...]         changed pixels between consecutive frames, and their bounding box
  selftest
"""
import json
import os
import struct
import sys
import zlib

# Machado et al. 2009, severity 1.0 (published table), linear RGB.
MACHADO = {
    "protanopia": ((0.152286, 1.052583, -0.204868), (0.114503, 0.786281, 0.099216), (-0.003882, -0.048116, 1.051998)),
    "deuteranopia": ((0.367322, 0.860646, -0.227968), (0.280085, 0.672501, 0.047413), (-0.011820, 0.042940, 0.968881)),
    "tritanopia": ((1.255528, -0.076749, -0.178779), (-0.078411, 0.930809, 0.147602), (0.004733, 0.691367, 0.303900)),
}
DIFF = 12  # per-channel difference that counts as a drawn pixel (PNG and render noise stays below it)


def read_png(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    pos, idat, w = 8, b"", 0
    while pos < len(data):
        n, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if kind == b"IHDR":
            w, h, depth, ctype, _, _, inter = struct.unpack(">IIBBBBB", body)
            assert depth == 8 and inter == 0 and ctype in (2, 6), (path, depth, ctype, inter)
            ch = 3 if ctype == 2 else 4
        elif kind == b"IDAT":
            idat += body
        pos += 12 + n
    raw = zlib.decompress(idat)
    stride = w * ch
    rows, prev = [], bytearray(stride)
    for y in range(h):
        f = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - ch] if i >= ch else 0
            b = prev[i]
            c = prev[i - ch] if i >= ch else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(bytes(line))
        prev = line
    px = bytearray()
    for r in rows:
        if ch == 3:
            px += r
        else:
            px += bytes(v for i, v in enumerate(r) if i % 4 != 3)
    return w, h, px  # RGB bytes, row-major


def write_png(path, w, h, px):
    raw = b"".join(b"\x00" + bytes(px[y * w * 3:(y + 1) * w * 3]) for y in range(h))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xffffffff)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


TO_LIN = [((v / 255) / 12.92) if v / 255 <= 0.04045 else (((v / 255) + 0.055) / 1.055) ** 2.4 for v in range(256)]


def to_srgb(x):
    x = min(max(x, 0.0), 1.0)
    return round(255 * (x * 12.92 if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055))


def simulate(px, m):
    out = bytearray(len(px))
    cache = {}
    for i in range(0, len(px), 3):
        key = bytes(px[i:i + 3])
        v = cache.get(key)
        if v is None:
            r, g, b = (TO_LIN[c] for c in key)
            v = bytes(to_srgb(row[0] * r + row[1] * g + row[2] * b) for row in m)
            cache[key] = v
        out[i:i + 3] = v
    return out


def lum(r, g, b):
    return 0.2126 * TO_LIN[r] + 0.7152 * TO_LIN[g] + 0.0722 * TO_LIN[b]


def region(w, px, rect):
    x0, y0, rw, rh = (int(v) for v in rect)
    for y in range(max(y0, 0), y0 + rh):
        for x in range(max(x0, 0), min(x0 + rw, w)):
            i = (y * w + x) * 3
            if i + 2 < len(px):
                yield px[i], px[i + 1], px[i + 2]


def contrast(w, px, rect):
    """WCAG ratio between the 95th and 5th luminance percentiles of the rect (glyph or shape vs its plate)."""
    ls = sorted(lum(*p) for p in region(w, px, rect))
    if not ls:
        return 0.0
    hi, lo = ls[int(len(ls) * 0.95)], ls[int(len(ls) * 0.05)]
    return (hi + 0.05) / (lo + 0.05)


def background(px):
    counts = {}
    for i in range(0, len(px), 3 * 7):  # every 7th pixel is plenty for the mode
        k = bytes(px[i:i + 3])
        counts[k] = counts.get(k, 0) + 1
    return max(counts, key=counts.get)


def coverage(path, rects_path=None):
    w, h, px = read_png(path)
    bg = background(px)
    skip = bytearray(w * h)
    markers = json.load(open(rects_path, encoding="utf-8")).get("markers", []) if rects_path else []
    for x0, y0, rw, rh in markers:
        for y in range(max(int(y0), 0), min(int(y0 + rh), h)):
            for x in range(max(int(x0), 0), min(int(x0 + rw), w)):
                skip[y * w + x] = 1
    n = 0
    for p in range(w * h):
        i = p * 3
        if not skip[p] and max(abs(px[i] - bg[0]), abs(px[i + 1] - bg[1]), abs(px[i + 2] - bg[2])) > DIFF:
            n += 1
    print("COVERAGE %s %dx%d bg=%s hud_px=%d excluded_marker_px=%d share=%.2f%%"
          % (os.path.basename(path), w, h, tuple(bg), n, sum(skip), 100.0 * n / (w * h)))
    return n / (w * h)


def cvd(path, out_dir, rects_path=None):
    w, h, px = read_png(path)
    rects = json.load(open(rects_path, encoding="utf-8")).get("named", {}) if rects_path else {}
    base = os.path.splitext(os.path.basename(path))[0]
    sims = {"original": px}
    for name, m in MACHADO.items():
        sims[name] = simulate(px, m)
        write_png(os.path.join(out_dir, "%s-%s.png" % (base, name)), w, h, sims[name])
        print("CVD wrote %s-%s.png" % (base, name))
    for label, rect in rects.items():
        print("CONTRAST %s %s %s" % (base, label, " ".join(
            "%s=%.2f" % (k, contrast(w, v, rect)) for k, v in sims.items())))


def ink(path, rects_path):
    w, h, px = read_png(path)
    for label, (x0, y0, rw, rh) in json.load(open(rects_path, encoding="utf-8")).get("text", {}).items():
        rows = [y for y in range(int(y0), int(y0 + rh))
                if any(lum(*p) > 0.5 for p in region(w, px, (x0, y, rw, 1)))]
        print("INK %s %s ink_height_px=%d" % (os.path.basename(path), label, (rows[-1] - rows[0] + 1) if rows else 0))


def motion(paths):
    """Optional first argument --rect=x,y,w,h limits the count to that rect (one element's zone)."""
    rect = None
    if paths[0].startswith("--rect="):
        rect = [int(v) for v in paths[0][7:].split(",")]
        paths = paths[1:]
    prev = None
    for p in paths:
        w, h, px = read_png(p)
        if prev is not None:
            n, box = 0, [w, h, -1, -1]
            for q in range(w * h):
                i = q * 3
                x, y = q % w, q // w
                if rect and not (rect[0] <= x < rect[0] + rect[2] and rect[1] <= y < rect[1] + rect[3]):
                    continue
                if max(abs(px[i] - prev[i]), abs(px[i + 1] - prev[i + 1]), abs(px[i + 2] - prev[i + 2])) > DIFF:
                    n += 1
                    box = [min(box[0], x), min(box[1], y), max(box[2], x), max(box[3], y)]
            print("MOTION %s changed_px=%d bbox=%s" % (os.path.basename(p), n, box if n else "-"))
        prev = px


def selftest():
    for name, m in MACHADO.items():
        for row in m:
            assert abs(sum(row) - 1.0) < 0.002, name  # white stays white
    px = bytearray([255, 0, 255, 10, 20, 30, 255, 255, 255, 0, 0, 0])
    tmp = os.path.join(os.environ.get("TEMP", "/tmp"), "hud_measure_selftest.png")
    write_png(tmp, 2, 2, px)
    assert read_png(tmp) == (2, 2, px)
    assert simulate(bytearray([255, 255, 255]), MACHADO["tritanopia"]) == bytearray([255, 255, 255])
    assert abs(contrast(2, bytearray([255, 255, 255, 0, 0, 0]) * 1, (0, 0, 2, 1)) - 21.0) < 0.01
    print("SELFTEST ok")


if __name__ == "__main__":
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == "coverage":
        coverage(*args)
    elif cmd == "cvd":
        cvd(*args)
    elif cmd == "ink":
        ink(*args)
    elif cmd == "motion":
        motion(args)
    else:
        selftest()
