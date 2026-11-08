/*
    CQ_fnc_airTick  (server, director task)
    Every helicopter under the air manager:
      toPark   -> flies to its pad and lands        -> parked (engine off, waiting for orders)
      parked   -> low on ammo (armed) or fuel (any) -> toRearm
      parked   -> (armed, rested, fuel/ammo ok)     -> patrolling (CQ_fnc_airPatrol)
      patrolling -> wandering pattern round an HQ   -> toPark when the sortie ends, toRearm when low
      hunting  -> search & destroy CQ_heliHuntTime  -> toPark, or toRearm when ammo/fuel runs low
      toRearm  -> lands at the nearest HQ holding what it lacks (or waits at the main HQ) -> rearming
      rearming -> CQ_airRearmTime on the ground: rearm (depot) + refuel (fuel tanker);
                  still short (no stock there): keeps waiting for a delivery
    Fleet aircraft whose main HQ fell are re-based at the new main HQ.
*/
private _goRearm = {
    params ["_e"];
    private _v = _e get "veh";
    private _needFuel = fuel _v < CQ_airLowFuel;
    private _t = if (_needFuel) then { [getPosATL _v, CQ_rearmMinFuel, "fuel"] call CQ_fnc_nearestStockHq } else { [getPosATL _v, CQ_rearmMinStock] call CQ_fnc_nearestStockHq };
    if (count _t == 0) then { _t = CQ_hqs getOrDefault [CQ_hubId, createHashMap] };
    if (count _t == 0) then { _t = CQ_hqs getOrDefault [_e get "homeId", createHashMap] };
    if (count _t == 0) exitWith { _e set ["state", "toPark"]; _e set ["nearT", -1] };
    _e set ["target", _t get "id"];
    _e set ["state", "toRearm"];
    _e set ["nearT", -1];
    [_e get "grp"] call CQ_fnc_clearWaypoints;
    (_e get "grp") setBehaviour "AWARE";
    _v engineOn true;
    ["Air: %1 low (ammo %2%%, fuel %3%%), heading to HQ #%4 to resupply", [typeOf _v, round (100 * ([_v] call CQ_fnc_vehAmmoLevel)), round (100 * fuel _v), _t get "id"]] call CQ_fnc_log;
};
// Fly to a pad and land on it; true once on the ground (re-issued orders + fallback)
private _landAt = {
    params ["_e", "_pad"];
    [_e get "veh", _pad, _e] call CQ_fnc_airLandStep
};

// Armed helis allowed on patrol at the same time (the rest stay parked as quick reaction)
private _armedAll = CQ_air select { (_x get "kind") == "armed" };
private _patrolSlots = (ceil (CQ_airPatrolShare * count _armedAll)) - ({ (_x get "state") == "patrolling" } count _armedAll);

