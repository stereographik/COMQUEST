/*
    CQ_fnc_vehRoamTick  (server, director task, every 30 s)
    Keeps every HQ vehicle that is not a truck roaming around its HQ: a new route
    (CQ_fnc_vehRoam) when it has none from the roam system yet, every CQ_vehRoamRefresh,
    or when it has not moved 15 m in 2 min outside combat (stuck or idle).
    Vehicles on other jobs (QRF, rearm, assault, transfer) are left alone.
*/
if (time < CQ_vehRoamNext) exitWith {};
CQ_vehRoamNext = time + 30;

{
    private _hq = _x;
    if !((_hq get "state") in CQ_activeStates && { _hq get "buildDone" }) then { continue };
    private _c = _hq get "pos";
    {
        private _v = _x;
        if (!alive _v || { _v isKindOf "Truck_F" } || { !canMove _v } || { _v getVariable ["CQ_busy", false] }) then { continue };
        private _g = group effectiveCommander _v;
        if (isNull _g || { !alive driver _v }) then { continue };
        if !((_g getVariable ["CQ_role", ""]) in ["patrol", ""]) then { continue };
        private _t = _g getVariable ["CQ_roamT", -1];
        private _renew = _t < 0 || { time - _t > CQ_vehRoamRefresh };
        if (!_renew && { behaviour leader _g != "COMBAT" }) then {
            if ((_v distance (_g getVariable ["CQ_roamPos", [0,0,0]])) > 15) then {
                _g setVariable ["CQ_roamPos", getPosATL _v];
                _g setVariable ["CQ_roamPosT", time];
            } else {
                if (time - (_g getVariable ["CQ_roamPosT", time]) > 120) then { _renew = true };
            };
        };
        if (_renew) then { [_g, _v, _c] call CQ_fnc_vehRoam };
    } forEach (_hq get "vehicles");
} forEach (values CQ_hqs);
