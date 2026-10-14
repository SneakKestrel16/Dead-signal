"""One-off generator: research-facility.md sketch -> data/maps/research_facility.tres.

Provenance tool, not a pipeline: it was run once (facility-map story 001, 2026-10-14) to turn the
level doc's ASCII sketch into map data. From now on the .tres is the authored file; edit it directly
(the greybox, story 002, will move positions) and do not re-run this over hand edits.

Every value is read off design/levels/research-facility.md:
- Scale "1 sketch column = 1 m, 1 sketch row = 2 m" (Zones and Rooms). x east from the west wall,
  z south from the north wall. A wall drawn at column c / row r lies at x = c / z = 2r.
- Room boxes: the wall lines around each room in the Overview Map. Every size matches the Zones and
  Rooms table. Corridor and spine segment bounds: the "Visibility sets" paragraph.
- Doors, archways, junctions and the exit: their sketch cell and the Connectivity Graph edge. A door
  in a vertical wall sits at (c, 2r + 1), in a horizontal wall at (c + 0.5, 2r).
- Markers: their token in the Placement overlay, at (column + len/2, 2r + 1).
Inference (no number in the doc; the greybox settles it): door width 1.0 m (the doc sets only a
0.8 m clear minimum); the swing box is the leaf's sweep on both sides, since the swing side is not
drawn; door height 2.0 m; ceilings 3 m (B1 6 m) are from the doc.

Usage: python tools/level/sketch_to_map.py  (writes data/maps/research_facility.tres)
"""
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "data" / "maps" / "research_facility.tres"
DOOR_W = 1.0
DOOR_H = 2.0

# id, room, zone, x0, z0, x1, z1, height
VOLUMES = [
    ("A1", "A1", "A", 0, 28, 10, 40, 3), ("A2-N", "A2", "A", 10, 4, 13, 14, 3),
    ("A2-M", "A2", "A", 10, 14, 13, 24, 3), ("A2-S", "A2", "A", 10, 24, 13, 36, 3),
    ("A3", "A3", "A", 0, 14, 10, 28, 3), ("A4", "A4", "A", 13, 14, 22, 26, 3),
    ("A5", "A5", "A", 13, 26, 22, 36, 3), ("A6", "A6", "A", 0, 4, 10, 14, 3),
    ("A7", "A7", "A", 13, 4, 22, 14, 3),
    ("H-N1", "H-N", "link", 0, 0, 12, 4, 3), ("H-N2", "H-N", "link", 12, 0, 24, 4, 3),
    ("H-N3", "H-N", "link", 24, 0, 36, 4, 3), ("H-N4", "H-N", "link", 36, 0, 48, 4, 3),
    ("H-S1", "H-S", "link", 10, 36, 22.5, 40, 3), ("H-S2", "H-S", "link", 22.5, 36, 35, 40, 3),
    ("H-S3", "H-S", "link", 35, 36, 47.5, 40, 3), ("H-S4", "H-S", "link", 47.5, 36, 60, 40, 3),
    ("B1", "B1", "B", 22, 12, 40, 28, 6), ("B2", "B2", "B", 22, 4, 40, 12, 3),
    ("B3", "B3", "B", 22, 28, 40, 36, 3),
    ("C1", "C1", "C", 48, 0, 60, 12, 3), ("C2", "C2", "C", 40, 14, 50, 28, 3),
    ("C3", "C3", "C", 40, 28, 60, 36, 3), ("C4", "C4", "C", 50, 12, 60, 28, 3),
    ("C5", "C5", "C", 40, 4, 48, 14, 3),
]

