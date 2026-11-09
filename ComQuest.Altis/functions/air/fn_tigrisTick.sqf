/*
    CQ_fnc_tigrisTick  (server, director task, every 4 s)
    Tigris radar: every MAGPIE drone within CQ_tigrisRadar of a Tigris, with a clear line of
    sight, is handed to its crew as a fully known target and engaged (radar forced on, gunner
    ordered to fire). The game AI often ignores a small drone flying high; with this, entering
    the Tigris's missile range (~4 km) is deadly.
*/
if (time < (missionNamespace getVariable ["CQ_tigrisNext", 0])) exitWith {};
CQ_tigrisNext = time + 4;
CQ_tigrises = (missionNamespace getVariable ["CQ_tigrises", []]) select { alive _x };
if (CQ_tigrises isEqualTo []) exitWith {};
private _drones = (missionNamespace getVariable ["CQ_magVehs", []]) select { alive _x && { ((getPosATL _x) select 2) > 20 } };
if (_drones isEqualTo []) exitWith {};
{
    private _t = _x;
    private _gun = gunner _t;
    if (!alive _gun || { side group _gun != east }) then { continue };
    _t setVehicleRadar 1;
    private _eye = (getPosASL _t) vectorAdd [0, 0, 3];
    private _tgts = _drones select {
        _x distance _t < CQ_tigrisRadar && { !(terrainIntersectASL [_eye, getPosASL _x]) }
    };
    if (_tgts isEqualTo []) then { continue };
    private _g = group _gun;
    { _g reveal [_x, 4] } forEach _tgts;
    private _tgt = ([_tgts, [], { _x distance _t }, "ASCEND"] call BIS_fnc_sortBy) select 0;
    _g setCombatMode "RED";
    _gun doTarget _tgt;
    _gun doFire _tgt;
    if (time - (_t getVariable ["CQ_lockLogT", -1e6]) > 30) then {
        _t setVariable ["CQ_lockLogT", time];
        ["Tigris at %1 locked MAGPIE %2 (%3 m)", [mapGridPosition _t, _tgt getVariable ["CQ_magName", typeOf _tgt], round (_tgt distance _t)]] call CQ_fnc_log;
    };
} forEach CQ_tigrises;
