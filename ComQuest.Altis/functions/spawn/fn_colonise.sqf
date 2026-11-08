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

// --- boarding: assign cargo seats, officer first
private _free = createHashMap;
{ _free set [netId _x, _x emptyPositions "cargo"] } forEach _vehs;
private _riders = [];
private _allUnits = units _cmdG;
{ _allUnits append (units _x) } forEach _groups;
{
    private _u = _x;
    private _vi = _vehs findIf { alive _x && { (_free get netId _x) > 0 } };
    if (_vi > -1) then {
        private _v = _vehs select _vi;
        _free set [netId _v, (_free get netId _v) - 1];
        _u assignAsCargo _v;
        [_u] orderGetIn true;
        _riders pushBack _u;
    };
} forEach (_allUnits select { alive _x });

// --- airlift: idle troop Taru carry the groups that got no seat in the convoy
private _parent = CQ_hqs getOrDefault [_child get "parent", createHashMap];
private _from = if (count _parent > 0) then { _parent get "pos" } else { getPosATL leader (_groups select 0) };
private _walkers = (_groups + [_cmdG]) select { private _g = _x; ((units _g) findIf { _x in _riders }) == -1 && { ({ alive _x } count units _g) > 0 } };
private _ferried = [];
{
    if (_walkers isEqualTo []) exitWith {};
    private _e = _x;
    private _v = _e get "veh";
    if ((_e get "kind") == "transport" && { (_e get "state") == "parked" } && { alive _v } && { alive driver _v }
        && { (_v emptyPositions "cargo") >= 4 } && { _v distance2D _from < 6000 } && { fuel _v > CQ_airLowFuel + 0.1 }) then {
        private _seats = _v emptyPositions "cargo";
        private _load = [];
        { private _n = { alive _x } count units _x; if (_n <= _seats) then { _load pushBack _x; _seats = _seats - _n } } forEach _walkers;
        if (_load isNotEqualTo []) then {
            _walkers = _walkers - _load;
            _ferried append _load;
            [_e, _load, _from, _site, _id] spawn CQ_fnc_airFerry;
        };
    };
} forEach CQ_air;

private _t0 = time;
waitUntil { sleep 2; (_riders findIf { alive _x && { vehicle _x == _x } }) == -1 || { time - _t0 > 90 } };
{ if (vehicle _x == _x) then { unassignVehicle _x } } forEach _riders;   // not in after 90 s: walk

// --- move (airlifted groups are steered by CQ_fnc_airFerry)
{ (group effectiveCommander _x) move _site } forEach (_vehs select { alive _x });
{ _x move (_site getPos [40, random 360]) } forEach ((_groups + [_cmdG]) - _ferried);
["Enemy colonists moving", format ["HQ #%1: %2 soldiers (%3 mounted, %4 airlifted) heading to grid %5",
    _id, [_groups + [_cmdG]] call CQ_fnc_aliveCount, count (_riders select { vehicle _x != _x }),
    [_ferried] call CQ_fnc_aliveCount, mapGridPosition _site]] call CQ_fnc_announce;

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

_child set ["infantry", _groups select { ({ alive _x } count units _x) > 0 }];
_child set ["cmdGroup", _cmdG];
_child set ["vehicles", _vehs select { alive _x }];
_child set ["state", "Securing"];
_child set ["stateT", time];
["Enemy colonists arrived", format ["HQ #%1: on site at grid %2, securing the perimeter before building", _id, mapGridPosition _site]] call CQ_fnc_announce;
