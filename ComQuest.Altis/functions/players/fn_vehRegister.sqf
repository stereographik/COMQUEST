/*
    CQ_fnc_vehRegister  (server)
    [_class, _spot, _dir] call CQ_fnc_vehRegister;
    _spot: a parking spot [pos, dir] from CQ_baseSpots, or a marker name placed in Eden.
    Without either, a free spot CQ_baseVehPadding from the other base vehicles is used.
    Spawns the vehicle; CQ_fnc_vehTick handles respawns from then on.
*/
params ["_class", ["_spot", ""], ["_dir", 0]];
if (!isServer) exitWith {};
if (isNil "CQ_vehEntries") then { CQ_vehEntries = [] };

private _pos = [];
if (_spot isEqualType [] && { _spot isNotEqualTo [] }) then {
    _pos = _spot select 0;
    _dir = _spot select 1;
} else {
    if (_spot isEqualType "" && { _spot in allMapMarkers }) then {
        _pos = getMarkerPos _spot;
        _dir = markerDir _spot;
    } else {
        private _taken = CQ_vehEntries apply { _x get "pos" };
        if (!isNil "CQ_arsenalBox") then { _taken pushBack (getPosATL CQ_arsenalBox) };
        for "_r" from CQ_baseVehPadding to 250 step 15 do {
            for "_a" from 0 to 330 step 30 do {
                private _p = CQ_basePos getPos [_r, _a];
                if (surfaceIsWater _p) then { continue };
                if ((_taken findIf { _x distance2D _p < CQ_baseVehPadding }) > -1) then { continue };
                if !([_p, 8] call CQ_fnc_isClear) then { continue };
                _pos = _p;
                break;
            };
            if (_pos isNotEqualTo []) exitWith {};
        };
        if (_pos isEqualTo []) then { _pos = CQ_basePos getPos [CQ_baseVehPadding * (1 + count CQ_vehEntries), 90] };
    };
};

private _entry = createHashMapFromArray [
    ["class", _class], ["pos", _pos], ["dir", _dir], ["veh", objNull], ["deadSince", -1], ["abandonedSince", -1]
];
CQ_vehEntries pushBack _entry;
[_entry] call CQ_fnc_vehSpawn;
