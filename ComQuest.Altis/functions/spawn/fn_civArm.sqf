/*
    CQ_fnc_civArm  (server)
    [_group, _pos, _role, _radius] call CQ_fnc_civArm  ->  unit
    An armed civilian for the enemy side: a random civilian outfit (CQ_civClasses) created in
    _group (CSAT side, so they fight as enemies) and armed for _role (CQ_fnc_civKit).
    Callers still run CQ_fnc_unitPrep on them (limited ammo like every enemy soldier).
*/
params ["_g", "_pos", ["_role", "rifle"], ["_rad", 8]];
if (isNil "CQ_civClassesOk") then {
    CQ_civClassesOk = CQ_civClasses select { isClass (configFile >> "CfgVehicles" >> _x) && { getText (configFile >> "CfgVehicles" >> _x >> "DLC") == "" } };
    if (CQ_civClassesOk isEqualTo []) then { CQ_civClassesOk = ["C_man_1"] };
};
private _u = _g createUnit [selectRandom CQ_civClassesOk, _pos, [], _rad, "NONE"];
[_u, _role] call CQ_fnc_civKit;
_u setVariable ["CQ_civArmed", true];
_u
