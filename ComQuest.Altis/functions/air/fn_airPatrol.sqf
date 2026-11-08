/*
    CQ_fnc_airPatrol  (server, from CQ_fnc_airTick)
    [_airEntry, _hq] call CQ_fnc_airPatrol;
    Sends an armed helicopter (Orca / Kajman) on a wandering patrol around an HQ perimeter.
    Each sortie picks a random pattern, direction, radius, altitude and speed so no two
    flights look the same:
      orbit    a loose circle around the HQ, points jittered in and out
      petal    out-and-back loops into random sectors (flower shape)
      zigzag   crossing legs from one side of the perimeter to the other
      wander   free random points in the ring around the HQ
    The route cycles until CQ_airTick ends the sortie (time, ammo, fuel or a QRF call).
*/
params ["_e", "_hq"];

private _v = _e get "veh";
private _g = _e get "grp";
private _c = _hq get "pos";

CQ_airPatrolRadius params ["_rMin", "_rMax"];
private _r = _rMin + random (_rMax - _rMin);
private _dir0 = random 360;
private _sense = selectRandom [1, -1];
private _pattern = selectRandom ["orbit", "petal", "zigzag", "wander"];

private _pts = [];
switch (_pattern) do {
    case "orbit": {
        private _n = 6 + floor random 4;
        for "_i" from 0 to _n - 1 do {
            _pts pushBack (_c getPos [_r * (0.75 + random 0.5), _dir0 + _sense * _i * (360 / _n) + (random 20 - 10)]);
        };
    };
    case "petal": {
        private _n = 3 + floor random 3;
        for "_i" from 0 to _n - 1 do {
            private _a = _dir0 + _sense * _i * (360 / _n);
            _pts pushBack (_c getPos [_r * (0.9 + random 0.4), _a - 15]);
            _pts pushBack (_c getPos [_r * (0.9 + random 0.4), _a + 15]);
            _pts pushBack (_c getPos [_r * 0.3, _a + 40 + random 20]);
        };
    };
    case "zigzag": {
        private _n = 5 + floor random 4;
        for "_i" from 0 to _n - 1 do {
            private _side = [0, 180] select (_i % 2);
            _pts pushBack (_c getPos [_r * (0.7 + random 0.5), _dir0 + _side + _sense * _i * 25]);
        };
    };
    default {
        for "_i" from 0 to 5 + floor random 4 do {
            _pts pushBack (_c getPos [_rMin * 0.5 + random (_r - _rMin * 0.5), random 360]);
        };
    };
};

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
_g setCombatMode "RED";                       // engages what it meets on the way
_g setSpeedMode (selectRandom ["LIMITED", "NORMAL", "NORMAL"]);
{
    private _wp = _g addWaypoint [_x, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointCompletionRadius 150;
} forEach _pts;
(_g addWaypoint [_pts select 0, 0]) setWaypointType "CYCLE";

_e set ["state", "patrolling"];
_e set ["target", _hq get "id"];
_e set ["until", time + (CQ_airPatrolTime select 0) + random ((CQ_airPatrolTime select 1) - (CQ_airPatrolTime select 0))];
_e set ["nearT", -1];
["Air: %1 patrols around HQ #%2 (%3, %4 m, %5 m high, %6 points)", [typeOf _v, _hq get "id", _pattern, round _r, round _alt, count _pts]] call CQ_fnc_log;
