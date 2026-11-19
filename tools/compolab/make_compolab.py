"""
make_compolab.py - builds the composition lab data for Eden.

Reads Quiksilver's Apex Framework compositions (from your own copy of the framework,
unpacked mission folder) and writes compolab_data.sqf into the CQ_CompoLab.VR mission:
one entry per composition = [name, [[class, [dx, dy, dz], dir], ...], [note lines]].
Apex (Tanoa DLC) classes are swapped for their base-game twins (SWAP below); classes it
does not know are kept and listed at the end so you can check them in Eden.

usage:  python make_compolab.py <unpacked Apex mission folder> <CQ_CompoLab.VR folder>
The framework's files are not part of the ComQuest repo: only this tool is.
"""
import re, sys, os, glob

SWAP = {
    "Land_HBarrier_01_line_1_green_F": "Land_HBarrier_1_F",
    "Land_HBarrier_01_line_3_green_F": "Land_HBarrier_3_F",
    "Land_HBarrier_01_line_5_green_F": "Land_HBarrier_5_F",
    "Land_HBarrier_01_big_4_green_F": "Land_HBarrierBig_F",
    "Land_HBarrier_01_tower_green_F": "Land_HBarrierTower_F",
    "Land_HBarrier_01_big_tower_green_F": "Land_HBarrierTower_F",
    "Land_HBarrier_01_wall_4_green_F": "Land_HBarrierWall4_F",
    "Land_HBarrier_01_wall_6_green_F": "Land_HBarrierWall6_F",
    "Land_HBarrier_01_wall_corner_green_F": "Land_HBarrierWall_corner_F",
    "Land_HBarrier_01_wall_corridor_green_F": "Land_HBarrierWall_corridor_F",
    "Land_BagFence_01_long_green_F": "Land_BagFence_Long_F",
    "Land_BagFence_01_short_green_F": "Land_BagFence_Short_F",
    "Land_BagFence_01_round_green_F": "Land_BagFence_Round_F",
    "Land_BagFence_01_corner_green_F": "Land_BagFence_Corner_F",
    "Land_BagFence_01_end_green_F": "Land_BagFence_End_F",
    "Land_BagBunker_01_large_green_F": "Land_BagBunker_Large_F",
    "Land_BagBunker_01_small_green_F": "Land_BagBunker_Small_F",
    "Box_T_East_Ammo_F": "Box_East_Ammo_F",
    "Box_T_East_Wps_F": "Box_East_Wps_F",
    "Box_T_East_WpsSpecial_F": "Box_East_WpsSpecial_F",
    "Box_T_NATO_Wps_F": "Box_NATO_Wps_F",
    "Box_Syndicate_Ammo_F": "Box_IND_Ammo_F",
    "Box_Syndicate_Wps_F": "Box_IND_Wps_F",
    "Box_Syndicate_WpsLaunch_F": "Box_IND_WpsLaunch_F",
}
# classes that look like DLC content (Apex/Tanoa naming) and have no swap: listed for a check
SUSPECT = re.compile(r"_(01|02|03)_.*(green|olive|tan|khaki)_F$|^.*_T_|Syndicate|Tanoa|_ghex_|_tropic", re.I)

# units ComQuest will put on each kind of site (what the layout must leave room for);
# "QS:" = what Quiksilver's framework spawns there
NOTES = {
    "HQ": ["UNITS: officer (commander) inside the main building",
           "elite escort x4 around the commander",
           "defenders x6+ on walls / tower floors",
           "static HMG x1-2 on towers (crewed)",
           "helipad (guard Orca) within 150 m, trucks can drive in",
           "QS: garrison in buildings, commander + escort"],
    "radioTower_1": ["UNITS: guards x2 (from HQ patrols)", "charge spot at the tower base"],
    "supplyDepot_1": ["UNITS: guards x2", "HEMTT / supply trucks load here (drive-in)"],
    "fortifiedAA": ["UNITS: AA x1 (static Titan or Tigris, crewed)", "guards x2"],
    "mortarPit": ["UNITS: mortars x2 + gunners", "guards x2"],
    "siteMortar": ["UNITS: mortars x2 + gunners", "QS: recon sentry or sniper team patrols"],
    "artyPit": ["UNITS: 2 Sochor (crewed)", "QS: engineers x2"],
    "siteDevice": ["UNITS: event device (EMP / hack)", "guards x4-6"],
    "siteFoxhole": ["UNITS: MG or sniper team x2"],
    "forestCamp": ["UNITS: sentry team x4 (guerillas)", "QS: resistance sentry groups"],
    "siteRadar": ["UNITS: guards x4", "AA nearby"],
    "siteOffshorePlatform": ["UNITS: guards x4-6 (sea objective)"],
    "siteResearch": ["UNITS: guards x4", "intel / hostage spot inside"],
}

