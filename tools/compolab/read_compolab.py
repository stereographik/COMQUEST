"""
read_compolab.py - reads the saved CQ_CompoLab.VR/mission.sqm (NOT binarized) and writes one
composition per Eden layer, relative to the centre in the layer's name ("<name> @<x>,<y>"):

    compositions.sqf   [[name, [[class, [dx, dy, dz], dir], ...]], ...]   (ComQuest format)
    compositions.json  the same, for tools

dz is the height above the lowest object of the layer (ground level on VR); dir in degrees.
usage:  python read_compolab.py <mission.sqm> <output folder>
"""
import re, sys, os, json, math

def parse(text):
    """tiny parser for the text config format: returns nested dicts (arrays as lists)"""
    tok = re.compile(r'\s*(class\s+(\w+)\s*\{|\};|(\w+)\[\]\s*=\s*\{(.*?)\};|(\w+)\s*=\s*("(?:[^"]|"")*"|[^;]*);)', re.S)
    pos, root, stack = 0, {}, []
    cur = root
    while True:
        m = tok.match(text, pos)
        if not m:
            break
        pos = m.end()
        if m.group(2):
            new = {}
            cur.setdefault("__order", []).append(m.group(2))
            cur[m.group(2)] = new
            stack.append(cur); cur = new
        elif m.group(1).strip() == "};":
            cur = stack.pop()
        elif m.group(3):
            raw = m.group(4).strip()
            vals = [v.strip().strip('"') for v in re.findall(r'"(?:[^"]|"")*"|[^,]+', raw)] if raw else []
            cur[m.group(3)] = [float(v) if re.fullmatch(r"-?[\d.e+-]+", v) else v for v in vals]
        else:
            v = m.group(6).strip()
            cur[m.group(5)] = v[1:-1].replace('""', '"') if v.startswith('"') else (float(v) if re.fullmatch(r"-?[\d.e+-]+", v) else v)
    return root

def items(ents):
    return [ents[k] for k in ents.get("__order", []) if k.startswith("Item")]

def objects(ents, out):
    for it in items(ents):
        t = it.get("dataType")
        if t == "Object":
            out.append(it)
        elif t in ("Group", "Layer") and "Entities" in it:
            objects(it["Entities"], out)

def main(sqm, outdir):
    text = open(sqm, encoding="utf-8", errors="replace").read()
    if "\0" in text[:200] or not text.lstrip().startswith(("version", "class", "binarization")):
        sys.exit("mission.sqm is binarized: save again with 'Binarize the scenario file' OFF")
    root = parse(text)
    comps = []
    for it in items(root["Mission"]["Entities"]):
        if it.get("dataType") != "Layer":
            continue
        m = re.match(r"(.*?)\s*@\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*$", it.get("name", ""))
        if not m:
            print("layer without a centre in its name, skipped:", it.get("name")); continue
        name, cx, cy = m.group(1), float(m.group(2)), float(m.group(3))
        objs = []
        objects(it.get("Entities", {}), objs)
        if not objs:
            continue
        zs = [o["PositionInfo"]["position"][1] for o in objs]
        z0 = min(zs)
        rows = []
        for o in objs:
            x, z, y = o["PositionInfo"]["position"]
            ang = o["PositionInfo"].get("angles", [0, 0, 0])
            d = (math.degrees(ang[1]) % 360) if len(ang) > 1 else 0
            rows.append([o["type"], [round(x - cx, 3), round(y - cy, 3), round(z - z0, 3)], round(d, 2)])
        comps.append([name, rows])
        print(f"{name}: {len(rows)} objects")
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, "compositions.json"), "w") as f:
        json.dump(comps, f, indent=1)
    with open(os.path.join(outdir, "compositions.sqf"), "w") as f:
        f.write("// read from CQ_CompoLab by tools/compolab/read_compolab.py: [name, [[class, [dx, dy, dz], dir], ...]]\n[\n")
        f.write(",\n".join(f'["{n}",[\n  ' + ",\n  ".join(f'["{c}",[{p[0]},{p[1]},{p[2]}],{d}]' for c, p, d in r) + "\n]]" for n, r in comps))
        f.write("\n]\n")
    print(len(comps), "compositions ->", outdir)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
