/*
    CQ_fnc_logiTick  (server, director task, runs every CQ_logiTickSeconds)
    The enemy's ammo brain:
      1 Main HQ (supply hub) = oldest built HQ whose depot stands. Its cap is CQ_hubCap.
      2 Rearm pass at every depot (soldiers, vehicles, statics nearby).
      3 Groups low on ammo stop and go to the nearest stocked HQ; rearmed groups go home.
      4 HQs linked to the hub by radio and under CQ_requestShare of their cap (ammo or fuel)
        get a HEMTT from the hub carrying ammo + fuel (CQ_fnc_truckRun).
      5 Supply flight (ammo + fuel) to the hub every CQ_ammoFlightInterval (CQ_fnc_ammoFlight).
*/
if (time < CQ_logiNext) exitWith {};
CQ_logiNext = time + CQ_logiTickSeconds;

private _active = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
private _built = _active select { (_x get "buildDone") && { alive (_x get "depot") } };

// ---- 1 main HQ
private _hub = createHashMap;
if (_built isNotEqualTo []) then { _hub = ([_built, [], { _x get "born" }, "ASCEND"] call BIS_fnc_sortBy) select 0 };
private _hubId = if (count _hub > 0) then { _hub get "id" } else { -1 };
if (_hubId != CQ_hubId) then {
    CQ_hubId = _hubId;
    if (_hubId > -1) then {
        if (CQ_nextAmmoFlight < 0) then { CQ_nextAmmoFlight = time + CQ_ammoFlightInterval };
        ["Enemy supply hub", format ["HQ #%1 is now the enemy's MAIN HQ: ammo flights land there, ammo trucks leave from there", _hubId]] call CQ_fnc_announce;
    } else {
        ["Enemy supply hub lost", "The enemy has no main HQ left: no more ammo flights or trucks until one is rebuilt"] call CQ_fnc_announce;
    };
};
{ _x set ["cap", [CQ_depotCap, CQ_hubCap] select ((_x get "id") == _hubId)] } forEach _built;

// ---- 2 rearm at depots
{ [_x] call CQ_fnc_hqRearmPass } forEach _built;

// ---- 3 low-ammo groups pull back, rearmed groups return
{
    private _home = _x;
    if ((_home get "state") == "Inbound") then { continue };
    private _hc = _home get "pos";

    private _send = {
        params ["_g", "_isVeh"];
        private _t = [getPosATL leader _g, CQ_rearmMinStock] call CQ_fnc_nearestStockHq;
        // Nothing stocked anywhere: keep patrolling with what is left (no point queuing at an empty depot)
        if (count _t == 0) exitWith {
            if !(_g getVariable ["CQ_dryWarned", false]) then {
                _g setVariable ["CQ_dryWarned", true];
                ["HQ #%1: %2 low on ammo but no depot has any, keeps patrolling", [_home get "id", groupId _g]] call CQ_fnc_log;
            };
        };
        _g setVariable ["CQ_dryWarned", false];
        _g setVariable ["CQ_rearmSince", time];
        [_g] call CQ_fnc_clearWaypoints;
        _g setVariable ["CQ_prevRole", _g getVariable ["CQ_role", "patrol"]];
        _g setVariable ["CQ_role", "rearm"];
        private _dest = if (alive (_t get "depot")) then { getPosATL (_t get "depot") } else { _t get "pos" };
        _g move (_dest getPos [[15, 30] select _isVeh, random 360]);
        ["HQ #%1: %2 low on ammo, pulling back to HQ #%3 to rearm", [_home get "id", groupId _g, _t get "id"]] call CQ_fnc_log;
    };
    private _back = {
        params ["_g"];
        [_g] call CQ_fnc_clearWaypoints;
        _g setVariable ["CQ_roamT", -1];   // vehicles: CQ_fnc_vehRoamTick gives them a new route
        private _prev = _g getVariable ["CQ_prevRole", "patrol"];
        if (_prev == "defend") then {
            _g setVariable ["CQ_role", "defend"];
            [_g, _hc] call BIS_fnc_taskDefend;
        } else {
            _g setVariable ["CQ_role", "patrol"];
            [_g, _hc, CQ_patrolRadius select 0] call CQ_fnc_infPatrol;
        };
    };

    {
        private _g = _x;
        if (isNull _g || { ({ alive _x } count units _g) == 0 }) then { continue };
        private _role = _g getVariable ["CQ_role", ""];
        private _r = [_g] call CQ_fnc_infAmmo;
        if (CQ_debug) then { _g setVariable ["CQ_dbg", format ["HQ%1 %2 ammo %3%%", _home get "id", _role, round (100 * _r)], true] };
        if (_role in ["patrol", "qrf", "reinf"] && { _r < CQ_lowAmmo }) then {
            // far from home: the HQ drives its field truck out; otherwise the group walks back
            if !([_home, _g] call CQ_fnc_fieldResupplyTry) then { [_g, false] call _send };
        };
        if (_role == "rearm" && { _r >= 0.8 || { time - (_g getVariable ["CQ_rearmSince", time]) > CQ_rearmWaitMax } }) then { [_g] call _back };
        if (_role == "waitSupply" && { !(_home get "fieldRun") }) then {
            _g setVariable ["CQ_role", _g getVariable ["CQ_prevRole", "patrol"]];   // truck gone: re-evaluated next pass
        };
    } forEach (_home get "infantry");

    {
        private _v = _x;
        private _g = group effectiveCommander _v;
        if (!alive _v || { isNull _g }) then { continue };
        private _role = _g getVariable ["CQ_role", ""];
        private _l = [_v] call CQ_fnc_vehAmmoLevel;
        if (CQ_debug) then { _v setVariable ["CQ_dbg", format ["HQ%1 %2 ammo %3%%", _home get "id", _role, round (100 * _l)], true] };
        if (_role in ["patrol", "qrf"] && { _l < CQ_vehLowAmmo }) then { [_g, true] call _send };
        if (_role == "rearm" && { _l >= CQ_vehRearmTo - 0.1 || { time - (_g getVariable ["CQ_rearmSince", time]) > CQ_rearmWaitMax } }) then { [_g] call _back };
    } forEach (_home get "vehicles");
} forEach _active;

