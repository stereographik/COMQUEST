/*
    CQ_fnc_airLoadout  (server)
    [_heli] call CQ_fnc_airLoadout;
    Armed escorts carry 12 rockets + a gun. The PO-30 Orca's stock loadout is already
    2000 rounds + 12 rockets. Other helicopters get one 12-rocket rack on the first pylon
    that takes it; if none does (Kajman: 19-rocket pods + Scalpels), the rocket pods keep
    12 rockets in total and the missiles are removed. CQ_pylonMax stores the per-pylon
    maximum used by CQ_fnc_rearmVeh.
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

private _max = [];
if (_slot > 0) then {
    {
        private _m = ["", _rack] select ((_forEachIndex + 1) == _slot);
        _v setPylonLoadout [_forEachIndex + 1, _m, true];
        _max pushBack ([0, 12] select (_m != ""));
    } forEach _pylons;
    ["%1 loadout: %2 on pylon %3 + gun", [typeOf _v, _rack, _slot]] call CQ_fnc_log;
} else {
    // No 12-rocket rack: keep the rocket pods, split 12 rockets between them, drop the missiles
    private _rocketIdx = [];
    { if ((toLower _x find "rocket") > -1) then { _rocketIdx pushBack _forEachIndex } } forEach _pylons;
    private _per = if (_rocketIdx isEqualTo []) then { 0 } else { floor (12 / count _rocketIdx) };
    {
        if (_forEachIndex in _rocketIdx) then {
            _v setAmmoOnPylon [_forEachIndex + 1, _per];
            _max pushBack _per;
        } else {
            _v setPylonLoadout [_forEachIndex + 1, "", true];
            _max pushBack 0;
        };
    } forEach _pylons;
    ["%1 loadout: %2 rockets on %3 pods + gun, missiles removed", [typeOf _v, _per * count _rocketIdx, count _rocketIdx]] call CQ_fnc_log;
};
_v setVariable ["CQ_pylonMax", _max];
