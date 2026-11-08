/*
    CQ_fnc_moveGroups  (server, spawned)
    [_groups, _fromHq, _toHq, _why] spawn CQ_fnc_moveGroups;
    Moves infantry squads from one HQ to another and picks the transport per squad from
    what is there and how far it is:
      under CQ_walkMaxDist          walk
      up to CQ_heliPreferDist       a free truck of the source HQ first, then a parked troop Taru
      beyond                        a parked troop Taru first, then a truck
      nothing free                  walk
    The truck drives back to its HQ after unloading. On arrival the squads join the target
    HQ and patrol there; if the target fell on the way, they return to the source.
*/
params ["_groups", "_from", "_to", ["_why", "balance"]];

private _fromId = _from get "id";
private _toId = _to get "id";
private _a = _from get "pos";
private _b = _to get "pos";
private _dist = _a distance2D _b;
_groups = _groups select { ({ alive _x } count units _x) > 0 };
if (_groups isEqualTo []) exitWith {};

private _men = [_groups] call CQ_fnc_aliveCount;
_from set ["transferBusy", true];
_to set ["transferBusy", true];
_from set ["infantry", (_from get "infantry") - _groups];
_to set ["incoming", (_to getOrDefault ["incoming", 0]) + _men];
{
    _x setVariable ["CQ_role", "transfer"];
    _x enableDynamicSimulation false;
    [_x] call CQ_fnc_clearWaypoints;
    _x setBehaviour "AWARE";
    _x setSpeedMode "NORMAL";
} forEach _groups;

// --- transport options
private _trucks = (_from get "vehicles") select {
    alive _x && { _x isKindOf "Truck_F" } && { canMove _x } && { alive driver _x }
    && { !(_x getVariable ["CQ_busy", false]) } && { getAmmoCargo _x <= 0 } && { getFuelCargo _x <= 0 }
    && { (_x emptyPositions "cargo") >= 4 } && { _x distance2D _a < CQ_truckRecallRange }
};
private _taru = CQ_air select {
    (_x get "kind") == "transport" && { (_x get "state") == "parked" } && { alive (_x get "veh") } && { alive driver (_x get "veh") }
    && { ((_x get "veh") emptyPositions "cargo") >= 4 } && { (_x get "veh") distance2D _a < 6000 } && { fuel (_x get "veh") > CQ_airLowFuel + 0.1 }
};
_taru = [_taru, [], { (_x get "veh") distance2D _a }, "ASCEND"] call BIS_fnc_sortBy;

private _walk = [];
private _rideTruck = [];      // [truck, groups]
private _airlift = [];        // [airEntry, groups]
if (_dist < CQ_walkMaxDist) then {
    _walk = +_groups;
} else {
    private _left = +_groups;
    private _useTrucks = {
        {
            private _v = _x;
            private _seats = _v emptyPositions "cargo";
            private _load = [];
            { private _s = { alive _x } count units _x; if (_s <= _seats) then { _load pushBack _x; _seats = _seats - _s } } forEach _left;
            if (_load isNotEqualTo []) then { _left = _left - _load; _rideTruck pushBack [_v, _load]; _v setVariable ["CQ_busy", true] };
        } forEach _trucks;
        _trucks = [];
    };
    private _useAir = {
        {
            if (_left isEqualTo []) exitWith {};
            private _e = _x;
            private _seats = (_e get "veh") emptyPositions "cargo";
            private _load = [];
            { private _s = { alive _x } count units _x; if (_s <= _seats) then { _load pushBack _x; _seats = _seats - _s } } forEach _left;
            if (_load isNotEqualTo []) then { _left = _left - _load; _airlift pushBack [_e, _load]; _e set ["state", "ferry"] };
        } forEach _taru;
        _taru = [];
    };
    if (_dist > CQ_heliPreferDist) then { call _useAir; call _useTrucks } else { call _useTrucks; call _useAir };
    _walk = _left;
};

["Enemy redeploying", format ["HQ #%1 sends %2 soldiers to HQ #%3 (%4 m): %5 by truck, %6 by helicopter, %7 on foot",
    _fromId, _men, _toId, round _dist,
    [_rideTruck apply { _x select 1 }] call { params ["_l"]; private _n = 0; { _n = _n + ([_x] call CQ_fnc_aliveCount) } forEach _l; _n },
    [_airlift apply { _x select 1 }] call { params ["_l"]; private _n = 0; { _n = _n + ([_x] call CQ_fnc_aliveCount) } forEach _l; _n },
    [_walk] call CQ_fnc_aliveCount]] call CQ_fnc_announce;

// --- walkers
{ (_x addWaypoint [_b getPos [60, random 360], 40]) setWaypointType "MOVE" } forEach _walk;

// --- helicopters (CQ_fnc_airFerry: pickup near the source, drop near the target, then walk in)
{ _x params ["_e", "_load"]; [_e, _load, _a, _b, _toId] spawn CQ_fnc_airFerry } forEach _airlift;

