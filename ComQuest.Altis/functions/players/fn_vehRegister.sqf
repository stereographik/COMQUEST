/*
    CQ_fnc_vehRegister  (server)
    ["B_MRAP_01_F", "cq_veh_hunter", 0] call CQ_fnc_vehRegister;
    Picks the vehicle's home spot once (marker if it exists, else a free spot near base),
    then spawns it. CQ_fnc_vehTick handles respawns from then on.
*/
params [["_class", "", [""]], ["_marker", "", [""]], ["_dir", 0, [0]]];

if (!isServer) exitWith {};
if (isNil "CQ_vehEntries") then { CQ_vehEntries = [] };

private _pos = [];
if (_marker in allMapMarkers) then {
    _pos = getMarkerPos _marker;
    _dir = markerDir _marker;
} else {
    // Free spot sized for this vehicle; earlier vehicles are already spawned, so no overlap.
    _pos = CQ_basePos findEmptyPosition [15, 150, _class];
    if (_pos isEqualTo []) then {
        _pos = CQ_basePos getPos [20 + 15 * count CQ_vehEntries, 90];
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