# a, b, kind, sketch column, sketch row, wall ("v" vertical | "h" horizontal), width (m)
# Order: the Connectivity Graph, read left to right, top to bottom.
PASSAGES = [
    ("A1", "A2", "door", 10, 16, "v", DOOR_W), ("A1", "A3", "door", 5, 14, "h", DOOR_W),
    ("A1", "H-S", "archway", 10, 19, "v", 2.0),
    ("A2", "H-N", "open", 11, 2, "h", 3.0), ("A2", "H-S", "open", 11, 18, "h", 3.0),
    ("A2", "A3", "door", 10, 9, "v", DOOR_W), ("A2", "A4", "door", 13, 10, "v", DOOR_W),
    ("A2", "A7", "door", 13, 5, "v", DOOR_W),
    ("A3", "A6", "door", 5, 7, "h", DOOR_W), ("A6", "H-N", "door", 5, 2, "h", DOOR_W),
    ("A7", "H-N", "door", 17, 2, "h", DOOR_W), ("A4", "A5", "door", 16, 13, "h", DOOR_W),
    ("A5", "H-S", "door", 16, 18, "h", DOOR_W),
    ("A4", "B1", "door", 22, 10, "v", DOOR_W), ("B1", "B2", "door", 31, 6, "h", DOOR_W),
    ("B1", "B3", "door", 31, 14, "h", DOOR_W), ("B2", "H-N", "door", 31, 2, "h", DOOR_W),
    ("B3", "H-S", "door", 31, 18, "h", DOOR_W),
    ("B1", "C2", "barricadable", 40, 10, "v", DOOR_W), ("H-N", "C5", "door", 44, 2, "h", DOOR_W),
    ("H-N", "C1", "barricadable", 48, 1, "v", DOOR_W), ("C5", "C1", "door", 48, 4, "v", DOOR_W),
    ("C5", "C2", "door", 44, 7, "h", DOOR_W),
    ("C1", "C4", "barricadable", 55, 6, "h", DOOR_W), ("C2", "C4", "archway", 50, 10.5, "v", 4.0),
    ("C2", "C3", "door", 45, 14, "h", DOOR_W), ("C3", "C4", "barricadable", 55, 14, "h", DOOR_W),
    ("C3", "H-S", "barricadable", 50, 18, "h", DOOR_W),
    ("C4", "Outside", "exit", 60, 9.5, "v", 4.0),
]

# id, type, token column, token row, token length. Order: Spawn Points, Defense, Surveillance and
# Candidate tables of the doc; switches one per room in Zones and Rooms order.
MARKERS = [
    ("S1", "survivor_spawn", 1, 15, 2), ("S2", "survivor_spawn", 4, 15, 2), ("S3", "survivor_spawn", 1, 16, 2),
    ("S4", "survivor_spawn", 4, 16, 2), ("S5", "survivor_spawn", 7, 15, 2),
    ("M1", "monster_spawn", 48, 15, 2), ("M2", "monster_spawn", 41, 5, 2), ("M3", "monster_spawn", 24, 4, 2),
    ("h1", "hiding", 4, 4, 2), ("h2", "hiding", 1, 9, 2), ("h3", "hiding", 17, 8, 2),
    ("h4", "hiding", 14, 16, 2), ("h5", "hiding", 30, 15, 2), ("h6", "hiding", 44, 4, 2),
    ("s-A1", "switch", 1, 17, 1), ("s-A3", "switch", 4, 9, 1), ("s-A4", "switch", 14, 9, 1),
    ("s-A5", "switch", 17, 16, 1), ("s-A6", "switch", 1, 5, 1), ("s-A7", "switch", 17, 4, 1),
    ("s-B1", "switch", 31, 8, 1), ("s-B2", "switch", 28, 3, 1), ("s-B3", "switch", 24, 16, 1),
    ("s-C1", "switch", 55, 1, 1), ("s-C2", "switch", 44, 8, 1), ("s-C3", "switch", 51, 15, 1),
    ("s-C4", "switch", 52, 9, 1), ("s-C5", "switch", 44, 5, 1),
    ("c1", "camera", 26, 8, 2), ("c2", "camera", 37, 19, 2), ("c3", "camera", 55, 8, 2), ("c4", "camera", 11, 6, 2),
    ("monitors", "monitor", 50, 3, 2),
    ("d1", "drive", 1, 4, 2), ("d2", "drive", 14, 8, 2), ("d3", "drive", 1, 8, 2),
    ("d4", "drive", 14, 4, 2), ("d5", "drive", 14, 15, 2), ("d6", "drive", 45, 15, 2),
    ("f1", "fuse", 4, 8, 2), ("f2", "fuse", 17, 15, 2), ("f3", "fuse", 27, 15, 2), ("f4", "fuse", 34, 19, 2),
    ("f5", "fuse", 41, 4, 2), ("f6", "fuse", 52, 1, 2), ("f7", "fuse", 2, 1, 2),
    ("P1", "fuse_box", 24, 3, 2), ("P2", "fuse_box", 28, 12, 2), ("P3", "fuse_box", 24, 15, 2),
    ("T1", "terminal", 52, 8, 2), ("T2", "terminal", 41, 8, 2), ("T3", "terminal", 42, 15, 2),
]


