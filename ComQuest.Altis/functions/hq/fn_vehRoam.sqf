/*
    CQ_fnc_vehRoam  (server)
    [_group, _vehicle, _hqPos] call CQ_fnc_vehRoam;
    Gives an HQ vehicle (Ifrit, Offroad, Marid, Mora, Nyx, troop trucks...) a roaming route
    across the HQ network: 5-8 points, about half around its own HQ, the rest around other
    built HQs within CQ_vehRoamNetRange. Points snap to a road when one is near, otherwise
    must pass CQ_fnc_roamSpotOk (no hill tops, steep slopes, rocky fields or water).
    Route is a loop (by bearing) or a criss-cross, a few short stops, cycling.
    CQ_fnc_vehRoamTick renews it every CQ_vehRoamRefresh or when the vehicle is stuck.
*/
params ["_g", "_v", "_c"];

private _hqs = ((values CQ_hqs) select {
    (_x get "state") in CQ_activeStates && { _x get "buildDone" } && { (_x get "pos") distance2D _c < CQ_vehRoamNetRange }
}) apply { _x get "pos" };
if (_hqs isEqualTo []) then { _hqs = [_c] };

private _n = 5 + floor random 4;
private _pts = [];
private _tries = 0;
while { count _pts < _n && { _tries < 60 } } do {
    _tries = _tries + 1;
    private _ctr = if (random 1 < 0.5) then { _c } else { selectRandom _hqs };
    private _p = _ctr getPos [200 + random (CQ_vehPatrolRadius - 200), random 360];
    private _roads = (_p nearRoads 200) select { !surfaceIsWater getPosATL _x };
    if (_roads isNotEqualTo []) then {
        _p = getPosATL (selectRandom _roads);
        if (_p distance2D CQ_basePos < CQ_airPatrolBaseGap) then { continue };
    } else {
        if !([_p] call CQ_fnc_roamSpotOk) then { continue };
    };
    if ((_pts findIf { _x distance2D _p < 150 }) > -1) then { continue };
    _pts pushBack _p;
};
if (count _pts < 2) exitWith {
    [_g, _c, 400] call BIS_fnc_taskPatrol;
    _g setVariable ["CQ_role", "patrol"];
    _g setVariable ["CQ_roamT", time];
};

if (random 1 < 0.6) then {
    private _sense = selectRandom [1, -1];
    _pts = [_pts, [], { _sense * (_c getDir _x) }, "ASCEND"] call BIS_fnc_sortBy;
};

[_g] call CQ_fnc_clearWaypoints;
_g setBehaviour "SAFE";
_g setCombatMode "RED";
_g setSpeedMode (selectRandom ["NORMAL", "NORMAL", "LIMITED"]);
{
    private _wp = _g addWaypoint [_x, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointCompletionRadius 40;
    if (random 1 < 0.2) then { _wp setWaypointTimeout [10, 20, 40] };   // short stop, like a checkpoint
} forEach _pts;
(_g addWaypoint [_pts select 0, 0]) setWaypointType "CYCLE";

_g setVariable ["CQ_role", "patrol"];
_g setVariable ["CQ_roamT", time];
_g setVariable ["CQ_roamPos", getPosATL _v];
_g setVariable ["CQ_roamPosT", time];
_g enableDynamicSimulation false;
_v enableDynamicSimulation false;
