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

// Pickup where the squads actually are: a landing spot close to the middle of the group
// (not at the HQ), so they only walk a few dozen metres to the bird
private _mid = [0, 0, 0];
{ _mid = _mid vectorAdd (getPosATL _x) } forEach _men;
_mid = if (_men isEqualTo []) then { _from } else { _mid vectorMultiply (1 / count _men) };
_mid set [2, 0];
private _pickup = [_mid, 15, 150] call CQ_fnc_airParkSpot;
["HQ #%1: airlift pickup at grid %2, %3 m from the squads' centre", [_childId, mapGridPosition _pickup, round (_pickup distance2D _mid)]] call CQ_fnc_log;
private _drop = [_to, 60, 220] call CQ_fnc_airParkSpot;
{ _x enableDynamicSimulation false; [_x] call CQ_fnc_clearWaypoints; _x move (getPosATL _pickup) } forEach _groups;
_hg enableDynamicSimulation false;
_v enableDynamicSimulation false;
[_hg] call CQ_fnc_clearWaypoints;
_v engineOn true;
_v flyInHeight CQ_heightTroops;

["Enemy airlift", format ["A Taru picks up %1 soldiers at grid %2 for HQ #%3 (grid %4): %5", count _men, mapGridPosition _pickup, _childId, mapGridPosition _to, (_groups apply { groupId _x }) joinString ", "]] call CQ_fnc_announce;

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

// 2 board (45 s to walk to the bird, then everyone left is seated: the pad is near their HQ)
private _t1 = time;
waitUntil { sleep 2; ({ alive _x && { _x distance _v > 50 } } count _men) == 0 || { time - _t1 > 45 } };
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
