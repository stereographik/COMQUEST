/*
    CQ_fnc_crateFill  (server)
    [_crate] call CQ_fnc_crateFill;
    [_vehicle, _factor, false] call CQ_fnc_crateFill;     (auto-fill of a vehicle)
    Fills a supply crate (or a vehicle) with ammunition for every base-game weapon (rifles,
    SMGs, marksman/sniper rifles, machine guns, launchers; no pistols, no DLC), grenades,
    smokes, 40 mm, explosives, medical and engineer gear, plus the base-game launchers.
*/
params ["_c", ["_f", 1], ["_isCrate", true]];
private _n = { params ["_k"]; (round (_k * _f)) max 1 };
clearWeaponCargoGlobal _c; clearMagazineCargoGlobal _c; clearItemCargoGlobal _c; clearBackpackCargoGlobal _c;

// Magazine list, built once: one entry per magazine, for EVERY base-game rifle, SMG,
// marksman/sniper rifle, machine gun and launcher (CfgWeapons scope 2, no "dlc" entry,
// no handguns), so the crates follow whatever base-game weapon players take from the
// arsenal. Counts: player roles' own weapons 10, rifle/SMG 6, marksman/sniper 4, belts 3,
// launcher rounds 2; CQ_crateRifleMags / CQ_crateExtraMags override.
if (isNil "CQ_crateMags") then {
    private _mags = createHashMap;
    private _put = { params ["_m", "_k"]; _mags set [_m, (_mags getOrDefault [_m, 0]) max _k] };
    {
        private _w = configName _x;
        private _type = getNumber (_x >> "type");
        if (getNumber (_x >> "scope") == 2 && { _type in [1, 4] } && { getText (_x >> "dlc") == "" }) then {
            private _m = (getArray (_x >> "magazines")) param [0, ""];
            if (_m != "" && { isClass (configFile >> "CfgMagazines" >> _m) }) then {
                private _cnt = getNumber (configFile >> "CfgMagazines" >> _m >> "count");
                private _k = switch (true) do {
                    case (_type == 4): { 2 };
                    case (_cnt >= 75): { 3 };
                    case (_cnt <= 10): { 4 };
                    default { 6 };
                };
                [_m, _k] call _put;
            };
        };
    } forEach ("isClass _x" configClasses (configFile >> "CfgWeapons"));
    // the player roles' own weapons: more of those
    {
        {
            if (_x in ["Throw", "Put"] || { getNumber (configFile >> "CfgWeapons" >> _x >> "type") == 2 }) then { continue };
            private _m = (getArray (configFile >> "CfgWeapons" >> _x >> "magazines")) param [0, ""];
            if (_m != "") then { [_m, [10, 3] select (getNumber (configFile >> "CfgMagazines" >> _m >> "count") <= 2)] call _put };
        } forEach getArray (configFile >> "CfgVehicles" >> _x >> "weapons");
    } forEach CQ_crateRoles;
    { _x params ["_m", "_k"]; if (isClass (configFile >> "CfgMagazines" >> _m)) then { [_m, _k] call _put } } forEach (CQ_crateRifleMags + CQ_crateExtraMags);
    CQ_crateMags = _mags;
    ["Supply crates: %1 magazine types (base-game weapons)", [count _mags]] call CQ_fnc_log;
};
{ _c addMagazineCargoGlobal [_x, [_y] call _n] } forEach CQ_crateMags;
{ _x params ["_cls", "_k"]; _c addItemCargoGlobal [_cls, [_k] call _n] } forEach CQ_crateItems;
{ _x params ["_cls", "_k"]; _c addWeaponCargoGlobal [_cls, [_k] call _n] } forEach CQ_crateWeapons;
if (_isCrate) then { _c setVariable ["CQ_crate", true, true] };
