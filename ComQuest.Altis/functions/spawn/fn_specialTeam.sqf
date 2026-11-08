/*
    CQ_fnc_specialTeam  (server, spawned)
    [_kind] spawn CQ_fnc_specialTeam;     _kind: "medic" or "engineer"
    One support team for the whole enemy army, paradropped once the first HQ is built and
    dropped again CQ_specialRespawn s after it is wiped out (vehicle destroyed or crew dead):
      medic     white Strider HMG, white-clad medics: drives to wounded CSAT soldiers
                (damage > CQ_medicHealAbove) and treats everyone within 40 m back to health
      engineer  Strider HMG, engineers in urban camo: drives to damaged CSAT vehicles and
                statics (damage or broken wheels/tracks) and repairs them on the spot
    Between jobs the team waits near the main HQ. Runs for the whole mission.
*/
params ["_kind"];
private _medic = _kind == "medic";
private _tag = format ["%1 team", ["Engineer", "Medic"] select _medic];

while { true } do {
    // --- wait for a built HQ to drop next to
    waitUntil { sleep 10; ((values CQ_hqs) findIf { (_x get "state") in CQ_activeStates && { _x get "buildDone" } }) > -1 };
    private _home = CQ_hqs getOrDefault [CQ_hubId, createHashMap];
    if (count _home == 0) then { _home = (values CQ_hqs) select { (_x get "state") in CQ_activeStates && { _x get "buildDone" } } select 0 };
    private _lz = (_home get "pos") getPos [120 + random 80, random 360];

    // --- paradrop the Strider, then crew it with the team
    missionNamespace setVariable [format ["CQ_team_%1", _kind], objNull];
    [CQ_specialVehicle, _lz, compile format ["
        params ['_v'];
        private _medic = %1;
        private _g = createGroup [east, true];
        private _cls = ['O_engineer_F', 'O_medic_F'] select _medic;
        private _mk = { private _u = _g createUnit [_cls, getPosATL _v, [], 5, 'NONE']; [[_u]] call CQ_fnc_unitPrep; _u };
        if (_medic) then {
            { _v setObjectTextureGlobal [_forEachIndex, '#(rgb,8,8,3)color(0.93,0.93,0.9,1)'] } forEach getArray (configOf _v >> 'hiddenSelections');
        };
        (call _mk) moveInDriver _v;
        { (call _mk) moveInTurret [_v, _x] } forEach (allTurrets [_v, false]);
        for '_i' from 1 to (_v emptyPositions 'cargo') do { (call _mk) moveInCargo _v };
        {
            if (_medic) then {
                _x setObjectTextureGlobal [0, '#(rgb,8,8,3)color(0.95,0.95,0.93,1)'];
                _x addItemToBackpack 'Medikit';
            } else {
                _x forceAddUniform 'U_O_CombatUniform_oucamo';
                _x addVest 'V_HarnessO_gry';
                _x addItemToBackpack 'ToolKit';
            };
        } forEach units _g;
        _g addVehicle _v;
        _g setBehaviour 'AWARE';
        _g setCombatMode 'YELLOW';
        _g enableDynamicSimulation false;
        _v setFuelConsumptionCoef CQ_fuelConsumption;
        _v setVariable ['CQ_team', '%2', true];
        missionNamespace setVariable ['CQ_team_%2', _v];
    ", _medic, _kind], _tag] spawn CQ_fnc_paraDropVehicle;

    private _t0 = time;
    waitUntil { sleep 3; !isNull (missionNamespace getVariable [format ["CQ_team_%1", _kind], objNull]) || { time - _t0 > 600 } };
    private _v = missionNamespace getVariable [format ["CQ_team_%1", _kind], objNull];
    if (isNull _v) then { sleep CQ_specialRespawn; continue };
    private _g = group driver _v;
    ["%1 on the ground at grid %2 (%3 men)", [_tag, mapGridPosition _v, count units _g]] call CQ_fnc_log;

    // --- work loop
    private _job = objNull;
    private _jobT = 0;
    while { alive _v && { ({ alive _x } count units _g) > 0 } } do {
        sleep 10;
        private _p = getPosATL _v;
        if (isNull _job || { time - _jobT > 300 }) then {
            _job = objNull;
            private _cands = if (_medic) then {
                allUnits select { alive _x && { side group _x == east } && { damage _x > CQ_medicHealAbove } && { vehicle _x == _x } && { _x distance2D _p < CQ_specialRange } }
            } else {
                vehicles select { alive _x && { side group effectiveCommander _x == east || { _x getVariable ["CQ_hqId", -1] > -1 } }
                    && { _x != _v } && { !(_x isKindOf "Air") || { isTouchingGround _x } }
                    && { damage _x > 0.15 || { !canMove _x && { _x isKindOf "LandVehicle" } } } && { _x distance2D _p < CQ_specialRange } }
            };
            if (_cands isNotEqualTo []) then {
                _job = ([_cands, [], { _x distance2D _p }, "ASCEND"] call BIS_fnc_sortBy) select 0;
                _jobT = time;
                [_g] call CQ_fnc_clearWaypoints;
                _g move (getPosATL _job);
                ["%1 heading to %2 at grid %3", [_tag, if (_medic) then { groupId group _job } else { typeOf _job }, mapGridPosition _job]] call CQ_fnc_log;
            } else {
                // idle: wait near the main HQ
                private _h = CQ_hqs getOrDefault [CQ_hubId, createHashMap];
                if (count _h > 0 && { _v distance2D (_h get "pos") > 250 } && { currentWaypoint _g >= count waypoints _g }) then {
                    _g move ((_h get "pos") getPos [80 + random 60, random 360]);
                };
            };
        } else {
            if (_v distance2D _job < 45 && { speed _v < 5 }) then {
                sleep 12;   // treatment / repair time
                if (_medic) then {
                    private _n = 0;
                    { if (alive _x && { side group _x == east } && { damage _x > 0.05 }) then { _x setDamage 0; _n = _n + 1 } } forEach (_v nearEntities [["CAManBase"], 45]);
                    ["%1 treated %2 soldiers at grid %3", [_tag, _n, mapGridPosition _v]] call CQ_fnc_log;
                } else {
                    if (alive _job) then { _job setDamage 0; ["%1 repaired %2 at grid %3", [_tag, typeOf _job, mapGridPosition _job]] call CQ_fnc_log };
                };
                _job = objNull;
            };
        };
    };
    ["%1 wiped out, a new one in %2 s", [_tag, CQ_specialRespawn]] call CQ_fnc_log;
    sleep CQ_specialRespawn;
};
