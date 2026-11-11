/*
    CQ_fnc_classKit  (client)
    [_label] call CQ_fnc_classKit;
    Tops up the player's current (vanilla class) loadout so every class leaves the base
    fully kitted (CQ_classKit): the kit's backpack (replaces the vanilla one), primary mags, launcher rounds,
    grenades / role items, a sidearm with mags, then the CQ_basicKit items.
    Only base-game items (no DLC).
*/
params [["_label", "Rifleman"]];
private _k = CQ_classKit getOrDefault [_label, [8, 0, [], ""]];
_k params ["_priMags", "_rounds", "_items", "_pack"];

// Class gear first (CQ_classGear): uniform, vest, headgear, primary + attachments, launcher, NVG.
// Each item only if it exists and is not DLC (else the vanilla item stays).
private _okCfg = { params ["_c", "_root"]; _c != "" && { isClass (configFile >> _root >> _c) } && { getText (configFile >> _root >> _c >> "DLC") == "" } };
private _firstMag = { params ["_w"]; private _m = getArray (configFile >> "CfgWeapons" >> _w >> "magazines"); if (_m isEqualTo []) then { "" } else { _m select 0 } };
private _g = CQ_classGear getOrDefault [_label, []];
if (_g isNotEqualTo []) then {
    _g params ["_pri", "_atts", "_lau", "_uni", "_vest", "_head"];
    if (_uni != "" && { [_uni, "CfgWeapons"] call _okCfg }) then { private _it = uniformItems player; player forceAddUniform _uni; { if (player canAddItemToUniform _x) then { player addItemToUniform _x } } forEach _it };
    if (_vest == "-") then { removeVest player } else {
        if ([_vest, "CfgWeapons"] call _okCfg) then { private _it = vestItems player; removeVest player; player addVest _vest; { if (player canAddItemToVest _x) then { player addItemToVest _x } } forEach _it };
    };
    if (_head == "-") then { removeHeadgear player } else { if ([_head, "CfgWeapons"] call _okCfg) then { removeHeadgear player; player addHeadgear _head } };
    if ([_pri, "CfgWeapons"] call _okCfg) then {
        if (primaryWeapon player != "") then { { player removeMagazines _x } forEach (getArray (configFile >> "CfgWeapons" >> primaryWeapon player >> "magazines")); player removeWeapon primaryWeapon player };
        private _pm = [_pri] call _firstMag;
        if (_pm != "") then { player addMagazine _pm };     // loaded by addWeapon
        player addWeapon _pri;
        private _fit = (_pri call BIS_fnc_compatibleItems) apply { toLower _x };
        {
            private _choices = if (_x isEqualType "") then { [_x] } else { _x };
            private _pick = _choices param [_choices findIf { [_x, "CfgWeapons"] call _okCfg && { (toLower _x) in _fit } }, ""];
            if (_pick != "") then { player addPrimaryWeaponItem _pick };
        } forEach _atts;
    };
    if (_lau != "" && { [_lau, "CfgWeapons"] call _okCfg }) then {
        if (secondaryWeapon player != "") then { player removeWeapon secondaryWeapon player };
        private _lm = [_lau] call _firstMag;
        if (_lm != "") then { player addMagazine _lm };
        player addWeapon _lau;
    };
    if ([CQ_classNvg, "CfgWeapons"] call _okCfg && { hmd player == "" }) then { player linkItem CQ_classNvg };
};

// Room first: the kit's backpack always replaces the vanilla one (often smaller), so the
// launcher rounds and role items really fit; emptied, then refilled below
if (_pack != "") then {
    if (backpack player != _pack) then { removeBackpack player; player addBackpack _pack };
    clearAllItemsFromBackpack player;
};

// Same magazine as the weapon uses, else its first compatible one
private _magOf = {
    params ["_w", "_loaded"];
    if (_loaded isNotEqualTo []) exitWith { _loaded select 0 };
    private _m = getArray (configFile >> "CfgWeapons" >> _w >> "magazines");
    if (_m isEqualTo []) then { "" } else { _m select 0 }
};
private _fill = {   // add _mag until _n are carried (stops when full)
    params ["_mag", "_n"];
    if (_mag == "") exitWith {};
    private _have = { _x == _mag } count magazines player;
    for "_i" from 1 to (_n - _have) do {
        if !(player canAdd _mag) exitWith {};
        player addMagazine _mag;
    };
};

// Primary
private _pw = primaryWeapon player;
if (_pw != "") then {
    [[_pw, primaryWeaponMagazine player] call _magOf, _priMags] call _fill;
};

// Sidearm
CQ_classSidearm params ["_hg", "_hgMag", "_hgN"];
if (handgunWeapon player == "") then {
    player addMagazine _hgMag;   // goes into the gun
    player addWeapon _hg;
};
[[handgunWeapon player, handgunMagazine player] call _magOf, _hgN] call _fill;

// Launcher: _rounds in total, one in the tube
private _sw = secondaryWeapon player;
if (_sw != "" && { _rounds > 0 }) then {
    private _m = [_sw, secondaryWeaponMagazine player] call _magOf;
    private _loaded = [0, 1] select (secondaryWeaponMagazine player isNotEqualTo []);
    [_m, _rounds - _loaded] call _fill;
};

// Role items, grenades
{
    _x params ["_it", "_n"];
    if (isClass (configFile >> "CfgMagazines" >> _it)) then {
        [_it, _n] call _fill;
    } else {
        if (_it in ["Rangefinder", "Laserdesignator"]) then {
            if (binocular player != _it) then { player removeWeapon (binocular player); player addWeapon _it };
        } else {
            private _have = { _x == _it } count items player;
            for "_i" from 1 to (_n - _have) do { if !(player canAdd _it) exitWith {}; player addItem _it };
        };
    };
} forEach _items;

call CQ_fnc_basicKit;
