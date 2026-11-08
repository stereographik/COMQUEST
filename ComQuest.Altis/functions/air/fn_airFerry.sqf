/*
    CQ_fnc_airFerry  (server, spawned by CQ_fnc_colonise)
    [_airEntry, _groups, _fromPos, _toPos, _childId] spawn CQ_fnc_airFerry;
    An idle troop Taru airlifts colonists who have no seat in the convoy:
      1 lands on a pickup pad near the parent HQ, the groups walk to it
      2 boards everyone within 50 m (or after 90 s)
      3 flies to a drop pad near the new site, lands, unloads
      4 goes back to its own pad (state toPark, air manager takes over again)
    Robust landings through CQ_fnc_airLandStep; if the heli is lost the groups walk.
*/
params ["_e", "_groups", "_from", "_to", "_childId"];

private _v = _e get "veh";
private _hg = _e get "grp";
_e set ["state", "ferry"];
_e set ["nearT", -1];

private _men = [];
{ _men append (units _x) } forEach _groups;
_men = _men select { alive _x };

private _pickup = [_from, 50, 220] call CQ_fnc_airParkSpot;
private _drop = [_to, 60, 220] call CQ_fnc_airParkSpot;
{ [_x] call CQ_fnc_clearWaypoints; _x move (getPosATL _pickup) } forEach _groups;
[_hg] call CQ_fnc_clearWaypoints;
_v engineOn true;
_v flyInHeight CQ_heightTroops;

["Enemy airlift", format ["A Taru picks up %1 colonists for HQ #%2 (grid %3)", count _men, _childId, mapGridPosition _to]] call CQ_fnc_announce;

private _walk = {
    { _x move (_to getPos [40, random 360]) } forEach _groups;
};
private _cleanup = {
    deleteVehicle _pickup;
    deleteVehicle _drop;
    if (alive _v) then { _e set ["state", "toPark"]; _e set ["nearT", -1] };
};

// 1 pickup
private _st = createHashMap;
private _t0 = time;
waitUntil { sleep 2; !alive _v || { !alive driver _v } || { [_v, _pickup, _st] call CQ_fnc_airLandStep } || { time - _t0 > 300 } };
if (!alive _v || { !alive driver _v } || { !isTouchingGround _v && { (getPosATL _v select 2) > 2 } }) exitWith {
    ["HQ #%1: airlift Taru never reached the pickup, colonists walk", [_childId]] call CQ_fnc_log;
    call _walk;
    call _cleanup;
};

// 2 board
private _t1 = time;
waitUntil { sleep 2; ({ alive _x && { _x distance _v > 50 } } count _men) == 0 || { time - _t1 > 90 } };
{ if (alive _x && { vehicle _x == _x }) then { _x moveInCargo _v } } forEach _men;
private _aboard = { alive _x && { vehicle _x == _v } } count _men;
["HQ #%1: airlift Taru took off with %2 colonists", [_childId, _aboard]] call CQ_fnc_log;
{ if (alive _x && { vehicle _x == _x }) then { _x doMove (_to getPos [40, random 360]) } } forEach _men;   // missed the flight: walk

// 3 flight to the drop pad
_v engineOn true;
_st = createHashMap;
_t0 = time;
waitUntil { sleep 2; !alive _v || { !alive driver _v } || { [_v, _drop, _st] call CQ_fnc_airLandStep } || { time - _t0 > 400 } };

// 4 unload (if it never landed, the colonists are put on the ground at the drop pad)
{
    if (alive _x && { vehicle _x == _v }) then {
        unassignVehicle _x;
        moveOut _x;
        if ((getPosATL _x select 2) > 3) then { _x setPosATL ((getPosATL _drop) getPos [3 + random 10, random 360]) };
    };
} forEach _men;
call _walk;
if (alive _v) then {
    ["Enemy airlift landed", format ["%1 colonists dropped at grid %2 (%3 m from the site of HQ #%4)",
        _aboard, mapGridPosition _v, round (_v distance2D _to), _childId]] call CQ_fnc_announce;
};

sleep 3;
call _cleanup;
