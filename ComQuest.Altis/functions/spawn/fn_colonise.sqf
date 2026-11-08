/*
    CQ_fnc_colonise  (server, spawned by CQ_fnc_hqSplit)
    [_child, _groups, _vehicles, _cmdGroup] spawn CQ_fnc_colonise;
    Colonists board the truck / random vehicle (up to 2 min), drive or walk to the child site,
    dismount, and the child HQ enters Securing: same lifecycle as a root HQ.
*/
params ["_child", "_groups", "_vehs", "_cmdG"];

private _id = _child get "id";
private _site = _child get "pos";

if (CQ_debug) then {
    private _m = createMarker [format ["cq_dbg_site_%1", _id], _site];
    _m setMarkerType "mil_objective";
    _m setMarkerColor "ColorOPFOR";
    _m setMarkerText format ["DEBUG site HQ #%1 (child of #%2)", _id, _child get "parent"];
    (_child get "markers") pushBack _m;
};

// Colonists must keep moving even with no player around (dynamic simulation would freeze
// them on the spot), and their old patrol / reinforcement waypoints must not pull them back
{ _x enableDynamicSimulation false; [_x] call CQ_fnc_clearWaypoints; _x setBehaviour "AWARE"; _x setSpeedMode "NORMAL" } forEach (_groups + [_cmdG]);
{
    _x enableDynamicSimulation false;
    private _vg = group effectiveCommander _x;
    if (!isNull _vg) then { _vg enableDynamicSimulation false; [_vg] call CQ_fnc_clearWaypoints };
} forEach _vehs;

{ _x setVariable ["CQ_busy", true] } forEach _vehs;
["HQ #%1: colonist column: %2 | squads %3", [_id,
    (_vehs apply { format ["%1 (%2)", typeOf _x, groupId group effectiveCommander _x] }) joinString ", ",
    ((_groups + [_cmdG]) apply { groupId _x }) joinString ", "]] call CQ_fnc_log;

// --- transport, squad by squad (whole squads only):
//   a free vehicle of the column with enough seats within CQ_transportPickRange -> rides
//   else a parked troop Taru within CQ_transportPickRange -> airlift (picks them up there)
//   else walks; with several squads, one squad always walks (ground presence on the route)
private _all0 = (_groups + [_cmdG]) select { ({ alive _x } count units _x) > 0 };
private _seatsLeft = createHashMap;
{ _seatsLeft set [netId _x, _x emptyPositions "cargo"] } forEach _vehs;
private _rides = createHashMap;          // vehicle netId -> groups
private _ferried = [];
private _walkers = [];
private _forcedWalk = if (count _groups > 1) then { _groups select 0 } else { grpNull };
{
    private _g = _x;
    private _n = { alive _x } count units _g;
    if (_g isEqualTo _forcedWalk) then { _walkers pushBack _g; continue };
    private _l = leader _g;
    private _vi = _vehs findIf { alive _x && { canMove _x } && { (_seatsLeft get netId _x) >= _n } && { _x distance2D _l < CQ_transportPickRange } };
    if (_vi > -1) then {
        private _v = _vehs select _vi;
        _seatsLeft set [netId _v, (_seatsLeft get netId _v) - _n];
        private _k = netId _v;
        _rides set [_k, (_rides getOrDefault [_k, []]) + [_g]];
        continue;
    };
    private _ai = CQ_air findIf {
        (_x get "kind") == "transport" && { (_x get "state") == "parked" } && { alive (_x get "veh") } && { alive driver (_x get "veh") }
        && { ((_x get "veh") emptyPositions "cargo") >= _n } && { (_x get "veh") distance2D _l < CQ_transportPickRange } && { fuel (_x get "veh") > CQ_airLowFuel + 0.1 }
    };
    if (_ai > -1) then {
        private _e = CQ_air select _ai;
        _e set ["state", "ferry"];
        _ferried pushBack _g;
        [_e, [_g], getPosATL _l, _site, _id] spawn CQ_fnc_airFerry;
        continue;
    };
    _walkers pushBack _g;
} forEach ((([_cmdG] select { ({ alive _x } count units _x) > 0 })) + _groups);   // officer's group first

// vehicles: carry their squads (or escort empty) and stay at the new HQ
{
    private _v = _x;
    if (alive _v) then { [_v, _rides getOrDefault [netId _v, []], _site, [], format ["HQ #%1 column", _id]] spawn CQ_fnc_convoyRide };
} forEach _vehs;
{ (_x addWaypoint [_site getPos [40, random 360], 30]) setWaypointType "MOVE" } forEach _walkers;

