/*
    CQ_fnc_arsenalOpen  (client, from the arsenal boxes' action)
    [] spawn CQ_fnc_arsenalOpen;
    Opens the arsenal with everything the full arsenal offers, minus the role gear of other
    classes (CQ_arsenalGates: launchers, machine guns, sniper rifles, grenade-launcher rifles,
    medikit, toolkit...). Magazines are all offered: anyone carries ammo for the squad.
    The catalogue is built once per client (CQ_arsenalCat), the box is a local helper object.
*/
if (isNil "CQ_arsenalCat") then {
    private _pub = {
        params ["_c"];
        private _s = if (isNumber (_c >> "scopeArsenal")) then { getNumber (_c >> "scopeArsenal") } else { getNumber (_c >> "scope") };
        _s == 2
    };
    private _tags = {      // every tag that can gate this item: both parts of BIS_fnc_itemType, "GL", and its name
        params ["_n", "_c"];
        private _t = _n call BIS_fnc_itemType;
        private _r = [_t select 0, _t select 1];
        if ((getArray (_c >> "muzzles")) findIf { !(_x in ["this", "SAFE"]) } > -1 && { (_t select 1) in ["AssaultRifle", "Rifle"] }) then { _r pushBack "GL" };
        _r
    };
    private _w = []; private _i = []; private _b = []; private _m = [];
    {
        private _n = configName _x;
        if !([_x] call _pub) then { continue };
        private _t = _n call BIS_fnc_itemType;
        if ((_t select 0) == "Weapon" || { (_t select 1) in ["Binocular", "LaserDesignator"] }) then {
            if ((_n call BIS_fnc_baseWeapon) != _n) then { continue };     // presets: the arsenal shows the base weapon
            _w pushBack [_n, [_n, _x] call _tags];
        } else {
            if ((_t select 0) in ["Item", "Equipment"]) then { _i pushBack [_n, [_n, _x] call _tags] };
        };
    } forEach ("true" configClasses (configFile >> "CfgWeapons"));
    { if ([_x] call _pub) then { _i pushBack [configName _x, ["Glasses"]] } } forEach ("true" configClasses (configFile >> "CfgGlasses"));
    { if (getNumber (_x >> "isBackpack") == 1 && { [_x] call _pub }) then { _b pushBack [configName _x, ["Backpack"]] } } forEach ("true" configClasses (configFile >> "CfgVehicles"));
    { if ([_x] call _pub) then { _m pushBack configName _x } } forEach ("true" configClasses (configFile >> "CfgMagazines"));
    CQ_arsenalCat = [_w, _i, _b, _m];
};

private _cls = player getVariable ["CQ_class", "Rifleman"];
// is this item gated away from my class?
private _barred = {
    params ["_n", "_tags"];
    private _ln = toLower _n;
    (CQ_arsenalGates findIf {
        _x params ["_g", "_allowed"];
        !(_cls in _allowed) && { (_g findIf {
            if ((_x select [0, 1]) == "@") then { (_ln find toLower (_x select [1])) > -1 } else { _x in _tags }
        }) > -1 }
    }) > -1
};
CQ_arsenalCat params ["_w", "_i", "_b", "_m"];
private _keep = { params ["_list"]; (_list select { !(_x call _barred) }) apply { _x select 0 } };

if (!isNull (missionNamespace getVariable ["CQ_arsenalObj", objNull])) then { deleteVehicle CQ_arsenalObj };
CQ_arsenalObj = "Land_HelipadEmpty_F" createVehicleLocal [0, 0, 0];
[CQ_arsenalObj, [_w] call _keep, false] call BIS_fnc_addVirtualWeaponCargo;
[CQ_arsenalObj, ([_i] call _keep) + (([_w] call _keep) select { ((_x call BIS_fnc_itemType) select 1) in ["Binocular", "LaserDesignator"] }), false] call BIS_fnc_addVirtualItemCargo;
[CQ_arsenalObj, [_b] call _keep, false] call BIS_fnc_addVirtualBackpackCargo;
[CQ_arsenalObj, _m, false] call BIS_fnc_addVirtualMagazineCargo;
["Open", [false, CQ_arsenalObj, player]] call BIS_fnc_arsenal;
