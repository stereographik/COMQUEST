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
        if (_it == "Rangefinder") then {
            if (binocular player != "Rangefinder") then { player removeWeapon (binocular player); player addWeapon "Rangefinder" };
        } else {
            private _have = { _x == _it } count items player;
            for "_i" from 1 to (_n - _have) do { if !(player canAdd _it) exitWith {}; player addItem _it };
        };
    };
} forEach _items;

call CQ_fnc_basicKit;
