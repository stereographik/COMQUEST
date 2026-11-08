/*
    CQ_fnc_airPatrol  (server, from CQ_fnc_airTick)
    [_airEntry, _hqs] call CQ_fnc_airPatrol;
    Sends an armed helicopter (Orca / Kajman) on a wandering patrol over the HQ network:
    its home HQ first, then CQ_airPatrolHqs other HQs picked at random among every declared
    HQ (nearest-neighbour order, so it sweeps from one zone to the next). Over each HQ it
    flies a random pattern:
      orbit    a loose circle, points jittered in and out
      petal    out-and-back loops into random sectors
      zigzag   crossing legs over the perimeter
      wander   free random points in the ring
    Radius, direction, altitude and speed are random per sortie. The route cycles until
    CQ_airTick ends the sortie (time, ammo, fuel or a QRF call).
*/
params ["_e", "_hqs"];
if (_hqs isEqualTo []) exitWith {};

private _v = _e get "veh";
private _g = _e get "grp";
CQ_airPatrolRadius params ["_rMin", "_rMax"];

private _zone = {
    params ["_c"];
    private _r = _rMin + random (_rMax - _rMin);
    private _dir0 = random 360;
    private _sense = selectRandom [1, -1];
    private _pts = [];
    switch (selectRandom ["orbit", "petal", "zigzag", "wander"]) do {
        case "orbit": {
            private _n = 4 + floor random 3;
            for "_i" from 0 to _n - 1 do { _pts pushBack (_c getPos [_r * (0.75 + random 0.5), _dir0 + _sense * _i * (360 / _n) + (random 20 - 10)]) };
        };
        case "petal": {
            for "_i" from 0 to 1 + floor random 2 do {
                private _a = _dir0 + _sense * _i * 120;
                _pts pushBack (_c getPos [_r * (0.9 + random 0.4), _a - 15]);
                _pts pushBack (_c getPos [_r * (0.9 + random 0.4), _a + 15]);
                _pts pushBack (_c getPos [_r * 0.3, _a + 40 + random 20]);
            };
        };
        case "zigzag": {
            for "_i" from 0 to 3 + floor random 3 do { _pts pushBack (_c getPos [_r * (0.7 + random 0.5), _dir0 + ([0, 180] select (_i % 2)) + _sense * _i * 25]) };
        };
        default {
            for "_i" from 0 to 3 + floor random 3 do { _pts pushBack (_c getPos [_rMin * 0.5 + random (_r - _rMin * 0.5), random 360]) };
        };
    };
    _pts
};

// Order the zones: nearest neighbour from the first (home)
private _todo = +_hqs;
private _order = [_todo deleteAt 0];
while { _todo isNotEqualTo [] } do {
    private _last = (_order select (count _order - 1)) get "pos";
    private _nx = ([_todo, [], { (_x get "pos") distance2D _last }, "ASCEND"] call BIS_fnc_sortBy) select 0;
    _todo = _todo - [_nx];
    _order pushBack _nx;
};
private _pts = [];
{ _pts append ([_x get "pos"] call _zone) } forEach _order;

// No patrol leg over the player base (AA, fighters): points too close are pushed back
_pts = _pts apply {
    private _p = _x;
    if (_p distance2D CQ_basePos < CQ_airPatrolBaseGap) then { _p = CQ_basePos getPos [CQ_airPatrolBaseGap, CQ_basePos getDir _p] };
    _p
};

[_g] call CQ_fnc_clearWaypoints;
_v engineOn true;
private _alt = (CQ_airPatrolHeight select 0) + random ((CQ_airPatrolHeight select 1) - (CQ_airPatrolHeight select 0));
_v flyInHeight _alt;
_g setBehaviour "AWARE";
_g setCombatMode "RED";
_g setSpeedMode (selectRandom ["LIMITED", "NORMAL", "NORMAL"]);
{
    private _wp = _g addWaypoint [_x, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointCompletionRadius 150;
} forEach _pts;
(_g addWaypoint [_pts select 0, 0]) setWaypointType "CYCLE";

_e set ["state", "patrolling"];
_e set ["target", (_order select 0) get "id"];
_e set ["patrolHqs", _order apply { _x get "id" }];
_e set ["until", time + (CQ_airPatrolTime select 0) + random ((CQ_airPatrolTime select 1) - (CQ_airPatrolTime select 0)) + CQ_airPatrolPerHq * (count _order - 1)];
_e set ["nearT", -1];
["Air: %1 patrols HQ %2 (%3 points, %4 m high)", [typeOf _v, (_order apply { format ["#%1", _x get "id"] }) joinString " > ", count _pts, round _alt]] call CQ_fnc_log;
