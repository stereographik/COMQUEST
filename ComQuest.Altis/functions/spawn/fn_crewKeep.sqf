/*
    CQ_fnc_crewKeep  (server)
    [_vehicle, _turretPath] call CQ_fnc_crewKeep  ->  false when that seat stays empty
    Lighter CSAT crews (CQ_crewTrim), to save AI:
      armour (Tank, Wheeled_APC_F): the commander seat (observer, no main gun) stays empty:
          Marid, Mora, Kamysh, Gorgon, Tigris keep driver + gunner
      aircraft: a copilot seat with no real weapon stays empty: Orca, Mohawk fly with the pilot
          alone; the Kajman keeps its gunner (cannon)
*/
params ["_veh", "_path"];
if (!CQ_crewTrim) exitWith { true };
if (_veh isKindOf "Air") exitWith {
    ((_veh weaponsTurret _path) - CQ_crewTrimFakeWeapons) isNotEqualTo []
};
if (_veh isKindOf "Tank" || { _veh isKindOf "Wheeled_APC_F" }) exitWith {
    private _tc = [_veh, _path] call BIS_fnc_turretConfig;
    !(getNumber (_tc >> "primaryObserver") == 1 && { getNumber (_tc >> "primaryGunner") != 1 })
};
true
