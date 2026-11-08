/*
    CQ_fnc_crateFill  (server)
    [_crate] call CQ_fnc_crateFill;
    Fills a supply crate with something for every player class: magazines of every weapon the
    playable roles carry (CQ_crateRoles, read from their config), launcher rounds, grenades,
    smokes, 40 mm, medical, engineer gear and explosives.
*/
params ["_c"];
clearWeaponCargoGlobal _c; clearMagazineCargoGlobal _c; clearItemCargoGlobal _c; clearBackpackCargoGlobal _c;

if (isNil "CQ_crateMags") then {
    private _mags = createHashMap;
    {
        private _cfg = configFile >> "CfgVehicles" >> _x;
        {
            private _w = _x;
            if (_w in ["Throw", "Put"]) then { continue };
            private _m = (getArray (configFile >> "CfgWeapons" >> _w >> "magazines")) param [0, ""];
            if (_m != "") then { _mags set [_m, (_mags getOrDefault [_m, 0]) + 1] };
        } forEach getArray (_cfg >> "weapons");
    } forEach CQ_crateRoles;
    CQ_crateMags = _mags;
};
{
    private _big = getNumber (configFile >> "CfgMagazines" >> _x >> "count") >= 100;
    private _isRocket = getNumber (configFile >> "CfgMagazines" >> _x >> "count") <= 2;
    _c addMagazineCargoGlobal [_x, [[20, 4] select _isRocket, 8] select _big];
} forEach (keys CQ_crateMags);
{ _x params ["_cls", "_n"]; _c addMagazineCargoGlobal [_cls, _n] } forEach CQ_crateExtraMags;
{ _x params ["_cls", "_n"]; _c addItemCargoGlobal [_cls, _n] } forEach CQ_crateItems;
_c setVariable ["CQ_crate", true, true];
