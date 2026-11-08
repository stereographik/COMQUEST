/*
    CQ_fnc_hqRearmPass  (server, from CQ_fnc_logiTick)
    [_hq] call CQ_fnc_hqRearmPass;
    Rearms every CSAT soldier on foot, ground vehicle and static within CQ_rearmRadius of the
    HQ's depot, paying from the depot stock. (Aircraft rearm in CQ_fnc_airTick.)
*/
params ["_hq"];

private _stock = _hq get "stock";
if (_stock <= 0) exitWith {};
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
