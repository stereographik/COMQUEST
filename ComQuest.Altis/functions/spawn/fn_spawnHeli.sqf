/*
    CQ_fnc_spawnHeli  (server)
    [_class, _posASL, _dir, _careless] call CQ_fnc_spawnHeli  ->  [heli, group]
    Spawns a crewed CSAT helicopter already flying. Transports are CARELESS so they
    hold their course instead of evading or engaging.
*/
params ["_class", "_pos", "_dir", ["_careless", true]];

private _r = [_pos, _dir, _class, east] call BIS_fnc_spawnVehicle;
_r params ["_heli", "_crew", "_grp"];

_heli setPosASL [_pos select 0, _pos select 1, (getTerrainHeightASL _pos max 0) + CQ_insertionFlyHeight];
_heli setDir _dir;
_heli setVelocityModelSpace [0, 40, 0];
_heli flyInHeight CQ_insertionFlyHeight;

if (_careless) then {
    _grp setBehaviourStrong "CARELESS";
    _grp setCombatMode "BLUE";
};

[_heli, _grp]
