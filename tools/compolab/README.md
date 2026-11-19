# CompoLab: edit compositions in Eden

A tool to edit object compositions in the Eden editor, then turn them back into data ComQuest can use.

1. **Generate** (Claude does this): `python make_compolab.py <unpacked Apex Framework mission> CQ_CompoLab.VR`
   writes `compolab_data.sqf` from your own copy of Quiksilver's Apex Framework (not in this repo).
   Apex (Tanoa DLC) classes are swapped for their base-game twins.
2. **Build in Eden**: open the scenario `CQ_CompoLab` (map VR) from your Eden missions folder,
   open the debug console (Tools > Debug Console, Ctrl+D) and run:
   `call compile preprocessFileLineNumbers "compolab_build.sqf";`
   Every composition gets its own layer `"<name> @<x>,<y>"` on a grid, with a name marker.
3. **Edit**: move, rotate, add, delete objects. New objects go in the composition's layer.
   Do not rename the layers (the `@x,y` part is the composition's centre). Save with
   "Binarize the scenario file" OFF.
4. **Read back** (Claude does this): `python read_compolab.py mission.sqm out/` writes
   `compositions.sqf` (ComQuest format: `[name, [[class, [dx, dy, dz], dir], ...]]`) and `.json`.
