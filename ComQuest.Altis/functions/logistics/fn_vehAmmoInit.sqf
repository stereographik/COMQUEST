/*
    CQ_fnc_vehAmmoInit  (server)
    [_vehicle, _level] call CQ_fnc_vehAmmoInit;
    Records the vehicle's FULL ammo (rounds in every turret magazine, pylons included),
    then loads it to _level (0..1). CQ_fnc_vehAmmoLevel measures against that full value.
*/
params ["_v", ["_level", 1]];

private _full = 0;
{ _full = _full + (_x select 2) } forEach (magazinesAllTurrets _v);
_v setVariable ["CQ_ammoFull", _full max 1];

if (_level < 1) then { _v setVehicleAmmo _level };
