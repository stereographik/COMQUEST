/*
    CQ_fnc_rearmVeh  (server)
    [_vehicle, _stock, _to] call CQ_fnc_rearmVeh  ->  stock left
    Reloads a vehicle, static or aircraft up to _to (0..1), paying from _stock in proportion
    to what is missing (CQ_vehFullCost). Partial reload when the stock is short.
*/
params ["_v", "_stock", ["_to", CQ_vehRearmTo]];

private _lvl = [_v] call CQ_fnc_vehAmmoLevel;
if (_lvl >= _to - 0.05 || { _stock <= 0 }) exitWith { _stock };

private _kind = switch (true) do {
    case (_v isKindOf "StaticWeapon"): { "static" };
    case (_v isKindOf "Air"): { "air" };
    case (_v isKindOf "Tank" || { _v isKindOf "Wheeled_APC_F" }): { "armour" };
    default { "light" };
};
private _fullCost = CQ_vehFullCost get _kind;

private _cost = (_to - _lvl) * _fullCost;
if (_cost > _stock) then {
    _to = _lvl + _stock / _fullCost;
    _cost = _stock;
};

_v setVehicleAmmo _to;
if (_v isKindOf "Air") then {
    // pylons are not always covered by setVehicleAmmo; refill to the loadout's own maximum
    private _max = _v getVariable ["CQ_pylonMax", []];
    {
        if (_x != "") then {
            private _cap = _max param [_forEachIndex, getNumber (configFile >> "CfgMagazines" >> _x >> "count")];
            _v setAmmoOnPylon [_forEachIndex + 1, round (_to * _cap)];
        };
    } forEach (getPylonMagazines _v);
};

_stock - _cost
