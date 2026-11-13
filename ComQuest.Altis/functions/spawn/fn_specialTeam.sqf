/*
    CQ_fnc_specialTeam  (server, spawned)
    [_kind] spawn CQ_fnc_specialTeam;     _kind: "medic" or "engineer"
    One support team for the whole enemy army, paradropped CQ_specialFirstDelay s after the
    first Mohawk drop of the game, next to that first HQ, and dropped again
    CQ_specialRespawn s (15 min) after it is wiped out (vehicle destroyed or crew dead), at most
    CQ_specialRespawns times (shown on the carrier marker):
      medic     sand hex Marid APC, medics in sand hex: drives to wounded CSAT soldiers
                (damage > CQ_medicHealAbove) and treats everyone within 40 m back to health
      engineer  green hex Marid APC, engineers in urban camo: drives to damaged CSAT vehicles and
                statics (damage or broken wheels/tracks) and repairs them on the spot
    Between jobs the team waits near the main HQ. Runs for the whole mission.
    Each team keeps CQ_sniperSeats seats free: with every insertion it drives snipers out to
    their overwatch spots before anything else (CQ_fnc_sniperQueue / CQ_fnc_sniperRun).
*/
params ["_kind"];
private _medic = _kind == "medic";
private _tag = format ["%1 team", ["Engineer", "Medic"] select _medic];

while { true } do {
    // --- first drop: CQ_specialFirstDelay s after the first Mohawk drop; then any time
    waitUntil { sleep 2; !isNil "CQ_firstDropT" && { time > CQ_firstDropT + CQ_specialFirstDelay } };
    sleep (20 * (["medic", "engineer"] find _kind));   // the two teams never take off together
    waitUntil { sleep 5; ((values CQ_hqs) findIf { (_x get "state") in CQ_activeStates }) > -1 };
    private _home = CQ_hqs getOrDefault [CQ_hubId, createHashMap];
    if (count _home == 0 || { !((_home get "state") in CQ_activeStates) }) then {
        private _act = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
        _home = ([_act, [], { _x get "born" }, "ASCEND"] call BIS_fnc_sortBy) select 0;
    };
    private _lz = (_home get "pos") getPos [(CQ_specialLzR select 0) + random ((CQ_specialLzR select 1) - (CQ_specialLzR select 0)), random 360];
    ["%1: paradrop near HQ #%2 (grid %3)", [_tag, _home get "id", mapGridPosition _lz]] call CQ_fnc_log;

    // --- paradrop the Marid, then crew it with the team (medics: the Marid's own sand hex camo;
    // engineers: green hex, its texture source if the game has it, else a plain olive paint).
    // No comments inside the compiled string below: compile does not strip them.
    missionNamespace setVariable [format ["CQ_team_%1", _kind], objNull];
    [CQ_specialVehicle, _lz, compile format ["
        params ['_v'];
        private _medic = %1;
        private _g = createGroup [east, true];
        private _cls = ['O_engineer_F', 'O_medic_F'] select _medic;
        private _mk = { private _u = _g createUnit [_cls, getPosATL _v, [], 5, 'NONE']; [[_u]] call CQ_fnc_unitPrep; _u };
        if (!_medic) then {
            if (isClass (configOf _v >> 'TextureSources' >> 'GreenHex')) then { [_v, ['GreenHex', 1]] call BIS_fnc_initVehicle }
            else { { _v setObjectTextureGlobal [_forEachIndex, '#(rgb,8,8,3)color(0.30,0.33,0.22,1)'] } forEach getArray (configOf _v >> 'hiddenSelections') };
        };
        (call _mk) moveInDriver _v;
        { (call _mk) moveInTurret [_v, _x] } forEach (allTurrets [_v, false]);
        for '_i' from 1 to ((_v emptyPositions 'cargo') - CQ_sniperSeats) do { (call _mk) moveInCargo _v };
        {
            if (_medic) then {
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
        // snipers to deliver come first (CQ_fnc_sniperQueue)
        private _sj = (missionNamespace getVariable ["CQ_sniperJobs", createHashMap]) getOrDefault [_kind, []];
        if (_sj isNotEqualTo []) then {
            [_v, _g, _sj deleteAt 0, _tag] call CQ_fnc_sniperRun;
            _job = objNull;
            continue;
        };
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
                if (count _h > 0 && { !((_h get "state") in CQ_activeStates) }) then {
                    // the main HQ fell: the nearest standing one
                    private _act = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
                    _h = if (_act isEqualTo []) then { createHashMap } else { ([_act, [], { (_x get "pos") distance2D _p }, "ASCEND"] call BIS_fnc_sortBy) select 0 };
                };
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
    private _left = (missionNamespace getVariable ["CQ_specialLeft", createHashMap]) getOrDefault [_kind, CQ_specialRespawns];
    if (_left <= 0) exitWith { ["%1 wiped out, the carrier has no replacement left", [_tag]] call CQ_fnc_log };
    CQ_specialLeft set [_kind, _left - 1];
    call CQ_fnc_carrierMarker;
    ["%1 wiped out, a new one in %2 s (%3 replacement(s) left after it)", [_tag, CQ_specialRespawn, _left - 1]] call CQ_fnc_log;
    sleep CQ_specialRespawn;
};
