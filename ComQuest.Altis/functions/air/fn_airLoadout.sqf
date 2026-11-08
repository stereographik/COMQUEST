/*
    CQ_fnc_airLoadout  (server)
    [_heli] call CQ_fnc_airLoadout;
    Armed escorts carry 12 rockets + a gun. The PO-30 Orca's stock loadout is already
    2000 rounds + 12 rockets. Other helicopters (Kajman) get one 12-rocket rack on the first
    pylon that accepts it, the other pylons emptied; if no pylon takes a 12-rocket rack the
    stock loadout is kept (and logged).
*/
params ["_v"];

private _pylons = getPylonMagazines _v;
if (_pylons isEqualTo [] || { typeOf _v == "O_Heli_Light_02_dynamicLoadout_F" }) exitWith {};

private _slot = -1;
private _rack = "";
{
    private _r12 = (_v getCompatiblePylonMagazines (_forEachIndex + 1)) select { (_x find "12Rnd") > -1 };
    if (_r12 isNotEqualTo []) exitWith { _slot = _forEachIndex + 1; _rack = _r12 select 0 };
} forEach _pylons;

if (_slot < 0) exitWith {
    ["%1: no 12-rocket rack fits, stock loadout kept (%2)", [typeOf _v, _pylons]] call CQ_fnc_log;
};

{
    _v setPylonLoadout [_forEachIndex + 1, ["", _rack] select ((_forEachIndex + 1) == _slot), true];
} forEach _pylons;
["%1 loadout: %2 on pylon %3 + gun", [typeOf _v, _rack, _slot]] call CQ_fnc_log;
