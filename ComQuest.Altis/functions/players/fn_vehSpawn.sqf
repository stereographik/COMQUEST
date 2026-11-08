/*
    CQ_fnc_vehSpawn  (server)
    [_entry] call CQ_fnc_vehSpawn;
    Spawns (or respawns) one base vehicle on its home spot, with empty cargo.
*/
params ["_entry"];

private _class = _entry get "class";
private _veh = createVehicle [_class, _entry get "pos", [], 0, "NONE"];   // NONE: shifts a little only if something blocks the spot
_veh setDir (_entry get "dir");
// No damage while it settles on its spot (a spawn that touches something would blow up)
_veh allowDamage false;
[_veh] spawn { params ["_v"]; sleep 10; if (alive _v) then { _v setDamage 0; _v allowDamage true } };

clearWeaponCargoGlobal _veh;
clearMagazineCargoGlobal _veh;
clearItemCargoGlobal _veh;
clearBackpackCargoGlobal _veh;
_veh addItemCargoGlobal ["FirstAidKit", 4];

_veh setVariable ["CQ_baseVehicle", true, true];

_entry set ["veh", _veh];
_entry set ["deadSince", -1];
_entry set ["abandonedSince", -1];

["Base vehicle ready: %1 at %2", [_class, mapGridPosition _veh]] call CQ_fnc_log;
_veh
