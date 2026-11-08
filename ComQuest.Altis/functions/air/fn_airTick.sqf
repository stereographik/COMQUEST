/*
    CQ_fnc_airTick  (server, director task)
    Every helicopter under the air manager:
      toPark   -> flies to its pad and lands        -> parked (engine off, waiting for orders)
      parked   -> armed and low on ammo             -> toRearm
      hunting  -> search & destroy CQ_heliHuntTime  -> toPark, or toRearm when ammo runs low
      toRearm  -> lands at the nearest HQ with stock (or waits at the main HQ) -> rearming
      rearming -> CQ_airRearmTime on the ground, paid from that depot; no stock: keeps waiting
    Fleet aircraft whose main HQ fell are re-based at the new main HQ.
*/
private _goRearm = {
    params ["_e"];
    private _v = _e get "veh";
    private _t = [getPosATL _v, CQ_rearmMinStock] call CQ_fnc_nearestStockHq;
    if (count _t == 0) then { _t = CQ_hqs getOrDefault [CQ_hubId, createHashMap] };
    if (count _t == 0) then { _t = CQ_hqs getOrDefault [_e get "homeId", createHashMap] };
    if (count _t == 0) exitWith { _e set ["state", "toPark"]; _e set ["landing", false] };
    _e set ["target", _t get "id"];
    _e set ["state", "toRearm"];
    _e set ["landing", false];
    [_e get "grp"] call CQ_fnc_clearWaypoints;
    (_e get "grp") setBehaviour "AWARE";
    _v engineOn true;
    ["Air: %1 low on ammo (%2%%), heading to HQ #%3 to rearm", [typeOf _v, round (100 * ([_v] call CQ_fnc_vehAmmoLevel)), _t get "id"]] call CQ_fnc_log;
};
// Fly to a pad and land on it; true once on the ground
private _landAt = {
    params ["_e", "_pad"];
    private _v = _e get "veh";
    if (_v distance2D _pad > 150) exitWith { _v doMove (getPosATL _pad); false };
    if (isTouchingGround _v) exitWith { true };
    if !(_e get "landing") then { _v land "LAND"; _e set ["landing", true] };
    false
};

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
        _e set ["landing", false];
        _v engineOn true;
    };

    private _armed = (_e get "kind") == "armed";
    private _lvl = if (_armed) then { [_v] call CQ_fnc_vehAmmoLevel } else { 1 };
    if (CQ_debug) then {
        private _lbl = format ["%1 %2 ammo %3%%", _e get "kind", _e get "state", round (100 * _lvl)];
        if ((_v getVariable ["CQ_dbg", ""]) != _lbl) then { _v setVariable ["CQ_dbg", _lbl, true] };
    };

    switch (_e get "state") do {
        case "toPark": {
            if ([_e, _e get "pad"] call _landAt) then {
                _v engineOn false;
                _g setBehaviour "SAFE";
                _e set ["state", "parked"];
                _e set ["landing", false];
            };
        };
        case "parked": {
            if (_armed && { _lvl < CQ_airLowAmmo }) then { [_e] call _goRearm };
        };
        case "hunting": {
            if (_lvl < CQ_airLowAmmo) then {
                [_e] call _goRearm;
            } else {
                if (time > (_e get "until")) then {
                    [_g] call CQ_fnc_clearWaypoints;
                    _g setBehaviour "AWARE";
                    _e set ["state", "toPark"];
                    _e set ["landing", false];
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
                    _e set ["landing", false];
                };
            };
        };
        case "rearming": {
            if (time > (_e get "until")) then {
                private _t = CQ_hqs getOrDefault [_e get "target", createHashMap];
                if (count _t > 0 && { alive (_t get "depot") } && { (_t get "stock") > 0 }) then {
                    _t set ["stock", [_v, _t get "stock", 1] call CQ_fnc_rearmVeh];
                    ["Air: %1 rearmed at HQ #%2 (%3%%), stock left %4", [typeOf _v, _t get "id", round (100 * ([_v] call CQ_fnc_vehAmmoLevel)), round (_t get "stock")]] call CQ_fnc_log;
                };
                if (([_v] call CQ_fnc_vehAmmoLevel) < CQ_airLowAmmo) then {
                    _e set ["until", time + CQ_airRearmTime];          // no ammo here yet: wait for a delivery
                } else {
                    _v engineOn true;
                    _e set ["state", "toPark"];
                    _e set ["landing", false];
                };
            };
        };
    };
} forEach CQ_air;

CQ_air = CQ_air select { !(_x getOrDefault ["dead", false]) };
