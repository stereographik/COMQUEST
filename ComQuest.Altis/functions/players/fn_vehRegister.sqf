/*
    CQ_fnc_vehRegister  (server)
    ["B_MRAP_01_F", "cq_veh_hunter", 0] call CQ_fnc_vehRegister;
    Picks the vehicle's home spot once (marker if it exists, else a free spot near base at
    least CQ_baseVehPadding from every other base vehicle and the arsenal crate, clear of
    objects and flat), then spawns it. CQ_fnc_vehTick handles respawns from then on.
*/
params [["_class", "", [""]], ["_marker", "", [""]], ["_dir", 0, [0]]];

if (!isServer) exitWith {};
if (isNil "CQ_vehEntries") then { CQ_vehEntries = [] };

private _pos = [];
if (_marker in allMapMarkers) then {
    _pos = getMarkerPos _marker;
    _dir = markerDir _marker;
} else {
    // Rings outward from the base; every spot keeps CQ_baseVehPadding from the others
    private _taken = CQ_vehEntries apply { _x get "pos" };
    if (!isNil "CQ_arsenalBox") then { _taken pushBack (getPosATL CQ_arsenalBox) };
    for "_r" from CQ_baseVehPadding to 250 step 15 do {
        for "_a" from 0 to 330 step 30 do {
            private _p = CQ_basePos getPos [_r, _a];
            if (surfaceIsWater _p) then { continue };
            if ((_taken findIf { _x distance2D _p < CQ_baseVehPadding }) > -1) then { continue };
            if !([_p, 8] call CQ_fnc_isClear) then { continue };
            if ((_p isFlatEmpty [-1, -1, 0.15, 8, 0, false, objNull]) isEqualTo []) then { continue };
            _pos = _p;
            break;
        };
        if (_pos isNotEqualTo []) exitWith {};
    };
    if (_pos isEqualTo []) then { _pos = CQ_basePos findEmptyPosition [CQ_baseVehPadding, 150, _class] };
    if (_pos isEqualTo []) then {
        _pos = CQ_basePos getPos [CQ_baseVehPadding * (1 + count CQ_vehEntries), 90];
        ["No free spot for %1, using fallback %2", [_class, mapGridPosition _pos]] call CQ_fnc_log;
    };
};

private _entry = createHashMapFromArray [
    ["class", _class],
    ["pos", _pos],
    ["dir", _dir],
    ["veh", objNull],
    ["deadSince", -1],
    ["abandonedSince", -1]
];
CQ_vehEntries pushBack _entry;

[_entry] call CQ_fnc_vehSpawn;
