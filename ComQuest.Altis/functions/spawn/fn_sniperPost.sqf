/*
    CQ_fnc_sniperPost  (server, spawned)
    [_unit, _pos] spawn CQ_fnc_sniperPost;
    A sniper walks to his overwatch spot, then goes prone, watches the west and stays.
    A newer order for the same sniper (alarm recall, new spot) cancels this one (CQ_postN).
*/
params ["_u", "_p"];
private _n = (_u getVariable ["CQ_postN", 0]) + 1;
_u setVariable ["CQ_postN", _n];
_u enableAI "PATH";
_u setUnitPos "AUTO";
_u doWatch objNull;
_u doMove _p;
private _t0 = time;
waitUntil { sleep 4; !alive _u || { (_u getVariable ["CQ_postN", 0]) != _n } || { _u distance2D _p < 6 } || { time - _t0 > 900 } };
if (!alive _u || { (_u getVariable ["CQ_postN", 0]) != _n }) exitWith {};
doStop _u;
_u setUnitPos "DOWN";
_u setDir 270;
_u doWatch (_p getPos [1000, 270]);
_u disableAI "PATH";
["Sniper in position at grid %1", [mapGridPosition _u]] call CQ_fnc_log;
