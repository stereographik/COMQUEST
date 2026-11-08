/*
    CQ_fnc_vehAmmoLevel
    [_vehicle] call CQ_fnc_vehAmmoLevel  ->  0..1 of the full ammo recorded by CQ_fnc_vehAmmoInit
*/
params ["_v"];

private _full = _v getVariable ["CQ_ammoFull", -1];
if (_full <= 0) exitWith { 1 };

private _now = 0;
{ _now = _now + (_x select 2) } forEach (magazinesAllTurrets _v);
(_now / _full) min 1
