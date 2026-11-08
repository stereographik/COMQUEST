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
_from set ["infantry", (_from get "infantry") - _groups];
_to set ["incoming", (_to getOrDefault ["incoming", 0]) + _men];
{
    _x setVariable ["CQ_role", "transfer"];
    _x enableDynamicSimulation false;
    [_x] call CQ_fnc_clearWaypoints;
    _x setBehaviour "AWARE";
    _x setSpeedMode "NORMAL";
} forEach _groups;

// --- transport, squad by squad (whole squads only):
//   free troop truck (any HQ) within CQ_transportPickRange of the squad -> rides
//   else a parked troop Taru within CQ_transportPickRange -> airlift, picked up where they are
//   else walks; with several squads one squad always walks; short hops (CQ_walkMaxDist) walk
private _freeTruck = {
    params ["_l", "_n"];
    private _best = objNull;
    private _bd = CQ_transportPickRange;
    {
        {
            if (alive _x && { _x isKindOf "Truck_F" } && { canMove _x } && { alive driver _x }
                && { !(_x getVariable ["CQ_busy", false]) } && { getAmmoCargo _x <= 0 } && { getFuelCargo _x <= 0 } && { getRepairCargo _x <= 0 }
                && { (_x emptyPositions "cargo") >= _n } && { _x distance2D _l < _bd }) then { _best = _x; _bd = _x distance2D _l };
        } forEach (_y get "vehicles");
    } forEach CQ_hqs;
    _best
};
private _walk = [];
private _byTruck = [];
private _byAir = [];
{
    private _g = _x;
    private _n = { alive _x } count units _g;
    private _l = leader _g;
    if (_dist < CQ_walkMaxDist || { _forEachIndex == 0 && { count _groups > 1 } }) then { _walk pushBack _g; continue };
    private _t = [_l, _n] call _freeTruck;
    if (!isNull _t) then {
        _t setVariable ["CQ_busy", true];
        _byTruck pushBack _g;
        [_t, [_g], _b, getPosATL _t, format ["Redeploy to HQ #%1", _toId]] spawn CQ_fnc_convoyRide;
        continue;
    };
    private _ai = CQ_air findIf {
        (_x get "kind") == "transport" && { (_x get "state") == "parked" } && { alive (_x get "veh") } && { alive driver (_x get "veh") }
        && { ((_x get "veh") emptyPositions "cargo") >= _n } && { (_x get "veh") distance2D _l < CQ_transportPickRange } && { fuel (_x get "veh") > CQ_airLowFuel + 0.1 }
    };
    if (_ai > -1) then {
        private _e = CQ_air select _ai;
        _e set ["state", "ferry"];
        _byAir pushBack _g;
        [_e, [_g], getPosATL _l, _b, _toId] spawn CQ_fnc_airFerry;
        continue;
    };
    _walk pushBack _g;
} forEach _groups;
{ (_x addWaypoint [_b getPos [60, random 360], 40]) setWaypointType "MOVE" } forEach _walk;

["Enemy redeploying", format ["HQ #%1 sends %2 soldiers to HQ #%3 (%4 m): %5 by truck, %6 by helicopter, %7 on foot | %8",
    _fromId, _men, _toId, round _dist, [_byTruck] call CQ_fnc_aliveCount, [_byAir] call CQ_fnc_aliveCount, [_walk] call CQ_fnc_aliveCount,
    (_groups apply { groupId _x }) joinString ", "]] call CQ_fnc_announce;

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

private _alive = _groups select { ({ alive _x } count units _x) > 0 };
private _home = if ((_to get "state") in CQ_activeStates) then { _to } else { _from };
if (_alive isEqualTo [] || { !((_home get "state") in CQ_activeStates) }) exitWith {};
_home set ["infantry", (_home get "infantry") + _alive];
{
    [_x] call CQ_fnc_clearWaypoints;
    _x setVariable ["CQ_role", "patrol"];
    [_x, _home get "pos", (CQ_patrolRadius select 0) + random ((CQ_patrolRadius select 1) - (CQ_patrolRadius select 0))] call CQ_fnc_infPatrol;
    _x enableDynamicSimulation CQ_dynSimGarrison;
} forEach _alive;
["reinf", [[_home get "id"] call CQ_fnc_objName], _home] call CQ_fnc_say;
["Enemy redeployment complete", format ["HQ #%1 received %2 soldiers (now %3)", _home get "id", [_alive] call CQ_fnc_aliveCount, [_home get "infantry"] call CQ_fnc_aliveCount]] call CQ_fnc_announce;
