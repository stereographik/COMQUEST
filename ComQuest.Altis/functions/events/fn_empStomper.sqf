/*
    CQ_fnc_empStomper  (server, spawned by CQ_fnc_empDefuse)
    The captured EMP's carrier: an indestructible Stomper (CQ_empStomper, AI crew, never a data
    link relay) created at the nearest military site outside the war zone (CQ_empCampTypes on the
    map, or our base; none closer than CQ_empWarZone m to an enemy HQ, the device or an enemy
    soldier). It runs its plan on its own, phases always in this order:
      pickup   drives to the device; within CQ_empLoadR m it loads it on its roof
      strike   once a target is programmed (CQ_fnc_empProgram, any time: it waits for it),
               drives there and goes off within CQ_empStrikeR m (CQ_fnc_empBlast "strike")
    Not moved for CQ_empStuck s: nudged CQ_empNudge m along its route. Shown to everyone
    (marker cq_emp_ugv).
*/
if (!isServer || { isNil "CQ_empState" }) exitWith {};
private _s = CQ_empState;
private _dev = _s get "device";
private _dp = _s get "pos";

// ---- spawn: nearest military site (or our base) outside the war zone
private _hqPos = (values CQ_hqs) select { (_x get "state") in CQ_activeStates } apply { _x get "pos" };
private _enemy = allUnits select { alive _x && { side _x == east } };
private _sites = (nearestObjects [[worldSize / 2, worldSize / 2, 0], CQ_empCampTypes, worldSize]) apply { getPos _x };
_sites pushBack (missionNamespace getVariable ["CQ_magPadPos", CQ_basePos]);
_sites = _sites select {
    private _q = _x;
    _q distance2D _dp > CQ_empWarZone
    && { (_hqPos findIf { _x distance2D _q < CQ_empWarZone }) == -1 }
    && { (_enemy findIf { _x distance2D _q < CQ_empWarZone }) == -1 }
};
if (_sites isEqualTo []) then { _sites = [missionNamespace getVariable ["CQ_magPadPos", CQ_basePos]] };
_sites = [_sites, [], { _x distance2D _dp }, "ASCEND"] call BIS_fnc_sortBy;
private _sp = (_sites select 0) findEmptyPosition [3, 60, CQ_empStomper];
if (_sp isEqualTo []) then { _sp = _sites select 0 };
private _v = createVehicle [CQ_empStomper, _sp, [], 0, "NONE"];
_v allowDamage false;
_v setVariable ["CQ_noRelay", true, true];          // never a data link relay (CQ_fnc_linkTick)
_v setVariable ["CQ_empStomper", true, true];
_v lock 2;
private _g = createVehicleCrew _v;
{ _x allowDamage false } forEach crew _v;
_g setBehaviour "CARELESS"; _g setCombatMode "BLUE"; _g setSpeedMode "FULL";
_g enableDynamicSimulation false;
_s set ["stomper", _v];
private _m = createMarker ["cq_emp_ugv", getPos _v];
_m setMarkerType "b_uav";
_m setMarkerColor "ColorWEST";
_m setMarkerText " EMP Stomper";
["EMP event: Stomper created at %1 (%2 m from the device)", [mapGridPosition _v, round (_v distance2D _dp)]] call CQ_fnc_log;

// ---- the plan
private _lastP = getPosATL _v;
private _lastMoveT = time;
private _orderT = -1e6;
while { !isNull _v && { (missionNamespace getVariable ["CQ_empPhase", ""]) == "defused" } } do {
    private _loaded = _s get "loaded";
    private _tgt = _s get "target";
    private _goal = if (!_loaded) then { getPosATL _dev } else { _tgt };
    "cq_emp_ugv" setMarkerPos getPos _v;
    "cq_emp_ugv" setMarkerText ([" EMP Stomper (to the device)", " EMP Stomper (loaded, waiting for a target)", " EMP Stomper (to the target)"] select ([0, [1, 2] select (_tgt isNotEqualTo [])] select _loaded));
    if (_goal isNotEqualTo []) then {
        private _dd = _v distance2D _goal;
        // pickup
        if (!_loaded && { _dd < CQ_empLoadR + 1 }) then {
            _dev enableSimulationGlobal true;
            _dev attachTo [_v, [0, -0.3, 0.55]];
            _s set ["loaded", true];
            { if (!isNull _x) then { deleteVehicle _x } } forEach [_s get "table"];
            ["EMP event: device loaded on the Stomper at %1", [mapGridPosition _v]] call CQ_fnc_log;
            ["empLoaded", [mapGridPosition _v]] call CQ_fnc_say;
            _orderT = -1e6;
            continue;
        };
        // strike
        if (_loaded && { _dd < CQ_empStrikeR }) exitWith {
            ["strike", [getPosATL _v, _s get "programmer"]] call CQ_fnc_empBlast;
        };
        // drive (orders refreshed every 10 s)
        if (time - _orderT > 10) then { _orderT = time; (driver _v) doMove _goal };
        // stuck: nudged along its route
        if ((getPosATL _v) distance2D _lastP > 2) then { _lastP = getPosATL _v; _lastMoveT = time };
        if (time - _lastMoveT > CQ_empStuck) then {
            private _np = (getPosATL _v) getPos [CQ_empNudge min _dd, _v getDir _goal];
            private _ep = _np findEmptyPosition [0, 8, CQ_empStomper];
            if (_ep isEqualTo [] || { surfaceIsWater _ep }) then { _ep = _np };
            _v setPosATL [_ep select 0, _ep select 1, 0];
            _v setDir (_v getDir _goal);
            ["EMP event: Stomper stuck %1 s at %2, nudged %3 m toward its goal", [CQ_empStuck, mapGridPosition _v, round (CQ_empNudge min _dd)]] call CQ_fnc_log;
            _lastP = getPosATL _v; _lastMoveT = time; _orderT = -1e6;
        };
    } else {
        _lastMoveT = time;     // waiting for a target: not stuck
    };
    sleep 3;
};
