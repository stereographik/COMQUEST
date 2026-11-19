/*
    compolab_notes.sqf  (Eden editor only)
    Adds only the orange UNIT notes next to each composition, in a layer "UNIT NOTES", for a
    lab that was built before the notes existed. Same grid as compolab_build.sqf.
        call compile preprocessFileLineNumbers "compolab_notes.sqf";
*/
private _data = call compile preprocessFileLineNumbers "compolab_data.sqf";
private _cols = 6;
private _gap = 140;
private _origin = [1000, 1000];
collect3DENHistory {
    private _layer = -1 add3DENLayer "UNIT NOTES";
    {
        _x params ["_name", "_objs", ["_notes", []]];
        private _i = _forEachIndex;
        private _c = [(_origin select 0) + (_i mod _cols) * _gap, (_origin select 1) + floor (_i / _cols) * _gap];
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
    } forEach _data;
};
systemChat "CompoLab: unit notes added (layer UNIT NOTES).";
