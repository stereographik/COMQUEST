/*
    SC_fnc_layout - one plot per composition around SC_origin (the ComQuest base spot at the
    main airport): spiral search for flat, empty ground that doesn't overlap another plot.
    Each plot: the composition, a flag and a map marker. SC_plots = [[name, pos, dir, pairs, radius], ...]
*/
SC_plots = [];
{
    private _i = _forEachIndex;
    _x params ["_name", "_author", "_r"];
    if ((SC_rows select _i) isEqualTo []) then { SC_plots pushBack [_name, [], 0, [], 0]; continue };
    private _need = (_r + 8) max 12;
    private _spot = [];
    private _ring = 0;
    while { _spot isEqualTo [] && { _ring < 60 } } do {
        private _rad = SC_firstRing + _ring * 45;
        private _n = (ceil (2 * 3.1416 * _rad / 45)) max 6;
        for "_k" from 0 to _n - 1 do {
            private _p = SC_origin getPos [_rad, _k * 360 / _n];
            if (!surfaceIsWater _p
                && { (SC_plots findIf { (_x select 1) isNotEqualTo [] && { (_x select 1) distance2D _p < _need + (_x select 4) + 15 } }) == -1 }
                && { ((_p isFlatEmpty [(_need * 0.5) min 12, -1, 0.35, _need min 40, 0, false, objNull]) isNotEqualTo []) }
                && { (nearestTerrainObjects [_p, ["BUILDING", "HOUSE", "FENCE", "WALL"], _need min 60, false]) isEqualTo [] }) exitWith { _spot = _p };
        };
        _ring = _ring + 1;
    };
    if (_spot isEqualTo []) then { diag_log format ["[SC] no free plot for %1", _name]; SC_plots pushBack [_name, [], 0, [], 0]; continue };
    private _dir = _spot getDir SC_origin;
    private _pairs = [_i, _spot, _dir] call SC_fnc_spawnComp;
    private _flag = createVehicle ["Flag_NATO_F", _spot getPos [_need, _dir + 180], [], 0, "CAN_COLLIDE"];
    private _m = createMarker [format ["sc_plot_%1", _i], _spot];
    _m setMarkerType "mil_flag";
    _m setMarkerColor "ColorBLUFOR";
    _m setMarkerText format ["%1. %2", _i + 1, _name];
    SC_plots pushBack [_name, _spot, _dir, _pairs, _need];
    diag_log format ["[SC] plot %1: %2 at grid %3 (%4 objects)", _i + 1, _name, mapGridPosition _spot, count _pairs];
} forEach SC_comps;