{
    private _e = _x;
    private _v = _e get "veh";
    private _g = _e get "grp";

    if (!alive _v || { !alive driver _v }) then {
        _e set ["dead", true];
        if ((_e get "kind") == "armed") then {
            ["Enemy helicopter down", format ["A CSAT %1 has been destroyed", getText (configOf _v >> "displayName")]] call CQ_fnc_announce;
        };
        continue;
    };

    // Re-base fleet aircraft when their main HQ is gone
    private _home = _e get "homeId";
    if (_home > -1 && { !(((CQ_hqs getOrDefault [_home, createHashMap]) getOrDefault ["state", ""]) in CQ_activeStates) }) then {
        _e set ["homeId", -1]; _home = -1;
    };
    if (_home == -1 && { CQ_hubId > -1 } && { (_e get "state") in ["parked", "toPark"] } && { ((CQ_hqs get CQ_hubId) get "pos") distance2D (_e get "pad") > 400 }) then {
        deleteVehicle (_e get "pad");
        _e set ["pad", [(CQ_hqs get CQ_hubId) get "pos"] call CQ_fnc_airParkSpot];
        _e set ["state", "toPark"];
        _e set ["nearT", -1];
        _v engineOn true;
    };

    private _armed = (_e get "kind") == "armed";
    private _lvl = if (_armed) then { [_v] call CQ_fnc_vehAmmoLevel } else { 1 };
    private _low = (_armed && { _lvl < CQ_airLowAmmo }) || { fuel _v < CQ_airLowFuel };
    if (CQ_debug) then {
        private _lbl = format ["%1 %2 ammo %3%% fuel %4%%", _e get "kind", _e get "state", round (100 * _lvl), round (100 * fuel _v)];
        if ((_v getVariable ["CQ_dbg", ""]) != _lbl) then { _v setVariable ["CQ_dbg", _lbl, true] };
    };

    switch (_e get "state") do {
        case "toPark": {
            if ([_e, _e get "pad"] call _landAt) then {
                _v engineOn false;
                _g setBehaviour "SAFE";
                _e set ["state", "parked"];
                _e set ["nearT", -1];
                _e set ["restUntil", time + (CQ_airPatrolRest select 0) + random ((CQ_airPatrolRest select 1) - (CQ_airPatrolRest select 0))];
            };
        };
        case "parked": {
            if (_low) then { [_e] call _goRearm };
            if (!_low && { _armed } && { _patrolSlots > 0 } && { time > (_e getOrDefault ["restUntil", 0]) }
                && { fuel _v >= CQ_airPatrolMinFuel } && { _lvl >= CQ_airLowAmmo + 0.15 }) then {
                // Patrol its home HQ most of the time, sometimes a neighbouring one
                private _homeHq = CQ_hqs getOrDefault [_home, createHashMap];
                private _near = (values CQ_hqs) select {
                    (_x get "state") in CQ_activeStates && { (_x get "pos") distance2D _v < CQ_airPatrolNearHq }
                };
                private _hq = _homeHq;
                if (_near isNotEqualTo [] && { count _homeHq == 0 || { random 1 < 0.4 } }) then { _hq = selectRandom _near };
                if (count _hq > 0) then {
                    [_e, _hq] call CQ_fnc_airPatrol;
                    _patrolSlots = _patrolSlots - 1;
                };
            };
        };
        case "patrolling": {
            private _t = CQ_hqs getOrDefault [_e get "target", createHashMap];
            if (_low) then {
                [_e] call _goRearm;
            } else {
                if (time > (_e get "until") || { count _t == 0 } || { !((_t get "state") in CQ_activeStates) }) then {
                    [_g] call CQ_fnc_clearWaypoints;
                    _g setSpeedMode "NORMAL";
                    _v flyInHeight CQ_heightEscort;
                    _e set ["state", "toPark"];
                    _e set ["nearT", -1];
                };
            };
        };
        case "hunting": {
            if (_low) then {
                [_e] call _goRearm;
            } else {
                if (time > (_e get "until")) then {
                    [_g] call CQ_fnc_clearWaypoints;
                    _g setBehaviour "AWARE";
                    _e set ["state", "toPark"];
                    _e set ["nearT", -1];
                };
            };
        };
        case "toRearm": {
            private _t = CQ_hqs getOrDefault [_e get "target", createHashMap];
            if (count _t == 0 || { !((_t get "state") in CQ_activeStates) }) then {
                [_e] call _goRearm;
            } else {
                private _pad = if ((_t get "id") == _home && { !isNull (_t get "pad") }) then { _t get "pad" } else { [_t] call CQ_fnc_hqAirPad };
                if ([_e, _pad] call _landAt) then {
                    _v engineOn false;
                    _e set ["state", "rearming"];
                    _e set ["until", time + CQ_airRearmTime];
                    _e set ["nearT", -1];
                };
            };
        };
        case "rearming": {
            if (time > (_e get "until")) then {
                private _t = CQ_hqs getOrDefault [_e get "target", createHashMap];
                if (count _t > 0) then {
                    if (_armed && { alive (_t get "depot") } && { (_t get "stock") > 0 }) then {
                        _t set ["stock", [_v, _t get "stock", 1] call CQ_fnc_rearmVeh];
                    };
                    private _need = 1 - fuel _v;
                    if (_need > 0.02 && { alive (_t get "tanker") } && { (_t get "fuel") > 0 }) then {
                        private _add = _need min ((_t get "fuel") / CQ_fuelFullCost);
                        _v setFuel ((fuel _v + _add) min 1);
                        _t set ["fuel", ((_t get "fuel") - _add * CQ_fuelFullCost) max 0];
                    };
                    ["Air: %1 resupplied at HQ #%2 (ammo %3%%, fuel %4%%), depot left %5 ammo %6 fuel", [typeOf _v, _t get "id",
                        round (100 * ([_v] call CQ_fnc_vehAmmoLevel)), round (100 * fuel _v), round (_t get "stock"), round (_t get "fuel")]] call CQ_fnc_log;
                };
                if ((_armed && { ([_v] call CQ_fnc_vehAmmoLevel) < CQ_airLowAmmo }) || { fuel _v < CQ_airLowFuel + 0.1 }) then {
                    _e set ["until", time + CQ_airRearmTime];          // no ammo here yet: wait for a delivery
                } else {
                    _v engineOn true;
                    _e set ["state", "toPark"];
                    _e set ["nearT", -1];
                };
            };
        };
    };
} forEach CQ_air;

CQ_air = CQ_air select { !(_x getOrDefault ["dead", false]) };
