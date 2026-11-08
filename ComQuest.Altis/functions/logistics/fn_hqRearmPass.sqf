/*
    CQ_fnc_hqRearmPass  (server, from CQ_fnc_logiTick)
    [_hq] call CQ_fnc_hqRearmPass;
    Rearms every CSAT soldier on foot, ground vehicle and static within CQ_rearmRadius of the
    HQ's depot, paying from the depot stock. (Aircraft rearm in CQ_fnc_airTick.)
*/
params ["_hq"];

private _stock = _hq get "stock";
private _dp = getPosATL (_hq get "depot");

{
    if (_stock <= 0) exitWith {};
    _stock = [_x, _stock, CQ_rearmUnitBelow] call CQ_fnc_rearmUnit;
} forEach ((_dp nearEntities [["CAManBase"], CQ_rearmRadius]) select { alive _x && { side group _x == east } && { vehicle _x == _x } });

{
    if (_stock <= 0) exitWith {};
    private _static = _x isKindOf "StaticWeapon";
    if (([_x] call CQ_fnc_vehAmmoLevel) < ([CQ_rearmVehBelow, CQ_rearmVehBelow + 0.1] select _static)) then {
        _stock = [_x, _stock, [CQ_vehRearmTo, 1] select _static] call CQ_fnc_rearmVeh;
    };
} forEach ((_dp nearEntities [["LandVehicle", "StaticWeapon"], CQ_rearmRadius + 30]) select { alive _x && { side group effectiveCommander _x == east } });

_hq set ["stock", _stock max 0];

// Ground vehicles next to the fuel tanker are refuelled from the HQ's fuel points
private _tk = _hq get "tanker";
if (alive _tk && { (_hq get "fuel") > 0 }) then {
    private _f = _hq get "fuel";
    {
        if (_f <= 0) exitWith {};
        private _need = 1 - fuel _x;
        if (_need > 0.05) then {
            private _add = _need min (_f / CQ_vehFuelFullCost);
            _x setFuel ((fuel _x + _add) min 1);
            _f = _f - _add * CQ_vehFuelFullCost;
        };
    } forEach ((_tk nearEntities [["LandVehicle"], 50]) select { alive _x && { _x != _tk } && { side group effectiveCommander _x == east } });
    _hq set ["fuel", _f max 0];
};