// ---- 4 delivery requests (trucks leave the main HQ)
if (_hubId > -1) then {
    private _linked = [_hub, _built] call CQ_fnc_hqLinks;
    {
        private _h = _x;
        private _id = _h get "id";
        if (_id == _hubId) then { continue };
        private _fuelOk = alive (_h get "tanker") && { alive (_hub get "tanker") };   // fuel only between two tankers
        private _low = (_h get "stock") < CQ_requestShare * (_h get "cap") || { _fuelOk && { (_h get "fuel") < CQ_requestShare * (_h get "cap") } };
        if (!_low) then { _h set ["lowWarned", false]; continue };

        if !(_id in _linked) then {
            if !(_h get "lowWarned") then {
                _h set ["lowWarned", true];
                ["Enemy HQ low on ammo", format ["HQ #%1 is running out of ammo and has no radio link to the main HQ", _id]] call CQ_fnc_announce;
            };
            continue;
        };
        if (_h get "truckInbound") then { continue };
        if (CQ_trucksActive >= CQ_trucksMax) then { continue };

        private _load = (CQ_truckLoad min ((_hub get "stock") - CQ_hubReserve) min ((_h get "cap") - (_h get "stock"))) max 0;
        private _fuelLoad = if (_fuelOk) then { (CQ_truckFuelLoad min ((_hub get "fuel") - CQ_hubFuelReserve) min ((_h get "cap") - (_h get "fuel"))) max 0 } else { 0 };
        if (_load < 30 && { _fuelLoad < 30 }) then { continue };

        _hub set ["stock", (_hub get "stock") - _load];
        _hub set ["fuel", (_hub get "fuel") - _fuelLoad];
        _h set ["truckInbound", true];
        CQ_trucksActive = CQ_trucksActive + 1;
        [_hub, _h, _load, _fuelLoad] spawn CQ_fnc_truckRun;
    } forEach _built;
};

// ---- 5 ammo flight to the main HQ (brought forward when the hub runs dry)
if (_hubId > -1 && { !CQ_ammoFlightActive } && { (_hub get "stock") < CQ_hubLowShare * (_hub get "cap") }
    && { CQ_nextAmmoFlight - time > CQ_hubLowFlightDelay }) then {
    CQ_nextAmmoFlight = time + CQ_hubLowFlightDelay;
    ["Main HQ #%1 low on ammo (%2): supply flight brought forward", [_hubId, round (_hub get "stock")]] call CQ_fnc_log;
};
if (_hubId > -1 && { !CQ_ammoFlightActive } && { CQ_nextAmmoFlight > 0 } && { time >= CQ_nextAmmoFlight }) then {
    CQ_nextAmmoFlight = time + CQ_ammoFlightInterval;
    CQ_ammoFlightActive = true;
    [_hub] spawn CQ_fnc_ammoFlight;
};

// ---- debug: stock report every minute
if (CQ_debug && { time >= CQ_logiReportT }) then {
    CQ_logiReportT = time + 60;
    { (format ["cq_hq_%1_exact", _x get "id"]) setMarkerText format ["DEBUG HQ #%1 %2 | ammo %3 fuel %4 /%5", _x get "id", _x get "state", round (_x get "stock"), round (_x get "fuel"), _x get "cap"] } forEach _built;
    private _parts = _built apply { format ["HQ%1%2 ammo %3 fuel %4 /%5", _x get "id", ["", "(main)"] select ((_x get "id") == _hubId), round (_x get "stock"), round (_x get "fuel"), _x get "cap"] };
    ["Stocks: %1 | trucks on the road %2 | aircraft %3 | enemy AI %4", [_parts joinString ", ", CQ_trucksActive, count CQ_air, call CQ_fnc_enemyCount]] call CQ_fnc_log;
};
