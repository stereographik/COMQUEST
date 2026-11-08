/*
    CQ_fnc_infPatrol  (server)
    [_group, _center, _radius] call CQ_fnc_infPatrol;
    A patrol loop that always works (BIS_fnc_taskPatrol can fail on cluttered ground):
    4-6 dry-land points 30-100 % of _radius around _center, SAFE / LIMITED, short random
    stops, cycling. Center and radius are kept on the group for CQ_fnc_groupWatch.
*/
params ["_g", "_c", ["_r", 300]];

private _pts = [];
private _tries = 0;
private _n = 4 + floor random 3;
while { count _pts < _n && { _tries < 40 } } do {
    _tries = _tries + 1;
    private _p = _c getPos [_r * (0.3 + random 0.7), random 360];
    if (surfaceIsWater _p) then { continue };
    _pts pushBack _p;
};
if (count _pts < 2) then { _pts = [_c getPos [_r * 0.5, 0], _c getPos [_r * 0.5, 180]] };

[_g] call CQ_fnc_clearWaypoints;
_g setBehaviour "SAFE";
_g setSpeedMode "LIMITED";
_g setFormation (selectRandom ["STAG COLUMN", "COLUMN", "WEDGE"]);
{
    private _wp = _g addWaypoint [_x, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointCompletionRadius 20;
    if (random 1 < 0.3) then { _wp setWaypointTimeout [20, 40, 80] };
} forEach _pts;
(_g addWaypoint [_pts select 0, 0]) setWaypointType "CYCLE";

_g setVariable ["CQ_patrolC", _c];
_g setVariable ["CQ_patrolR", _r];
_g setVariable ["CQ_watchPos", getPosATL leader _g];
_g setVariable ["CQ_watchT", time];
