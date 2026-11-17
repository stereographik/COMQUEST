/*
    compolab_build.sqf  (Eden editor only)
    Places every composition of compolab_data.sqf on a grid, one Eden LAYER per composition,
    named "<name> @<x>,<y>" (the centre the composition is built around: keep it in the name).
    A marker with the name sits 50 m south of each centre; orange lines east of it list the
    UNITS ComQuest will put there (what the layout must leave room for).
    Already built without the notes? Run compolab_notes.sqf instead (adds only the notes).

    In Eden (CQ_CompoLab, map VR): Tools > Debug Console (Ctrl+D), paste and run:
        call compile preprocessFileLineNumbers "compolab_build.sqf";
    Run it once on an empty scenario. Then edit, move, add, delete what you like INSIDE each
    layer (new objects must go in the composition's layer), keep the centre where it is, and
    save (Scenario > Save, with "Binarize the scenario file" OFF).
*/
private _data = call compile preprocessFileLineNumbers "compolab_data.sqf";
private _cols = 6;
private _gap = 140;
private _origin = [1000, 1000];
private _n = 0;
// the units ComQuest will put there: one text line per note, east of the composition
private _notesAt = {
    params ["_c", "_notes", "_layer"];
    {
        private _p = [(_c select 0) + 42, (_c select 1) + 30 - 9 * _forEachIndex, 0];
        private _t = create3DENEntity ["Marker", "mil_box", _p];
        if !(_t isEqualTo "" || { _t isEqualTo objNull }) then {   // a marker comes back as its name (a string)
            _t set3DENAttribute ["text", _x];
            _t set3DENAttribute ["baseColor", "ColorOrange"];
            _t set3DENAttribute ["size2", [0.4, 0.4]];
            _t set3DENLayer _layer;
        };
    } forEach _notes;
};
collect3DENHistory {
    {
        _x params ["_name", "_objs", ["_notes", []]];
        private _i = _forEachIndex;
        private _c = [(_origin select 0) + (_i mod _cols) * _gap, (_origin select 1) + floor (_i / _cols) * _gap];
        private _layer = -1 add3DENLayer format ["%1 @%2,%3", _name, _c select 0, _c select 1];
        {
            _x params ["_cls", "_rel", "_dir"];
            private _p = [(_c select 0) + (_rel select 0), (_c select 1) + (_rel select 1), _rel select 2];
            private _e = create3DENEntity ["Object", _cls, _p, true];
            if (!isNull _e) then {
                _e set3DENAttribute ["rotation", [0, 0, _dir]];
                if ((_rel select 2) > 0.05) then { _e set3DENAttribute ["position", _p] };
                _e set3DENLayer _layer;
                _n = _n + 1;
            } else {
                diag_log format ["CompoLab: %1 could not place %2", _name, _cls];
            };
        } forEach _objs;
        private _m = create3DENEntity ["Marker", "mil_dot", [_c select 0, (_c select 1) - 50, 0]];
        if !(_m isEqualTo "" || { _m isEqualTo objNull }) then {   // a marker comes back as its name (a string)
            _m set3DENAttribute ["text", _name];
            _m set3DENLayer _layer;
        };
        [_c, _notes, _layer] call _notesAt;
    } forEach _data;
};
systemChat format ["CompoLab: %1 compositions, %2 objects placed. Edit inside the layers, then save.", count _data, _n];
