/*
    CQ_fnc_safeZoneFired  (client, FiredMan event handler on the player)
    Inside the weapons-safe perimeter (CQ_safeZoneRadius around the base) while the base is
    not under attack (CQ_baseHot, CQ_fnc_safeZoneTick), the shot never leaves: the projectile
    is deleted and the round given back. Smoke, chemlights and countermeasures are allowed.
*/
params ["_unit", "_weapon", "_muzzle", "", "_ammo", "_mag", "_proj", "_veh"];
if (missionNamespace getVariable ["CQ_baseHot", false]) exitWith {};
if (_unit distance2D CQ_basePos > CQ_safeZoneRadius) exitWith {};
private _cfg = configFile >> "CfgAmmo" >> _ammo;
private _sim = toLower getText (_cfg >> "simulation");
if (_sim in ["shotsmoke", "shotsmokex", "shotilluminating", "shotcm"] || { "chemlight" in toLower _ammo } || { "smoke" in toLower _ammo }) exitWith {};
deleteVehicle _proj;
// give the round back (on foot; a vehicle round is simply lost)
if (isNull _veh) then {
    switch (true) do {
        case (_weapon in ["Throw", "Put"]): { _unit addMagazine _mag };
        case (_weapon == secondaryWeapon _unit && { _unit ammo _muzzle == 0 }): { _unit addSecondaryWeaponItem _mag };
        default { _unit setAmmo [_muzzle, (_unit ammo _muzzle) + 1] };
    };
};
if (time > (missionNamespace getVariable ["CQ_safeMsgT", -10]) + 3) then {
    CQ_safeMsgT = time;
    cutText [format ["<t font='PuristaMedium' size='1.2' color='#BA392C'>WEAPONS SAFE</t><br/><t font='PuristaLight' color='#F2F1DF'>No firing within %1 m of the base unless it is under attack</t>", CQ_safeZoneRadius], "PLAIN DOWN", 0.4, true, true];
};
