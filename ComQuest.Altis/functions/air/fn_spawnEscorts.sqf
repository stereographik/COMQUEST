/*
    CQ_fnc_spawnEscorts  (server)
    [_start, _heading, _target] call CQ_fnc_spawnEscorts  ->  [[heli, group], ...]
    The escort every transport flight gets: 2 armed PO-30 Orcas + 1 Mi-48 Kajman
    (CQ_escortClasses), 12 rockets each, loitering over the target until released.
*/
params ["_start", "_heading", "_target"];

private _out = [];
{
    private _p = (_start getPos [-120 + 120 * _forEachIndex, _heading + 90]) getPos [150, _heading + 180];
    ([_x, [_p select 0, _p select 1, 0], _heading, false] call CQ_fnc_spawnHeli) params ["_heli", "_hg"];
    [_heli] call CQ_fnc_airLoadout;
    [_heli, 1] call CQ_fnc_vehAmmoInit;
    _hg setBehaviour "AWARE";
    _hg setCombatMode "RED";
    private _wp = _hg addWaypoint [_target, 0];
    _wp setWaypointType "LOITER";
    _wp setWaypointLoiterRadius 400;
    _out pushBack [_heli, _hg];
} forEach CQ_escortClasses;

_out
