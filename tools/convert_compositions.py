#!/usr/bin/env python3
"""
convert_compositions.py  -  Eden compositions (composition.sqe + header.sqe) -> SQF data
Usage:  python3 -I tools/convert_compositions.py <compositions_root> <out.sqf> <name> [<name> ...]
  <name> is the composition folder name as it appears in the CntoDev repository (URL-encoded,
  e.g. "Small%20FOB"), searched anywhere under <compositions_root>.
Output: an SQF file defining SC_comps = [[name, author, radius, [[class, [dx, dy, dz], yawDeg,
pitchDeg, bankDeg, simple, noSim], ...]], ...]  with offsets in metres from the composition
centre (x east, y north, z up). Only placed objects are kept (no units, groups, logics,
triggers, waypoints or markers).
Source compositions: CntoDev/compositions, CC-BY-SA-4.0 (credit the authors, share alike).
"""
import math
import re
import sys
import urllib.parse
from pathlib import Path

TOKEN = re.compile(r'"(?:[^"]|"")*"|[A-Za-z_][A-Za-z0-9_]*(?:\[\])?|-?[0-9.]+(?:e[-+]?[0-9]+)?|[{}=;,]', re.I)


def parse(text):
    """Very small parser for the Eden .sqe / .sqm class syntax -> nested dicts (classes keep order)."""
    toks = TOKEN.findall(text)
    pos = 0

    def value():
        nonlocal pos
        t = toks[pos]
        if t == "{":
            pos += 1
            arr = []
            while toks[pos] != "}":
                if toks[pos] == ",":
                    pos += 1
                    continue
                arr.append(value())
            pos += 1
            return arr
        pos += 1
        if t.startswith('"'):
            return t[1:-1].replace('""', '"')
        try:
            return float(t)
        except ValueError:
            return t

    def body(end):
        nonlocal pos
        d = {"__classes": []}
        while pos < len(toks) and toks[pos] != end:
            t = toks[pos]
            if t == ";":
                pos += 1
                continue
            if t.lower() == "class":
                name = toks[pos + 1]
                pos += 2
                if toks[pos] == "{":
                    pos += 1
                    sub = body("}")
                    pos += 1
                else:
                    sub = {"__classes": []}
                d["__classes"].append((name, sub))
                d[name] = sub
                continue
            key = t.replace("[]", "")
            pos += 2  # key =
            d[key] = value()
        return d

    return body(None)


def objects(node, out, in_group=False):
    for name, sub in node.get("__classes", []):
        dt = sub.get("dataType", "")
        if dt == "Object" and not in_group:
            out.append(sub)
        elif dt == "Layer":
            objects(sub.get("Entities", {}), out, in_group)
        elif dt == "Group":
            continue  # units: not decoration
        elif name in ("items", "Entities"):
            objects(sub, out, in_group)
        elif name.startswith("Item"):
            # an Item that is neither Object, Layer nor Group (Logic, Trigger, Marker, Comment...)
            continue
    return out


def convert(folder):
    comp = parse((folder / "composition.sqe").read_text(encoding="utf-8", errors="replace"))
    header = parse((folder / "header.sqe").read_text(encoding="utf-8", errors="replace")) if (folder / "header.sqe").exists() else {}
    objs = objects(comp.get("items", {}), [])
    rows = []
    radius = 0.0
    for o in objs:
        pi = o.get("PositionInfo", {})
        p = pi.get("position", [0, 0, 0])
        a = pi.get("angles", [0, 0, 0])
        attrs = o.get("Attributes", {})
        cls = o.get("type", "")
        if not cls:
            continue
        # Eden: position = [x, height, y], angles in radians = [pitch, yaw, bank]
        dx, dz, dy = float(p[0]), float(p[1]), float(p[2])
        yaw = math.degrees(float(a[1])) % 360
        pitch = math.degrees(float(a[0]))
        bank = math.degrees(float(a[2]))
        pitch = pitch - 360 if pitch > 180 else pitch
        bank = bank - 360 if bank > 180 else bank
        simple = 1 if attrs.get("createAsSimpleObject", 0) else 0
        nosim = 1 if attrs.get("disableSimulation", 0) else 0
        radius = max(radius, math.hypot(dx, dy))
        rows.append((cls, dx, dy, dz, yaw, pitch, bank, simple, nosim))
    name = header.get("name") or urllib.parse.unquote(folder.name)
    author = header.get("author", "unknown")
    return name, author, radius, rows


def sqf_str(s):
    return '"' + str(s).replace('"', '""') + '"'


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    root = Path(sys.argv[1])
    out = Path(sys.argv[2])
    names = sys.argv[3:]
    blocks = []
    for n in names:
        hits = [p for p in root.rglob("composition.sqe") if p.parent.name == n]
        if not hits:
            print(f"not found: {n}")
            continue
        name, author, radius, rows = convert(hits[0].parent)
        lines = ",\n".join(
            "        [%s, [%.3f, %.3f, %.3f], %.2f, %.2f, %.2f, %d, %d]" % (sqf_str(c), dx, dy, dz, yaw, pi, ba, s, ns)
            for c, dx, dy, dz, yaw, pi, ba, s, ns in rows
        )
        blocks.append("    [%s, %s, %.1f, [\n%s\n    ]]" % (sqf_str(name), sqf_str(author), radius, lines))
        print(f"{name:35s} by {author:20s} {len(rows):4d} objects, radius {radius:6.1f} m")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(
        "// GENERATED by tools/convert_compositions.py - do not edit by hand\n"
        "// Source: https://github.com/CntoDev/compositions (CC-BY-SA-4.0), authors credited per entry\n"
        "// [name, author, radius m, [[class, [dx, dy, dz], yaw, pitch, bank, simpleObject, noSimulation], ...]]\n"
        "SC_comps = [\n" + ",\n".join(blocks) + "\n];\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
