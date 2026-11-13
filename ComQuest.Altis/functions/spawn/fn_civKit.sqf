/*
    CQ_fnc_civKit
    [_unit, _role] call CQ_fnc_civKit;
    Arms a civilian-dressed guerilla: everything off but the clothes, a bandolier (CQ_civVests),
    then the weapon kit of the role from CQ_civKits (base game, Katiba family):
      leader, rifle, carbine, gl, mg, at, marksman, medic
    Works on any local unit (server groups, the intro's local actors).
*/
params ["_u", ["_role", "rifle"]];
private _kit = CQ_civKits getOrDefault [_role, CQ_civKits get "rifle"];
_kit params ["_wpn", "_mag", "_nMag", ["_opt", ""], ["_lnc", ""], ["_rkt", ""], ["_nRkt", 0], ["_extra", []]];

removeAllWeapons _u;
removeVest _u;
removeBackpack _u;
removeHeadgear _u;
removeGoggles _u;
_u addVest (selectRandom CQ_civVests);
if (_lnc != "") then { _u addBackpack (selectRandom CQ_civPacks) };
for "_i" from 1 to _nMag do { _u addMagazine _mag };
_u addWeapon _wpn;
if (_opt != "") then { _u addPrimaryWeaponItem _opt };
if (_lnc != "") then {
    for "_i" from 1 to _nRkt do { _u addMagazine _rkt };
    _u addWeapon _lnc;
};
{ _x params ["_it", "_n"]; for "_i" from 1 to _n do { _u addItem _it } } forEach _extra;
if (random 1 < 0.5) then { _u addHeadgear (selectRandom CQ_civHats) };
_u selectWeapon _wpn;
