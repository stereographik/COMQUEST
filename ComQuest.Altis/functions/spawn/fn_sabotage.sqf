/*
    CQ_fnc_sabotage  (server)
    ["tick"] call CQ_fnc_sabotage;            director task "sabotage" (every 5 s)
    ["spawn", [_pos, _byAir]] call CQ_fnc_sabotage;
    SABOTAGE: CSAT's elite network hunters (CQ_sabClasses: leader, Titan AA, satchel expert,
    Titan AT, marksman, autorifleman/medic), motorised (CQ_sabVehicles). They belong to the
    corridor outpost (home: the outpost, the root HQ once it has fallen or if there is none).
      trigger   CQ_sabDelay s after MAGPIE's first contact reaches our base; afterwards a new
                hunt at most every CQ_sabCooldown s (counted from the start of the last hunt)
      target    the exposed node of our data link closest to their home: WASP (flying) or the
                base's relay vehicle
      drive     to a dismount point CQ_sabDismount m short of the target's fuzzy position
                (+/- CQ_sabFuzz m, exact once they know it); the driver stays with the vehicle
      foot      every CQ_sabUpdate s a new fuzzy position; close in: the AA / AT specialists
                engage, the satchel expert blows a relay vehicle he reaches (CQ_sabSatchelR m)
      back      target destroyed, or CQ_sabHuntTime s: back to the vehicle, then home
      wiped     CQ_sabBounty points to the squad that killed the last one; the next team
                (CQ_sabTeams in all) is paradropped near the root HQ and drives home to wait
    MAGPIE seeing them within CQ_sabWarnR m of the node: CROSSROAD warns; WASP pulls back.
    State: CQ_sab hashmap: phase (none, toHome, home, drive, foot, back), grp, veh, home,
    target, tPos, t0, nextT, left, huntT, warned
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
        _s set ["phase", ["home", "toHome"] select _byAir];
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
            ["spawn", [_drop, !_first]] call CQ_fnc_sabotage;
        };

        // choose the target: the exposed node closest to home
        private _pickTarget = {
            private _c = [];
            private _wasp = ((missionNamespace getVariable ["CQ_mag", []]) select { (_x getOrDefault ["role", ""]) == "wasp" && { alive (_x get "veh") } && { (_x getOrDefault ["phase", ""]) == "air" } }) apply { _x get "veh" };
            _c append _wasp;
            private _rv = missionNamespace getVariable ["CQ_linkRelayVeh", objNull];
            if (alive _rv) then { _c pushBack _rv };
            if (_c isEqualTo []) exitWith { objNull };
            ([_c, [], { _x distance2D _home }, "ASCEND"] call BIS_fnc_sortBy) select 0
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

        switch (_ph) do {
            case "toHome": {
                if (!alive _v) exitWith {};                      // vehicle still coming down
                if ((leader _g) distance2D _home < 150) exitWith { _s set ["phase", "home"]; [_g] call CQ_fnc_clearWaypoints; ["SABOTAGE: team at home (grid %1), waiting", [mapGridPosition _home]] call CQ_fnc_log };
                if ((units _g) findIf { alive _x && { vehicle _x != _v } } > -1) exitWith { call _mount };
                if (time - (_s get "t0") > 20) then { _s set ["t0", time]; (driver _v) doMove _home };
            };
            case "home": {
                if (time - (_s get "huntT") < CQ_sabCooldown) exitWith {};
                private _t = call _pickTarget;
                if (isNull _t) exitWith {};
                _s set ["target", _t]; _s set ["huntT", time]; _s set ["driveLog", false]; _s set ["boardLog", true]; _s set ["warned", false]; _s set ["t0", 0];
                _s set ["tPos", [_t] call _fuzzy];
                _s set ["phase", "drive"];
                _s set ["boardT", time];
                call _mount;
                ["SABOTAGE: hunt %1 started from grid %2, target %3 at grid %4", [CQ_sabTeams - (_s get "left"), mapGridPosition _home, ["relay vehicle", "WASP"] select (_t isKindOf "Air"), mapGridPosition _t]] call CQ_fnc_log;
            };
            case "drive": {
                private _t = _s get "target";
                if (!alive _t) exitWith { _s set ["phase", "back"]; _s set ["t0", 0] };
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
                    private _dp = _tp getPos [CQ_sabDismount, _tp getDir _v];
                    (driver _v) doMove _dp;
                };
                if (_v distance2D (_s get "tPos") < CQ_sabDismount + 80) then {
                    // dismount: everyone but the driver goes on foot
                    { if (_x != driver _v) then { unassignVehicle _x; [_x] orderGetIn false; moveOut _x } } forEach units _g;
                    doStop (driver _v);
                    _s set ["phase", "foot"]; _s set ["t0", 0];
                    _g setBehaviour "STEALTH";
                    ["SABOTAGE: dismounted at grid %1, %2 m from the target", [mapGridPosition _v, round (_v distance2D _t)]] call CQ_fnc_log;
                };
            };
            case "foot": {
                private _t = _s get "target";
                if (!alive _t) exitWith {
                    ["SABOTAGE: %1 destroyed, the team heads home", [["relay vehicle", "WASP"] select (_t isKindOf "Air")]] call CQ_fnc_log;
                    ["sabSuccess", [["the relay vehicle", "WASP"] select (_t isKindOf "Air")]] call CQ_fnc_say;
                    _s set ["phase", "back"]; _s set ["t0", 0];
                };
                if (time - (_s get "huntT") > CQ_sabHuntTime) exitWith { ["SABOTAGE: hunt timed out, the team heads home"] call CQ_fnc_log; _s set ["phase", "back"]; _s set ["t0", 0] };
                // the satchel expert blows a relay vehicle he reaches
                if !(_t isKindOf "Air") then {
                    private _ex = (units _g) select { alive _x && { (typeOf _x) == (CQ_sabClasses select 2) } && { _x distance _t < CQ_sabSatchelR } };
                    if (_ex isNotEqualTo [] && { !(_t getVariable ["CQ_sabCharged", false]) }) then {
                        _t setVariable ["CQ_sabCharged", true];
                        ["SABOTAGE: satchel charge planted on the relay vehicle at grid %1", [mapGridPosition _t]] call CQ_fnc_log;
                        [_t] spawn { params ["_t"]; sleep 20; if (alive _t) then { createVehicle ["SatchelCharge_Remote_Ammo_Scripted", getPosATL _t, [], 0, "CAN_COLLIDE"] setDamage 1; _t setDamage 1 } };
                    };
                };
                private _upd = [CQ_sabUpdate select 1, CQ_sabUpdate select 0] select ((_t getVariable ["CQ_linked", false]) || { !(_t isKindOf "Air") });   // a transmitting node gives itself away faster
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
            case "back": {
                _g setCombatMode "YELLOW"; _g setBehaviour "AWARE";
                if ((leader _g) distance2D _home < 200) exitWith {
                    _s set ["phase", "home"]; [_g] call CQ_fnc_clearWaypoints;
                    ["SABOTAGE: back home (grid %1)", [mapGridPosition _home]] call CQ_fnc_log;
                };
                if (time - (_s get "t0") > 30) then {
                    _s set ["t0", time];
                    if (alive _v && { canMove _v }) then {
                        if ((units _g) findIf { alive _x && { vehicle _x != _v } } > -1) then {
                            { if (alive _x && { vehicle _x == _x }) then { _x doMove (getPosATL _v) } } forEach units _g;
                            if ((units _g) findIf { alive _x && { vehicle _x == _x } && { _x distance _v < 30 } } > -1) then { call _mount };
                        } else { (driver _v) doMove _home };
                    } else {
                        [_g] call CQ_fnc_clearWaypoints;
                        _g move _home;
                    };
                };
            };
        };
    };
};