def num(v):
    return repr(float(v))


def vec(x, y, z):
    return "Vector3(%s, %s, %s)" % (num(x), num(y), num(z))


def aabb(x, y, z, sx, sy, sz):
    return "AABB(%s, %s, %s, %s, %s, %s)" % tuple(num(v) for v in (x, y, z, sx, sy, sz))


def volume_of(x, z):
    for vid, _room, _zone, x0, z0, x1, z1, _h in VOLUMES:
        if x0 <= x < x1 and z0 <= z < z1:
            return vid
    raise SystemExit("no volume at %s, %s" % (x, z))


def sub(rid):
    return rid.replace("-", "_")


def main():
    out = ['[gd_resource type="Resource" script_class="MapData" format=3]', "",
           '[ext_resource type="Script" path="res://src/core/facility/map_data.gd" id="1"]',
           '[ext_resource type="Script" path="res://src/core/facility/map_volume.gd" id="2"]',
           '[ext_resource type="Script" path="res://src/core/facility/map_passage.gd" id="3"]',
           '[ext_resource type="Script" path="res://src/core/facility/map_marker.gd" id="4"]', ""]
    vols, pas, mks = [], [], []
    for vid, room, zone, x0, z0, x1, z1, h in VOLUMES:
        sid = "v_" + sub(vid)
        vols.append(sid)
        out += ['[sub_resource type="Resource" id="%s"]' % sid, 'script = ExtResource("2")',
                'id = &"%s"' % vid, 'room = &"%s"' % room, 'zone = &"%s"' % zone,
                "box = " + aabb(x0, 0, z0, x1 - x0, h, z1 - z0), ""]
    for a, b, kind, c, r, wall, w in PASSAGES:
        pid = "%s-%s" % (a, b)
        x, z = (c, 2 * r + 1) if wall == "v" else (c + 0.5, 2 * r)
        if kind in ("door", "barricadable"):
            swing = aabb(x - w, 0, z - w / 2, 2 * w, DOOR_H, w) if wall == "v" else aabb(x - w / 2, 0, z - w, w, DOOR_H, 2 * w)
        else:
            swing = aabb(0, 0, 0, 0, 0, 0)
        sid = "p_" + sub(pid)
        pas.append(sid)
        out += ['[sub_resource type="Resource" id="%s"]' % sid, 'script = ExtResource("3")',
                'id = &"%s"' % pid, 'a = &"%s"' % a, 'b = &"%s"' % b, 'kind = &"%s"' % kind,
                "position = " + vec(x, 0, z), "width_m = " + num(w), "swing_box = " + swing, ""]
    for mid, mtype, c, r, length in MARKERS:
        x, z = c + length / 2, 2 * r + 1
        sid = "m_" + sub(mid)
        mks.append(sid)
        out += ['[sub_resource type="Resource" id="%s"]' % sid, 'script = ExtResource("4")',
                'id = &"%s"' % mid, 'type = &"%s"' % mtype, 'volume = &"%s"' % volume_of(x, z),
                "position = " + vec(x, 0, z), ""]

    def arr(script_id, ids):
        return 'Array[ExtResource("%s")]([%s])' % (script_id, ", ".join('SubResource("%s")' % i for i in ids))

    out += ["[resource]", 'script = ExtResource("1")', "volumes = " + arr("2", vols),
            "passages = " + arr("3", pas), "markers = " + arr("4", mks), ""]
    OUT.write_bytes("\n".join(out).encode("utf-8"))


if __name__ == "__main__":
    main()
