/*
    CQ_fnc_empBlast  (server)
    ["loss", []] call CQ_fnc_empBlast;          the planted device went off (timer)
    ["strike", [_pos, _who]] call CQ_fnc_empBlast;   our captured device went off on the Stomper
    loss    every drone of ours within CQ_empBlastR m of the device destroyed (MAGPIE replaces
            them as usual), our vehicles there: engine dead (an engineer's toolkit repairs it),
            lights off. Nobody hurt. The device and its guards go (CQ_fnc_eventCleanup).
    strike  within CQ_empHitR m: enemy vehicles (engine, turret, gun dead, no fuel) and statics
            (destroyed) for good; the enemy HQs there off the radio net CQ_empSilence s (no waves,
            nobody hears them: CQ_fnc_netTick). CQ_empPtsStrike points to _who.
*/
params ["_mode", ["_args", []]];
if (!isServer || { isNil "CQ_empState" }) exitWith {};
private _s = CQ_empState;
// engine (and gun) dead: commands with local arguments go to the vehicle's owner
private _kill = {
    params ["_v", ["_guns", false]];
    { [_v, [_x, 1]] remoteExec ["setHitPointDamage", _v] } forEach (["HitEngine"] + (if (_guns) then { ["HitTurret", "HitGun"] } else { [] }));
    if (_guns) then { [_v, 0] remoteExec ["setFuel", _v] };
    [_v, false] remoteExec ["engineOn", _v];
    [_v, false] remoteExec ["setPilotLight", _v];
};
// the shockwave: every client shows it (CQ_fnc_empClient "fx": ring, shake, a lightning bolt to
// each hit); each object is hit here when the wave reaches it (radius / _time m/s)
private _wave = {
    params ["_p", "_r", "_time", "_hits", "_kill"];
    ["fx", [_p, _r, _time, _hits apply { _x select 0 }]] remoteExec ["CQ_fnc_empClient", 0];
    [_p, _r / (_time max 0.5), _hits, _kill] spawn {
        params ["_p", "_spd", "_hits", "_kill"];
        private _t0 = time;
        _hits = [_hits, [], { (_x select 0) distance2D _p }, "ASCEND"] call BIS_fnc_sortBy;
        {
            _x params ["_o", "_k"];
            waitUntil { time - _t0 >= (_o distance2D _p) / _spd || { isNull _o } };
            if (!isNull _o && { alive _o }) then {
                switch (_k) do {
                    case "drone": { _o setDamage 1 };
                    case "veh": { [_o] call _kill };
                    case "enemy": { [_o, true] call _kill };
                    case "static": { _o setDamage 1 };
                };
            };
        } forEach _hits;
    };
};

