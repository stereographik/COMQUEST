/*
    CQ_fnc_convoyRide  (server, spawned)
    [_vehicle, _groups, _dest, _homePos, _tag] spawn CQ_fnc_convoyRide;
    One ground vehicle carries whole squads to _dest (or only drives there, as escort,
    when _groups is empty):
      1 board: each squad gets the vehicle (addVehicle) and cargo seats, 20 s to climb in,
        then the rest are seated directly (whole squads only: a squad split between foot
        and truck makes the truck stop and wait for them)
      2 drive: MOVE waypoint; if the vehicle has not moved 10 m in 45 s the order is
        re-issued (AWARE, then the driver alone), up to 6 times
      3 unload within 120 m of _dest, squads walk the last metres
      4 _homePos given: the vehicle drives back there (trucks); else it stays (escorts)
    CQ_busy is set for the whole job.
*/
params ["_v", "_groups", "_dest", ["_home", []], ["_tag", ""]];
if (!alive _v) exitWith {};
_v setVariable ["CQ_busy", true];
private _vg = group driver _v;
_vg enableDynamicSimulation false;
_v enableDynamicSimulation false;
[_vg] call CQ_fnc_clearWaypoints;

// 1 board
private _men = [];
{
    private _g = _x;
    _g enableDynamicSimulation false;
    [_g] call CQ_fnc_clearWaypoints;
    _g addVehicle _v;
    { _x assignAsCargo _v; _men pushBack _x } forEach ((units _g) select { alive _x });
    (units _g) orderGetIn true;
} forEach _groups;
if (_men isNotEqualTo []) then {
    private _t0 = time;
    waitUntil { sleep 2; !alive _v || { (_men findIf { alive _x && { vehicle _x != _v } }) == -1 } || { time - _t0 > 20 } };
    { if (alive _x && { vehicle _x != _v } && { (_v emptyPositions "cargo") > 0 }) then { moveOut _x; _x moveInCargo _v } } forEach _men;
};
private _aboard = { alive _x && { vehicle _x == _v } } count _men;
["%1: %2 (%3) leaves with %4 aboard (%5)", [_tag, typeOf _v, groupId _vg, _aboard, (_groups apply { groupId _x }) joinString ", "]] call CQ_fnc_log;

// 2 drive
private _go = {
    params ["_mode"];
    [_vg] call CQ_fnc_clearWaypoints;
    _vg setBehaviour (["SAFE", "AWARE", "AWARE"] select (_mode min 2));
    _vg setSpeedMode "NORMAL";
    if (_mode >= 2) then { (driver _v) doMove (_dest getPos [30, random 360]) } else {
        (_vg addWaypoint [_dest getPos [40, random 360], 30]) setWaypointType "MOVE";
    };
};
[0] call _go;
private _t0 = time;
private _lastPos = getPosATL _v;
private _lastT = time;
private _retries = 0;
waitUntil {
    sleep 3;
    if (alive _v && { _v distance _lastPos > 10 }) then { _lastPos = getPosATL _v; _lastT = time };
    if (alive _v && { time - _lastT > 45 } && { _retries < 6 }) then {
        _retries = _retries + 1;
        [_retries] call _go;
        _lastT = time;
        ["%1: %2 (%3) stuck at grid %4, order re-issued (%5)", [_tag, typeOf _v, groupId _vg, mapGridPosition _v, _retries]] call CQ_fnc_log;
    };
    !alive _v || { !alive driver _v } || { !canMove _v } || { _v distance2D _dest < 120 } || { time - _t0 > 1200 }
};

// 3 unload
{ _x leaveVehicle _v } forEach _groups;
{ if (alive _x && { vehicle _x == _v }) then { unassignVehicle _x; moveOut _x } } forEach _men;
{ [_x] call CQ_fnc_clearWaypoints; (_x addWaypoint [_dest getPos [40, random 360], 30]) setWaypointType "MOVE" } forEach (_groups select { ({ alive _x } count units _x) > 0 });
if (_men isNotEqualTo []) then {
    ["%1: %2 (%3) unloaded at grid %4, %5 m from the target", [_tag, typeOf _v, groupId _vg, mapGridPosition _v, round (_v distance2D _dest)]] call CQ_fnc_log;
};

// 4 home (trucks) or stay (escorts / column vehicles)
if (_home isNotEqualTo [] && { alive _v } && { alive driver _v }) then {
    sleep 5;
    [_vg] call CQ_fnc_clearWaypoints;
    (_vg addWaypoint [_home getPos [30, random 360], 20]) setWaypointType "MOVE";
    private _t1 = time;
    waitUntil { sleep 5; !alive _v || { _v distance2D _home < 80 } || { time - _t1 > 900 } };
};
_v setVariable ["CQ_busy", false];
if (!isNull _vg) then { _vg setVariable ["CQ_roamT", -1] };   // roaming again (CQ_fnc_vehRoamTick)
