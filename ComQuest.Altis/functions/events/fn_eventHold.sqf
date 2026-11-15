/*
    CQ_fnc_eventHold  (server)
    [_units, _center, [_r0, _r1]] call CQ_fnc_eventHold;
    Side-event defenders (crash survivors, hostage guards outside): alert (COMBAT, fire at will) and
    holding their own spot, spread evenly on a ring _r0.._r1 m around _center, facing out, mixed
    stances. They turn, crouch and shoot, but never walk away or chase (disableAI "PATH").
*/
params ["_units", "_center", ["_rr", [10, 25]]];
_rr params ["_r0", "_r1"];
private _men = _units select { alive _x && { vehicle _x == _x } };
private _n = count _men;
private _a0 = random 360;
{
    private _a = _a0 + _forEachIndex * 360 / (_n max 1) + (random 20) - 10;
    private _p = _center getPos [_r0 + random (_r1 - _r0), _a];
    if (surfaceIsWater _p) then { _p = _center getPos [_r0, _a] };
    _x setPosATL [_p select 0, _p select 1, 0];
    _x setDir _a;
    _x setFormDir _a;
    _x setUnitPos (selectRandom ["UP", "MIDDLE", "MIDDLE", "DOWN"]);
    _x disableAI "PATH";
} forEach _men;
{ _x setBehaviour "COMBAT"; _x setCombatMode "RED" } forEach ((_units apply { group _x }) arrayIntersect (_units apply { group _x }));
