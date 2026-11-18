/*
    CQ_fnc_sabotage  (server)
    ["tick"] call CQ_fnc_sabotage;            director task "sabotage" (every 5 s)
    ["spawn", [_pos, _byAir]] call CQ_fnc_sabotage;
    SABOTAGE: CSAT's elite network hunters (CQ_sabClasses: leader, Titan AA, satchel expert,
    Titan AT, marksman, autorifleman/medic), motorised (CQ_sabVehicles). They belong to the
    corridor outpost (home: the outpost, the root HQ once it has fallen or if there is none).
      trigger   the first team is ready CQ_sabDelay s after MAGPIE's first contact reaches our base
      wait      where they are, by their vehicle, shooting any drone they see (combat RED)
      target    the WASP or Darter that reports the next spot (a new identification it sends to
                the base: CQ_sabSpot, CQ_fnc_magTick). Sentinels, players' drones and the relay
                vehicle are never hunted (only shot on sight)
      drive     cross-country and cautious (STEALTH, normal speed, lights off) to a dismount point
                off the road, CQ_sabDismount m short of the drone's fuzzy position (+/- CQ_sabFuzz m,
                exact once they know it); the driver stays with the vehicle
      foot      every CQ_sabUpdate s a new fuzzy position; within 900 m they know it and fire
      give up   drone down, or CQ_sabHuntTime s on foot: back to waiting where they are
      rearm     the Titan AA gunner's missiles spent: to the nearest standing supply depot (else
                active HQ, else home) to get CQ_sabAaMissiles back, then wait there
      wiped     CQ_sabBounty points to the squad that killed the last one; the next team
                (CQ_sabTeams in all, at most every CQ_sabCooldown s) is paradropped near the root
                HQ and drives home to wait
    MAGPIE seeing them within CQ_sabWarnR m of the node: CROSSROAD warns; WASP pulls back.
    State: CQ_sab hashmap: phase (none, toHome, wait, drive, foot, rearm), grp, veh, target,
    tPos, t0, nextT, left, huntT, spotT, warned, rearmPos, aaMag, force (debug: hunt the nearest now)
*/
params ["_mode", ["_a", []]];
if (!isServer) exitWith {};
if (isNil "CQ_sab") then {
    CQ_sab = createHashMapFromArray [["phase", "none"], ["grp", grpNull], ["veh", objNull], ["left", CQ_sabTeams],
        ["huntT", -1e6], ["nextT", 0], ["target", objNull], ["tPos", []], ["t0", 0], ["warned", false], ["started", false]];
};
private _s = CQ_sab;

// home: the outpost while it stands, else the root HQ
private _homePos = {
    if (!isNil "CQ_outpostState" && { !(CQ_outpostState get "fallen") }) exitWith { CQ_outpostState get "pos" };
    private _roots = (values CQ_hqs) select { (_x getOrDefault ["parent", -1]) == -1 && { (_x get "state") in CQ_activeStates } };
    if (_roots isEqualTo []) exitWith { [] };
    (([_roots, [], { _x get "id" }] call BIS_fnc_sortBy) select 0) get "pos"
};
private _alive = { ({ alive _x } count units (_s get "grp")) };