// --- trucks: board, drive, unload, drive home
{
    _x params ["_v", "_load"];
    [_v, _load, _a, _b, _toId] spawn {
        params ["_v", "_load", "_a", "_b", "_toId"];
        private _men = [];
        { _men append ((units _x) select { alive _x }) } forEach _load;
        private _vg = group driver _v;
        // A roaming truck is called back to the HQ first, the squads gather there
        if (_v distance2D _a > 120) then {
            _vg enableDynamicSimulation false;
            [_vg] call CQ_fnc_clearWaypoints;
            _vg setSpeedMode "FULL";
            _vg move (_a getPos [25, random 360]);
            { _x move (_a getPos [20, random 360]) } forEach _load;
            private _tc = time;
            waitUntil { sleep 3; !alive _v || { !canMove _v } || { _v distance2D _a < 120 } || { time - _tc > 240 } };
        };
        { _x assignAsCargo _v; [_x] orderGetIn true } forEach _men;
        private _t0 = time;
        waitUntil { sleep 2; !alive _v || { (_men findIf { alive _x && { vehicle _x == _x } }) == -1 } || { time - _t0 > 30 } };
        { if (alive _x && { vehicle _x == _x }) then {
            if (alive _v && { _x distance _v < 400 } && { (_v emptyPositions "cargo") > 0 }) then { _x moveInCargo _v } else { unassignVehicle _x };
        } } forEach _men;
        { if ((units _x) findIf { alive _x && { vehicle _x == _x } } > -1) then { (_x addWaypoint [_b getPos [60, random 360], 40]) setWaypointType "MOVE" } } forEach _load;

        _vg enableDynamicSimulation false;
        [_vg] call CQ_fnc_clearWaypoints;
        _vg setBehaviour "SAFE";
        _vg setSpeedMode "NORMAL";
        (_vg addWaypoint [_b getPos [50, random 360], 30]) setWaypointType "MOVE";
        _t0 = time;
        waitUntil { sleep 3; !alive _v || { !alive driver _v } || { !canMove _v } || { _v distance2D _b < 150 } || { time - _t0 > 900 } };
        { _x leaveVehicle _v } forEach _load;
        { if (alive _x && { vehicle _x == _v }) then { unassignVehicle _x; moveOut _x } } forEach _men;
        { [_x] call CQ_fnc_clearWaypoints; (_x addWaypoint [_b getPos [40, random 360], 30]) setWaypointType "MOVE" } forEach (_load select { ({ alive _x } count units _x) > 0 });
        if (alive _v && { alive driver _v }) then {
            sleep 5;
            [_vg] call CQ_fnc_clearWaypoints;
            (_vg addWaypoint [_a getPos [30, random 360], 20]) setWaypointType "MOVE";
            ["Redeploy: truck dropped troops for HQ #%1 and heads home", [_toId]] call CQ_fnc_log;
            private _t1 = time;
            waitUntil { sleep 5; !alive _v || { _v distance2D _a < 80 } || { time - _t1 > 900 } };
        } else {
            { if (alive _x && { vehicle _x == _x }) then { (group _x) move (_b getPos [40, random 360]) } } forEach _men;
        };
        _v setVariable ["CQ_busy", false];
        if (!isNull _vg) then { _vg setVariable ["CQ_roamT", -1] };   // roaming again (CQ_fnc_vehRoamTick)
    };
} forEach _rideTruck;

// --- wait for the squads, then hand them over
private _t0 = time;
while { true } do {
    sleep 5;
    private _alive = _groups select { ({ alive _x } count units _x) > 0 };
    if (_alive isEqualTo []) exitWith {};
    if (!((_to get "state") in CQ_activeStates)) exitWith {};
    private _menNow = [];
    { _menNow append ((units _x) select { alive _x }) } forEach _alive;
    if (({ _x distance2D _b < 250 } count _menNow) >= 0.8 * count _menNow) exitWith {};
    // walkers that stopped short are sent again (airlifted groups are steered by airFerry)
    {
        if ((leader _x) distance2D _b > 250 && { ((units _x) findIf { alive _x && { vehicle _x != _x } }) == -1 }
            && { currentWaypoint _x >= count waypoints _x }) then {
            (_x addWaypoint [_b getPos [60, random 360], 40]) setWaypointType "MOVE";
        };
    } forEach _alive;
    if (time - _t0 > 1500) exitWith { ["Redeploy to HQ #%1 timed out, squads join where they are", [_toId]] call CQ_fnc_log };
};

_to set ["incoming", ((_to getOrDefault ["incoming", 0]) - _men) max 0];
_from set ["transferBusy", false];
_to set ["transferBusy", false];

private _alive = _groups select { ({ alive _x } count units _x) > 0 };
private _home = if ((_to get "state") in CQ_activeStates) then { _to } else { _from };
if (_alive isEqualTo [] || { !((_home get "state") in CQ_activeStates) }) exitWith {};
_home set ["infantry", (_home get "infantry") + _alive];
{
    [_x] call CQ_fnc_clearWaypoints;
    _x setVariable ["CQ_role", "patrol"];
    [_x, _home get "pos", (CQ_patrolRadius select 0) + random ((CQ_patrolRadius select 1) - (CQ_patrolRadius select 0))] call BIS_fnc_taskPatrol;
    _x enableDynamicSimulation CQ_dynSimGarrison;
} forEach _alive;
["Enemy redeployment complete", format ["HQ #%1 received %2 soldiers (now %3)", _home get "id", [_alive] call CQ_fnc_aliveCount, [_home get "infantry"] call CQ_fnc_aliveCount]] call CQ_fnc_announce;
