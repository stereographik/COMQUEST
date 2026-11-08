/*
    CQ_fnc_vehRoam  (server)
    [_group, _vehicle, _hqPos] call CQ_fnc_vehRoam;
    Gives an HQ vehicle (Ifrit, Offroad, Marid, Mora, Nyx...) a fresh roaming route around
    its HQ: 4-7 points in a ring 300 m .. CQ_vehPatrolRadius, snapped to roads when one is
    close, either a loop around the HQ or a criss-cross, short random stops, cycling.
    CQ_fnc_vehRoamTick renews it every CQ_vehRoamRefresh or when the vehicle is stuck.
*/
params ["_g", "_v", "_c"];

private _rMin = 300;
private _rMax = CQ_vehPatrolRadius max 400;
private _n = 4 + floor random 4;
private _pts = [];
private _tries = 0;
while { count _pts < _n && { _tries < 40 } } do {
    _tries = _tries + 1;
    private _p = _c getPos [_rMin + random (_rMax - _rMin), random 360];
    private _roads = _p nearRoads 150;
    if (_roads isNotEqualTo []) then { _p = getPosATL (selectRandom _roads) };
    if (surfaceIsWater _p) then { continue };
    if (_p distance2D CQ_basePos < CQ_airPatrolBaseGap) then { continue };
    _pts pushBack _p;
};
if (count _pts < 2) exitWith { [_g, _c, _rMax] call BIS_fnc_taskPatrol };

private _pattern = selectRandom ["loop", "loop", "crisscross"];
if (_pattern == "loop") then {
    private _sense = selectRandom [1, -1];
    _pts = [_pts, [], { _sense * (_c getDir _x) }, "ASCEND"] call BIS_fnc_sortBy;
};

[_g] call CQ_fnc_clearWaypoints;
_g setBehaviour "SAFE";
_g setCombatMode "RED";
_g setSpeedMode (selectRandom ["LIMITED", "LIMITED", "NORMAL"]);
{
    private _wp = _g addWaypoint [_x, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointCompletionRadius 25;
    if (random 1 < 0.35) then { _wp setWaypointTimeout [15, 30, 60] };   // short stop, like a checkpoint
} forEach _pts;
(_g addWaypoint [_pts select 0, 0]) setWaypointType "CYCLE";

_g setVariable ["CQ_role", "patrol"];
_g setVariable ["CQ_roamT", time];
_g setVariable ["CQ_roamPos", getPosATL _v];
_g setVariable ["CQ_roamPosT", time];
_g enableDynamicSimulation CQ_dynSimGarrison;