OBJ = re.compile(r'\["([A-Za-z0-9_]+)",\[(-?[\d.e+-]+),(-?[\d.e+-]+),(-?[\d.e+-]+)\],(-?[\d.e+-]+)')


def strip_tanoa(t):
    """Drop the 'if (worldName in [...Tanoa...]) exitWith { ... };' block: its objects are the Tanoa version."""
    m = re.search(r"if \(worldName (in \[[^\]]*Tanoa[^\]]*\]|isEqualTo 'Tanoa')\) exitWith \{", t)
    if not m: return t
    i, depth, q = m.end(), 1, None
    while i < len(t) and depth:
        ch = t[i]
        if q:
            if ch == q: q = None
        elif ch in "'\"": q = ch
        elif ch == "{": depth += 1
        elif ch == "}": depth -= 1
        i += 1
    return t[:m.start()] + t[i:]

def variants(t):
    """Group the object rows by the list that holds them: a file with 2 random versions gives 2 groups."""
    parent, stack, q = {}, [], None
    for i, ch in enumerate(t):
        if q:
            if ch == q: q = None
            continue
        if ch in "'\"": q = ch
        elif ch == "[":
            parent[i] = stack[-1] if stack else -1
            stack.append(i)
        elif ch == "]" and stack: stack.pop()
    groups = {}
    for m in OBJ.finditer(t):
        groups.setdefault(parent.get(m.start(), -1), []).append(m.groups())
    return [g for _, g in sorted(groups.items())]

def comps(src):
    cfg = os.path.join(src, "code", "config")
    out = []
    hq = sorted(glob.glob(os.path.join(cfg, "hqCompositions", "arid", "QS_composition*.sqf")),
                key=lambda p: int(re.findall(r"\d+", os.path.basename(p))[0]))
    for p in hq:
        out.append(("HQ " + re.findall(r"\d+", os.path.basename(p))[0], p))
    sites = ["QS_data_radioTower_1", "QS_data_supplyDepot_1", "QS_data_fortifiedAA", "QS_data_mortarPit",
             "QS_data_artyPit", "QS_data_siteMortar", "QS_data_siteDevice", "QS_data_siteFoxhole",
             "QS_data_forestCamp"]
    for s in sites:
        p = os.path.join(cfg, s + ".sqf")
        if os.path.exists(p): out.append((s.replace("QS_data_", ""), p))
    for p in sorted(glob.glob(os.path.join(cfg, "smCompositions", "*.sqf"))):
        out.append((os.path.basename(p)[8:-4], p))
    return out

def main(src, dst):
    seen_suspect = set()
    entries = []
    for name, p in comps(src):
        src_txt = open(p, encoding="latin1").read()
        groups = variants(strip_tanoa(src_txt))
        groups = [g for g in groups if len(g) > 1 or len(groups) == 1]   # a lone row in its own list is not a version
        if "select (worldName isEqualTo 'Tanoa')" in src_txt: groups = groups[:1]   # [altis, tanoa] select isTanoa
        for vi, objs in enumerate(groups):
          vname = name if len(groups) == 1 else f"{name} {chr(65 + vi)}"
          if True:
            rows = []
            for cls, x, y, z, d in objs:
                if cls.startswith(("O_", "B_", "I_", "C_")) and not cls.startswith(("B_Slingload", "B_supplyCrate")):
                    pass   # vehicles / statics are kept: Eden places them empty
                c = SWAP.get(cls, cls)
                if c == cls and SUSPECT.search(cls): seen_suspect.add(cls)
                rows.append(f'["{c}",[{float(x):.3f},{float(y):.3f},{float(z):.3f}],{float(d):.2f}]')
            notes = NOTES.get("HQ" if name.startswith("HQ ") else name, [])
            nsqf = "[" + ",".join('"' + n.replace('"', "'") + '"' for n in notes) + "]"
            entries.append(f'["{vname}",[\n  ' + ",\n  ".join(rows) + f"\n],{nsqf}]")
    os.makedirs(dst, exist_ok=True)
    with open(os.path.join(dst, "compolab_data.sqf"), "w") as f:
        f.write("// generated by tools/compolab/make_compolab.py from your copy of Quiksilver's Apex Framework\n")
        f.write("// [name, [[class, [dx, dy, dz], dir], ...], [unit notes]]  (Apex DLC classes swapped for base-game ones)\n[\n")
        f.write(",\n".join(entries) + "\n]\n")
    print(f"{len(entries)} compositions -> {dst}/compolab_data.sqf")
    if seen_suspect:
        print("check these classes in Eden (possible DLC):", ", ".join(sorted(seen_suspect)))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