switch (_mode) do {
    case "spawn": {
        _a params ["_pos", ["_byAir", false]];
        private _cls = CQ_sabClasses apply {
            private _cfg = configFile >> "CfgVehicles" >> _x;
            [_x, "O_Soldier_F"] select !(isClass _cfg && { getText (_cfg >> "DLC") == "" })
        };
        private _g = createGroup [east, true];
        _g setVariable ["CQ_noInfCap", true];   // an event: out of both caps (infantry and all-AI, CQ_fnc_enemyCount)
        _g setVariable ["CQ_event", true];
        _g setGroupIdGlobal ["SABOTAGE"];
        _g setVariable ["CQ_sabotage", true];
        {
            private _u = _g createUnit [_x, _pos, [], 6, "NONE"];
            [[_u]] call CQ_fnc_unitPrep;
            _u setSkill CQ_sabSkill;
            _u setVariable ["CQ_hunter", true];
            _u setVariable ["CQ_sabotage", true];
            _u addEventHandler ["Killed", {
                params ["_u", "_k", "_i"];
                private _who = [_i, _k] select (isNull _i);
                if (({ alive _x } count units group _u) > 0) exitWith {};
                ["SABOTAGE: team wiped out at grid %1", [mapGridPosition _u]] call CQ_fnc_log;
                ["sabDown", []] call CQ_fnc_say;
                if (!isNull _who && { isPlayer _who }) then {
                    private _pg = group _who;
                    if !(_pg getVariable ["CQ_solo", true]) then { _pg setVariable ["CQ_sqPts", (_pg getVariable ["CQ_sqPts", 0]) + CQ_sabBounty, true] };
                    [_who, CQ_sabBounty, "SABOTAGE team"] call CQ_fnc_scoreAdd;
                };
            }];
            if (_byAir) then {
                private _p = _pos getPos [random 200, random 360];
                _u setPosATL [_p select 0, _p select 1, 400 + random 60];
                private _ch = createVehicle ["Steerable_Parachute_F", getPosATL _u, [], 0, "CAN_COLLIDE"];
                _ch setPosATL getPosATL _u;
                _u moveInDriver _ch;
            };
        } forEach _cls;
        _g setBehaviour "AWARE";
        _g setCombatMode "YELLOW";
        _g enableDynamicSimulation false;
        _s set ["grp", _g];
        // the vehicle: on the spot at home, paradropped next to the team otherwise
        private _vcls = CQ_sabVehicles param [CQ_sabVehicles findIf { isClass (configFile >> "CfgVehicles" >> _x) }, "O_MRAP_02_F"];
        if (_byAir) then {
            [_vcls, _pos, { params ["_v"]; CQ_sab set ["veh", _v]; ["SABOTAGE: vehicle down at grid %1", [mapGridPosition _v]] call CQ_fnc_log }, "SABOTAGE vehicle"] spawn CQ_fnc_paraDropVehicle;
        } else {
            private _vp = _pos findEmptyPosition [5, 60, _vcls];
            if (_vp isEqualTo []) then { _vp = _pos getPos [20, random 360] };
            private _v = createVehicle [_vcls, _vp, [], 0, "NONE"];
            _s set ["veh", _v];
        };
        _s set ["phase", ["wait", "toHome"] select _byAir];
        _s set ["boardT", time + 120];                       // paradropped: time to land before the boarding failsafe
        _s set ["t0", time];
        ["SABOTAGE: team %1/%2 %3 at grid %4", [CQ_sabTeams - (_s get "left") + 1, CQ_sabTeams, ["ready at home", "paradropped"] select _byAir, mapGridPosition _pos]] call CQ_fnc_log;
        _s set ["left", (_s get "left") - 1];
    };

    case "tick": {
        if (!CQ_sabOn) exitWith {};
        if (time < (_s get "nextT")) exitWith {};
        _s set ["nextT", time + 5];
        if !(missionNamespace getVariable ["CQ_magContactMade", false]) exitWith {};
        if !(_s get "started") then {
            if (isNil "CQ_sabContactT") then { CQ_sabContactT = time };
            if (time - CQ_sabContactT < CQ_sabDelay) exitWith {};
            _s set ["started", true];
        };
        if !(_s get "started") exitWith {};
        private _g = _s get "grp";
        private _v = _s get "veh";
        private _ph = _s get "phase";
        private _home = call _homePos;
        if (_home isEqualTo []) exitWith {};

        // no team: the first one is ready at home, the next ones are paradropped near the root HQ
        if (isNull _g || { (call _alive) == 0 }) exitWith {
            if (_ph != "none") then { _s set ["phase", "none"]; _s set ["grp", grpNull] };
            if ((_s get "left") <= 0) exitWith {};
            if (time - (_s get "huntT") < CQ_sabCooldown && { (_s get "huntT") > 0 }) exitWith {};
            private _first = (_s get "left") == CQ_sabTeams;
            private _roots = (values CQ_hqs) select { (_x getOrDefault ["parent", -1]) == -1 && { (_x get "state") in CQ_activeStates } };
            private _drop = if (_first || { _roots isEqualTo [] }) then { _home } else { ((_roots select 0) get "pos") getPos [300 + random 300, random 360] };
            if !([count CQ_sabClasses + 2, "sabotage"] call CQ_fnc_aiRoom) exitWith {};   // the enemy AI budget: asked again next tick
            ["spawn", [_drop, !_first]] call CQ_fnc_sabotage;
        };

        private _fuzzy = {
            params ["_t"];
            if ((units _g) findIf { alive _x && { (_x knowsAbout _t) > 1.5 } } > -1) exitWith { getPosATL _t };
            (getPosATL _t) getPos [random CQ_sabFuzz, random 360]
        };
        private _mount = {
            if (!alive _v) exitWith {};
            // failsafe: past CQ_sabBoardTime, whoever is close is seated by script
            if (time - (_s getOrDefault ["boardT", time]) > CQ_sabBoardTime) exitWith {
                { if (alive _x && { vehicle _x == _x } && { _x distance _v < 60 }) then { if (isNull driver _v) then { _x moveInDriver _v } else { _x moveInAny _v } } } forEach units _g;
            };
            { if (alive _x && { vehicle _x == _x }) then { _x assignAsCargo _v; [_x] orderGetIn true } } forEach units _g;
            if (isNull driver _v) then { private _d = (units _g) select { alive _x } select 0; _d assignAsDriver _v; [_d] orderGetIn true };
        };
        // on wheels: cross-country and cautious (STEALTH keeps the AI off the roads, lights off at night),
        // normal speed
        private _offRoad = { _g setBehaviour "STEALTH"; _g setSpeedMode "NORMAL"; _g setCombatMode "YELLOW" };
        // a point moved off any road (the closest spot within 150 m that is not road, nor water)
        private _offRoadPt = {
            params ["_p"];
            if !(isOnRoad _p) exitWith { _p };
            private _out = _p;
            { private _c = _p getPos [_x select 0, _x select 1]; if (!isOnRoad _c && { !surfaceIsWater _c }) exitWith { _out = _c } } forEach [[40, 0], [40, 90], [40, 180], [40, 270], [80, 45], [80, 135], [80, 225], [80, 315], [150, 0], [150, 120], [150, 240]];
            _out
        };
        // seen by MAGPIE near a node: CROSSROAD warns once per hunt, WASP gets the position
        private _seen = if (isNil "CQ_magSeen") then { [] } else { (units _g) select { alive _x && { (CQ_magSeen getOrDefault [hashValue (vehicle _x), []]) isNotEqualTo [] } && { time - ((CQ_magSeen get hashValue (vehicle _x)) select 2) < 60 } } };
        if (_seen isNotEqualTo []) then {
            CQ_sabSeenPos = getPosATL (_seen select 0); CQ_sabSeenT = time;
            private _t = _s get "target";
            if (alive _t && { !(_s get "warned") } && { (_seen select 0) distance2D _t < CQ_sabWarnR }) then {
                _s set ["warned", true];
                ["sabWarn", [["the relay vehicle", "WASP"] select (_t isKindOf "Air"), round ((_seen select 0) distance2D _t)]] call CQ_fnc_say;
                ["SABOTAGE: spotted by MAGPIE %1 m from its target", [round ((_seen select 0) distance2D _t)]] call CQ_fnc_log;
            };
        };

        // the AA gunner and the AA missiles he has left (loaded + carried)
        private _aaMan = { private _m = (units _g) select { alive _x && { (typeOf _x) == (CQ_sabClasses select 1) } }; if (_m isEqualTo []) then { objNull } else { _m select 0 } };
        private _aaLeft = {
            private _m = call _aaMan;
            if (isNull _m) exitWith { 0 };
            private _mag = _s getOrDefault ["aaMag", ""];
            if (_mag == "") then { _mag = (getArray (configFile >> "CfgWeapons" >> secondaryWeapon _m >> "magazines")) param [0, "Titan_AA"]; _s set ["aaMag", _mag] };
            ({ _x == _mag } count magazines _m) + ({ _x == _mag } count (secondaryWeaponMagazine _m))
        };
        // where to rearm: the nearest standing supply depot, else the nearest active HQ, else home
        private _rearmPos = {
            private _lp = getPosATL (leader _g);
            private _dep = flatten ((values CQ_hqs) apply { (_x get "installations") select { alive _x && { (_x getVariable ["CQ_objType", ""]) == "Depot" } } });
            if (_dep isNotEqualTo []) exitWith { getPosATL (([_dep, [], { _x distance2D _lp }] call BIS_fnc_sortBy) select 0) };
            private _hq = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
            if (_hq isNotEqualTo []) exitWith { (([_hq, [], { (_x get "pos") distance2D _lp }] call BIS_fnc_sortBy) select 0) get "pos" };
            _home
        };
        // back to waiting where they are (men on foot regroup at the vehicle)
        private _toWait = {
            _s set ["phase", "wait"]; _s set ["t0", 0];
            [_g] call CQ_fnc_clearWaypoints;
            if (alive _v) then { doStop (driver _v) };
            _g setBehaviour "AWARE"; _g setCombatMode "RED";
        };

        switch (_ph) do {
            case "toHome": {
                if (!alive _v) exitWith {};                      // vehicle still coming down
                if ((leader _g) distance2D _home < 150) exitWith { call _toWait; ["SABOTAGE: team at home (grid %1), waiting for a spot", [mapGridPosition _home]] call CQ_fnc_log };
                if ((units _g) findIf { alive _x && { vehicle _x != _v } } > -1) exitWith { call _mount };
                if (time - (_s get "t0") > 20) then { _s set ["t0", time]; call _offRoad; (driver _v) doMove ([_home] call _offRoadPt) };
            };
            // WAIT: where they are, by their vehicle, shooting any drone they see. The next spot that
            // WASP or a Darter reports (CQ_sabSpot, CQ_fnc_magTick) makes that drone the target.
            // AA missiles spent: rearm first.
            case "home";
            case "wait": {
                _g setBehaviour "AWARE"; _g setCombatMode "RED";
                if ((call _aaLeft) == 0 && { (call _aaMan) isNotEqualTo objNull }) exitWith {
                    private _rp = call _rearmPos;
                    _s set ["phase", "rearm"]; _s set ["rearmPos", _rp]; _s set ["t0", 0]; _s set ["boardT", time];
                    ["SABOTAGE: AA missiles spent, driving to rearm at grid %1", [mapGridPosition _rp]] call CQ_fnc_log;
                };
                // regroup at the vehicle
                if (alive _v && { time - (_s get "t0") > 30 }) then {
                    _s set ["t0", time];
                    { if (alive _x && { vehicle _x == _x } && { _x distance _v > 40 }) then { _x doMove (getPosATL _v) } } forEach units _g;
                };
                private _sp = missionNamespace getVariable ["CQ_sabSpot", [objNull, -1]];
                _sp params ["_d", "_st"];
                private _force = _s getOrDefault ["force", false];
                if (_force) then {
                    _s set ["force", false];
                    private _c = ((missionNamespace getVariable ["CQ_mag", []]) select { (_x getOrDefault ["role", ""]) in ["wasp", "dormant"] && { alive (_x get "veh") } }) apply { _x get "veh" };
                    if (_c isNotEqualTo []) then { _d = ([_c, [], { _x distance2D (leader _g) }] call BIS_fnc_sortBy) select 0; _st = time };
                };
                if (!alive _d || { _st <= (_s getOrDefault ["spotT", -1]) }) exitWith {};
                _s set ["spotT", _st];
                _s set ["target", _d]; _s set ["huntT", time]; _s set ["driveLog", false]; _s set ["boardLog", true]; _s set ["warned", false]; _s set ["t0", 0];
                _s set ["tPos", [_d] call _fuzzy];
                _s set ["phase", "drive"];
                _s set ["boardT", time];
                call _mount;
                ["SABOTAGE: hunting %1 (it reported a spot) from grid %2, %3 m away, %4 AA missile(s)", [_d getVariable ["CQ_magName", "a drone"], mapGridPosition (leader _g), round ((leader _g) distance2D _d), call _aaLeft]] call CQ_fnc_log;
            };
            case "drive": {
                private _t = _s get "target";
                // target lost before they got there (not their doing): they stop and wait for the next spot
                if (!alive _t) exitWith { ["SABOTAGE: target lost before contact, waiting for the next spot"] call CQ_fnc_log; call _toWait };
                if (time - (_s get "huntT") > CQ_sabDriveMax) exitWith { ["SABOTAGE: drove %1 s without reaching the drone, waiting for the next spot", [CQ_sabDriveMax]] call CQ_fnc_log; call _toWait };
                if (!alive _v || { !canMove _v }) exitWith { _s set ["phase", "foot"]; { unassignVehicle _x; moveOut _x } forEach units _g; _s set ["t0", 0] };
                if (time - (_s get "t0") > 20) then {
                    _s set ["t0", time];
                    _s set ["tPos", [_t] call _fuzzy];
                    private _out = (units _g) select { alive _x && { vehicle _x != _v } };
                    if (_out isNotEqualTo [] && { time - (_s get "boardT") < CQ_sabBoardTime + 30 }) exitWith { call _mount };
                    // still not aboard after the failsafe: they walk and the vehicle goes without them
                    if (_out isNotEqualTo []) then {
                        { unassignVehicle _x; [_x] orderGetIn false; _x doMove (_s get "tPos") } forEach _out;
                        if (_s getOrDefault ["boardLog", true]) then { _s set ["boardLog", false]; ["SABOTAGE: %1 man/men could not board, they follow on foot", [count _out]] call CQ_fnc_log };
                    };
                    if !(_s getOrDefault ["driveLog", false]) then { _s set ["driveLog", true]; ["SABOTAGE: driving, %1/%2 aboard, %3 m to the target", [{ alive _x && { vehicle _x == _v } } count units _g, call _alive, round (_v distance2D (_s get "tPos"))]] call CQ_fnc_log };
                    private _tp = _s get "tPos";
                    private _dp = [_tp getPos [CQ_sabDismount, _tp getDir _v]] call _offRoadPt;
                    call _offRoad;
                    (driver _v) doMove _dp;
                };
                if (_v distance2D (_s get "tPos") < CQ_sabDismount + 80) then {
                    // dismount: everyone but the driver goes on foot
                    { if (_x != driver _v) then { unassignVehicle _x; [_x] orderGetIn false; moveOut _x } } forEach units _g;
                    doStop (driver _v);
                    _s set ["phase", "foot"]; _s set ["t0", 0]; _s set ["huntT", time];   // the CQ_sabHuntTime s on foot start now
                    _g setBehaviour "STEALTH";
                    ["SABOTAGE: dismounted at grid %1, %2 m from the target", [mapGridPosition _v, round (_v distance2D _t)]] call CQ_fnc_log;
                };
            };
            case "foot": {
                private _t = _s get "target";
                if (!alive _t) exitWith {
                    ["SABOTAGE: %1 shot down, waiting for the next spot", [_t getVariable ["CQ_magName", "the drone"]]] call CQ_fnc_log;
                    ["sabSuccess", [_t getVariable ["CQ_magName", "WASP"]]] call CQ_fnc_say;
                    call _toWait;
                };
                if (time - (_s get "huntT") > CQ_sabHuntTime) exitWith { ["SABOTAGE: hunt given up after %1 s, waiting for the next spot", [CQ_sabHuntTime]] call CQ_fnc_log; call _toWait };
                if ((call _aaLeft) == 0 && { (call _aaMan) isNotEqualTo objNull }) exitWith { ["SABOTAGE: AA missiles spent during the hunt"] call CQ_fnc_log; call _toWait };
                private _upd = [CQ_sabUpdate select 1, CQ_sabUpdate select 0] select (_t getVariable ["CQ_linked", false]);   // a transmitting drone gives itself away faster
                if (time - (_s get "t0") > _upd) then {
                    _s set ["t0", time];
                    private _tp = [_t] call _fuzzy;
                    _s set ["tPos", _tp];
                    [_g] call CQ_fnc_clearWaypoints;
                    private _foot = (units _g) select { alive _x && { vehicle _x == _x } };
                    { _x doMove ((_tp getPos [random 40, random 360])) } forEach _foot;
                    // in range: they know where it is
                    if ((leader _g) distance2D _t < 900) then { _g reveal [_t, 4]; _g setCombatMode "RED" };
                };
            };
            // REARM: cross-country to the nearest standing supply depot (else active HQ, else home):
            // the AA gunner gets his CQ_sabAaMissiles back, then they wait there
            case "rearm": {
                private _rp = _s get "rearmPos";
                private _man = call _aaMan;
                if (isNull _man) exitWith { call _toWait };
                if ((leader _g) distance2D _rp < 150) exitWith {
                    private _mag = _s getOrDefault ["aaMag", "Titan_AA"];
                    _man addMagazines [_mag, (CQ_sabAaMissiles - (call _aaLeft)) max 0];
                    ["SABOTAGE: rearmed at grid %1, %2 AA missile(s)", [mapGridPosition _rp, call _aaLeft]] call CQ_fnc_log;
                    call _toWait;
                };
                if (alive _v && { canMove _v }) then {
                    if ((units _g) findIf { alive _x && { vehicle _x != _v } } > -1) exitWith { call _mount };
                    if (time - (_s get "t0") > 20) then { _s set ["t0", time]; call _offRoad; (driver _v) doMove ([_rp] call _offRoadPt) };
                } else {
                    if (time - (_s get "t0") > 30) then { _s set ["t0", time]; [_g] call CQ_fnc_clearWaypoints; _g move _rp; _g setBehaviour "AWARE" };
                };
            };
        };
    };
};
