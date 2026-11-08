/*
    CQ_fnc_vehRoamTick  (server, director task, every 30 s)
    Keeps every HQ ground vehicle moving (armour, cars and troop trucks; supply / fuel /
    repair trucks keep their own jobs):
      - new roaming route (CQ_fnc_vehRoam) when it has none, every CQ_vehRoamRefresh, or
        when it has not moved 15 m in 90 s outside combat (stuck or idle)
      - under CQ_vehLowFuel it drives to the nearest HQ whose fuel tanker has fuel
        (role "refuel"); the depot pass (CQ_fnc_hqRearmPass) fills it, then it roams again
    Vehicles on other jobs (QRF, rearm, assault, transfer, busy) are left alone.
*/
if (time < CQ_vehRoamNext) exitWith {};
CQ_vehRoamNext = time + 30;

{
    private _hq = _x;
    if !((_hq get "state") in CQ_activeStates && { _hq get "buildDone" }) then { continue };
    private _c = _hq get "pos";
    {
        private _v = _x;
        if (!alive _v || { !canMove _v } || { _v getVariable ["CQ_busy", false] }) then { continue };
        if (getAmmoCargo _v > 0 || { getFuelCargo _v > 0 } || { getRepairCargo _v > 0 }) then { continue };
        private _g = group effectiveCommander _v;
        if (isNull _g || { !alive driver _v }) then { continue };
        private _role = _g getVariable ["CQ_role", ""];

        // refuelled: back to roaming
        if (_role == "refuel") then {
            if (fuel _v > 0.9) then { _g setVariable ["CQ_role", "patrol"]; [_g, _v, _c] call CQ_fnc_vehRoam };
            continue;
        };
        if !(_role in ["patrol", ""]) then { continue };

        // low fuel: nearest HQ with fuel, or home to wait for a delivery
        if (fuel _v < CQ_vehLowFuel) then {
            private _t = [getPosATL _v, CQ_vehFuelFullCost * 0.5, "fuel"] call CQ_fnc_nearestStockHq;
            if (count _t == 0) then { _t = _hq };
            private _dest = if (alive (_t get "tanker")) then { getPosATL (_t get "tanker") } else { _t get "pos" };
            [_g] call CQ_fnc_clearWaypoints;
            _g setVariable ["CQ_role", "refuel"];
            _g setSpeedMode "NORMAL";
            _g move (_dest getPos [15 + random 10, random 360]);
            ["HQ #%1: %2 low on fuel (%3%%), driving to HQ #%4", [_hq get "id", typeOf _v, round (100 * fuel _v), _t get "id"]] call CQ_fnc_log;
            continue;
        };

        private _t = _g getVariable ["CQ_roamT", -1];
        private _renew = _t < 0 || { time - _t > CQ_vehRoamRefresh };
        if (!_renew && { behaviour leader _g != "COMBAT" }) then {
            if ((_v distance (_g getVariable ["CQ_roamPos", [0,0,0]])) > 15) then {
                _g setVariable ["CQ_roamPos", getPosATL _v];
                _g setVariable ["CQ_roamPosT", time];
            } else {
                if (time - (_g getVariable ["CQ_roamPosT", time]) > 90) then { _renew = true };
            };
        };
        if (_renew) then { [_g, _v, _c] call CQ_fnc_vehRoam };
    } forEach (_hq get "vehicles");
} forEach (values CQ_hqs);
