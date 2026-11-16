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

switch (_mode) do {
    case "loss": {
        private _p = _s get "pos";
        CQ_empPhase = "blown"; publicVariable "CQ_empPhase";
        private _nd = 0;
        {
            private _v = _x get "veh";
            if (alive _v && { _v distance2D _p < CQ_empBlastR }) then { _v setDamage 1; _nd = _nd + 1 };
        } forEach (missionNamespace getVariable ["CQ_mag", []]);
        { if (alive _x && { side _x == west } && { _x distance2D _p < CQ_empBlastR }) then { _x setDamage 1; _nd = _nd + 1 } } forEach allUnitsUAV;
        private _nv = 0;
        {
            if (alive _x && { _x distance2D _p < CQ_empBlastR } && { !(_x isKindOf "StaticWeapon") } && { !(_x isKindOf "ParachuteBase") } && { !(_x isKindOf "UAV") }
                && { getNumber (configOf _x >> "side") == 1 || { (crew _x) isNotEqualTo [] && { side group effectiveCommander _x == west } } }) then {
                [_x] call _kill; _nv = _nv + 1;
            };
        } forEach vehicles;
        ["fx", [_p, CQ_empBlastR]] remoteExec ["CQ_fnc_empClient", 0];
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
        private _nv = 0; private _ns = 0;
        {
            if (alive _x && { _x distance2D _p < CQ_empHitR } && { !(_x isKindOf "ParachuteBase") }) then {
                if (_x isKindOf "StaticWeapon") then {
                    if (getNumber (configOf _x >> "side") == 0 || { side group effectiveCommander _x == east }) then { _x setDamage 1; _ns = _ns + 1 };
                } else {
                    if (getNumber (configOf _x >> "side") == 0 || { (crew _x) isNotEqualTo [] && { side group effectiveCommander _x == east } }) then { [_x, true] call _kill; _nv = _nv + 1 };
                };
            };
        } forEach vehicles;
        private _hit = [];
        {
            private _r = _x getOrDefault ["radio", objNull];
            if ((_x get "pos") distance2D _p < CQ_empHitR || { !isNull _r && { _r distance2D _p < CQ_empHitR } }) then {
                _x set ["empUntil", time + CQ_empSilence];
                _hit pushBack (_x get "id");
            };
        } forEach (values CQ_hqs);
        ["fx", [_p, CQ_empHitR]] remoteExec ["CQ_fnc_empClient", 0];
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