switch (_mode) do {
    case "loss": {
        private _p = _s get "pos";
        CQ_empPhase = "blown"; publicVariable "CQ_empPhase";
        // hit list: [object, "drone" | "veh"]; each is hit when the shockwave reaches it
        private _hits = [];
        {
            private _v = _x get "veh";
            if (alive _v && { _v distance2D _p < CQ_empBlastR }) then { _hits pushBackUnique [_v, "drone"] };
        } forEach (missionNamespace getVariable ["CQ_mag", []]);
        { if (alive _x && { side _x == west } && { _x distance2D _p < CQ_empBlastR }) then { _hits pushBackUnique [_x, "drone"] } } forEach allUnitsUAV;
        {
            if (alive _x && { _x distance2D _p < CQ_empBlastR } && { !(_x isKindOf "StaticWeapon") } && { !(_x isKindOf "ParachuteBase") } && { !(_x isKindOf "UAV") }
                && { getNumber (configOf _x >> "side") == 1 || { (crew _x) isNotEqualTo [] && { side group effectiveCommander _x == west } } }) then {
                _hits pushBack [_x, "veh"];
            };
        } forEach vehicles;
        private _nd = { (_x select 1) == "drone" } count _hits;
        private _nv = { (_x select 1) == "veh" } count _hits;
        [_p, CQ_empBlastR, CQ_empWaveTime select 0, _hits, _kill] call _wave;
        ["EMP event: the device went off at %1: %2 drones down, %3 vehicles dead within %4 m", [mapGridPosition _p, _nd, _nv, CQ_empBlastR]] call CQ_fnc_log;
        ["EMP blast", format ["The EMP went off at grid %1: %2 drones lost, %3 vehicles dead within %4 km. Engineers can repair the engines.", mapGridPosition _p, _nd, _nv, round (CQ_empBlastR / 1000)]] call CQ_fnc_announce;
        ["empBlown", []] call CQ_fnc_say;
        { deleteMarker _x } forEach ["cq_emp", "cq_emp_t"];
        { if (!isNull _x) then { deleteVehicle _x } } forEach [_s get "device", _s get "prop"];
        ["EMP event", (_s get "men") + [_s get "table"]] call CQ_fnc_eventCleanup;
        if (!isNil "CQ_empKey") then { [CQ_empKey, 2, "EMP device", "went off"] call CQ_fnc_opSide };
        CQ_empPhase = "done"; publicVariable "CQ_empPhase";
    };
    case "strike": {
        _args params ["_p", ["_who", objNull]];
        private _hits = [];
        {
            if (alive _x && { _x distance2D _p < CQ_empHitR } && { !(_x isKindOf "ParachuteBase") }) then {
                if (_x isKindOf "StaticWeapon") then {
                    if (getNumber (configOf _x >> "side") == 0 || { side group effectiveCommander _x == east }) then { _hits pushBack [_x, "static"] };
                } else {
                    if (getNumber (configOf _x >> "side") == 0 || { (crew _x) isNotEqualTo [] && { side group effectiveCommander _x == east } }) then { _hits pushBack [_x, "enemy"] };
                };
            };
        } forEach vehicles;
        private _nv = { (_x select 1) == "enemy" } count _hits;
        private _ns = { (_x select 1) == "static" } count _hits;
        private _hit = [];
        {
            private _r = _x getOrDefault ["radio", objNull];
            if ((_x get "pos") distance2D _p < CQ_empHitR || { !isNull _r && { _r distance2D _p < CQ_empHitR } }) then {
                _x set ["empUntil", time + CQ_empSilence];
                _hit pushBack (_x get "id");
            };
        } forEach (values CQ_hqs);
        [_p, CQ_empHitR, CQ_empWaveTime select 1, _hits, _kill] call _wave;
        if (!isNull _who) then { [_who, CQ_empPtsStrike, "EMP strike"] call CQ_fnc_scoreAdd };
        ["EMP event: captured EMP went off at %1: %2 enemy vehicles and %3 statics dead, HQs off the radio for %4 s: %5", [mapGridPosition _p, _nv, _ns, CQ_empSilence, _hit]] call CQ_fnc_log;
        ["EMP strike", format ["Our EMP went off at grid %1: %2 enemy vehicles and %3 guns dead%4.", mapGridPosition _p, _nv, _ns,
            if (_hit isEqualTo []) then { "" } else { format [", %1 off their radio for %2 min", (_hit apply { [_x] call CQ_fnc_objName }) joinString ", ", round (CQ_empSilence / 60)] }]] call CQ_fnc_announce;
        ["empStrike", [mapGridPosition _p]] call CQ_fnc_say;
        { deleteMarker _x } forEach ["cq_emp_ugv", "cq_emp_tgt", "cq_emp_tgtR"];
        { if (!isNull _x) then { deleteVehicle _x } } forEach [_s get "device", _s get "holder"];
        private _v = _s get "stomper";
        if (!isNull _v) then { { deleteVehicle _x } forEach crew _v; deleteVehicle _v };
        if (!isNil "CQ_empKey") then { [CQ_empKey, 2, "EMP device", format ["defused, delivered at grid %1", mapGridPosition _p], _who] call CQ_fnc_opSide };
        CQ_empPhase = "done"; publicVariable "CQ_empPhase";
    };
};
