"""One-off transcription: research-facility.md "Visibility sets" table -> each volume's `sees` in
data/maps/research_facility.tres (facility-map story 005, 2026-10-14).

Provenance tool, like sketch_to_map.py: from now on the .tres is the authored file. The greybox
sightline pass (AD-51) edits `sees` there directly; MapData.errors() checks every edit (known volumes,
symmetric, each door joins the two rooms).

Table notation: "A1=A2" and "H-N#C1" name the door between two rooms (passage id "A1-A2", "H-N-C1");
"door: volumes" entries are cut while that door is closed or barricaded. "open:", "glass:" and
"archway X~Y:" entries are never cut (door id &""). A volume listed both through a door and through
glass (A2-M and A3, A2-M and A4) is never cut: the glass still shows it.

Usage: python tools/level/visibility_to_map.py  (rewrites the `sees` line of every volume)
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT / "design" / "levels" / "research-facility.md"
MAP = ROOT / "data" / "maps" / "research_facility.tres"


def table():
    text = DOC.read_text(encoding="utf-8")
    start = text.index("| Volume | Through a door")
    rows = {}
    for line in text[start:].splitlines()[2:]:
        if not line.startswith("|"):
            break
        vid, doors, always = (c.strip() for c in line.strip("|").split("|"))
        sees = {}
        for part in doors.split("·"):
            door, vols = part.split(":")
            for v in vols.split(","):
                sees[v.strip()] = re.sub(r"[=#]", "-", door.strip(), count=1)
        if always != "—":
            for part in always.split("·"):
                for v in part.split(":")[1].split(","):
                    sees[v.strip()] = ""
        rows[vid] = sees
    return rows


def main():
    rows = table()
    src = MAP.read_text(encoding="utf-8")
    src = re.sub(r"\nsees = [^\n]*", "", src)
    for vid, sees in rows.items():
        body = ", ".join('&"%s": &"%s"' % kv for kv in sees.items())
        line = "sees = Dictionary[StringName, StringName]({%s})" % body
        block = 'id = &"%s"\n' % vid
        i = src.index(block)
        j = src.index("\nbox = ", i)
        k = src.index("\n", j + 1)
        src = src[:k] + "\n" + line + src[k:]
    MAP.write_bytes(src.encode("utf-8"))
    print("%d volumes" % len(rows))


if __name__ == "__main__":
    main()