private _mounted = 0;
{ { _mounted = _mounted + ({ alive _x } count units _x) } forEach _y } forEach _rides;
["Enemy colonists moving", format ["HQ #%1: %2 soldiers heading to grid %3: %4 by vehicle, %5 by helicopter, %6 on foot (%7)",
    _id, [_all0] call CQ_fnc_aliveCount, mapGridPosition _site, _mounted, [_ferried] call CQ_fnc_aliveCount, [_walkers] call CQ_fnc_aliveCount,
    (_walkers apply { groupId _x }) joinString ", "]] call CQ_fnc_announce;
private _onFoot = {
    params ["_g"];
    ((units _g) findIf { alive _x && { vehicle _x != _x } }) == -1 && { currentWaypoint _g >= count waypoints _g }
};

_t0 = time;
while { true } do {
    sleep 3;
    private _all = _groups + [_cmdG];
    if (_child get "moveSkip") exitWith {
        _child set ["moveSkip", false];
        {
            if (alive _x) then {
                private _p = [_site getPos [60, random 360], 6, 40] call CQ_fnc_clearPos;
                if (_p isEqualTo []) then { _p = _site getPos [70, random 360] };
                _x setPosATL _p;
            };
        } forEach _vehs;
        { { if (alive _x && { vehicle _x == _x }) then { _x setPosATL (_site getPos [20 + random 30, random 360]) } } forEach units _x } forEach _all;
        ["HQ #%1: DEBUG skip, colonists moved to the site", [_id]] call CQ_fnc_log;
    };
    if (([_all] call CQ_fnc_aliveCount) == 0) exitWith {};
    // Arrived once most of the colonists are on site, not when the first truck gets there
    private _men = [];
    { _men append ((units _x) select { alive _x }) } forEach _all;
    private _onSite = { _x distance2D _site < 300 } count _men;
    if (_onSite >= CQ_colonistArrivalShare * count _men) exitWith {};
    // Mounted groups whose vehicle died walk the rest of the way
    // (also re-sends any group that stopped short of the site)
    {
        if ((leader _x) distance2D _site > 150 && { [_x] call _onFoot }) then {
            (_x addWaypoint [_site getPos [40, random 360], 30]) setWaypointType "MOVE";
        };
    } forEach (_all - _ferried);
    if (CQ_debug && { time - (_child getOrDefault ["progT", 0]) > 60 }) then {
        _child set ["progT", time];
        ["HQ #%1: column progress | %2 | %3", [_id,
            (_vehs select { alive _x } apply { format ["%1 %2 m", groupId group effectiveCommander _x, round (_x distance2D _site)] }) joinString ", ",
            (_all select { ({ alive _x } count units _x) > 0 } apply { format ["%1 %2 m%3", groupId _x, round ((leader _x) distance2D _site), ["", " (in vehicle)"] select (vehicle leader _x != leader _x)] }) joinString ", "]] call CQ_fnc_log;
    };
    if (time - _t0 > 1200) exitWith { ["HQ #%1: colonists timed out on the way (%2/%3 on site), securing from here", [_id, _onSite, count _men]] call CQ_fnc_log };
};

// --- dismount and hand over to the lifecycle
private _all = _groups + [_cmdG];
if (([_all] call CQ_fnc_aliveCount) == 0) exitWith {
    _child set ["state", "Failed"];
    { deleteMarker _x } forEach (_child get "markers");
    ["Enemy colonists eliminated", format ["HQ #%1 will never be built", _id]] call CQ_fnc_announce;
};

{
    private _g = _x;   // infantry and officer only: vehicle crews are in their own groups
    { _g leaveVehicle _x } forEach _vehs;
    { if (vehicle _x != _x) then { unassignVehicle _x; moveOut _x } } forEach units _g;
} forEach _all;

_child set ["infantry", ((_child get "infantry") + _groups) select { ({ alive _x } count units _x) > 0 }];   // keeps squads that came by redeployment
_child set ["cmdGroup", _cmdG];
_child set ["vehicles", _vehs select { alive _x }];
_child set ["incomingCol", 0];
_child set ["state", "Securing"];
_child set ["stateT", time];
["Enemy colonists arrived", format ["HQ #%1: on site at grid %2, securing the perimeter before building", _id, mapGridPosition _site]] call CQ_fnc_announce;
