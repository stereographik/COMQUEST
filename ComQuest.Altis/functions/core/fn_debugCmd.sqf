/*
    CQ_fnc_debugCmd  (server, from the debug panel CQ_fnc_debugUi)
    [_cmd, _hqId] remoteExec ["CQ_fnc_debugCmd", 2];
    Allowed for the host and logged-in admins only.
    Logs:                 logs (id = 1 enemy + 2 friendly: which log lines the caller gets in chat)
    Enemy HQ (selected):  next, ammo, fuel, killCmd, capture, tower, depot, destroy, wave
    Carrier and forces:   root, flight, carrierMinus, carrierFull, killAll
    Story:                actNext, sitrep, storyReset
    MAGPIE:               magReport, magLaunch, magKill
    Events:               crash, tpCrash, decrypt, crashOut, hst, tpHst, hstClear, hstFw, hstBoard, hstHome, hstEnd, opBuild, opKill, opJam, tpOp
    Player (the caller):  heal, tpBase, tpHq, points, vehFix
    Base and world:       vehReset, defRebuild, time1, noon, night, clearWx
    View:                 playerView (the game as a final player sees it: no debug output)
    list                  just refresh
    Answers the caller with the HQ list (CQ_fnc_debugUiFill).
*/
params [["_cmd", "list"], ["_id", -1]];
private _caller = remoteExecutedOwner;
if !(_caller == 2 || { (admin _caller) == 2 }) exitWith {};     // host or logged-in admin only
private _p = (allPlayers select { owner _x == _caller }) param [0, objNull];
private _hq = CQ_hqs getOrDefault [_id, createHashMap];
private _msg = "";
private _needHq = _cmd in ["btKill", "btNow", "tpBt", "hack", "tpTower", "next", "ammo", "fuel", "destroy", "killCmd", "capture", "tower", "depot", "wave", "tpHq"];

if (_needHq && { count _hq == 0 }) then {
    _msg = "Select an HQ in the list first";
} else {
    switch (_cmd) do {
        case "next": {
            private _st = _hq get "state";
            _msg = switch (_st) do {
                case "Inbound": {
                    if ((_hq get "parent") > -1) then { _hq set ["moveSkip", true]; "colonists moved to the site" }
                    else { "root insertion still flying: wait for the landing" };
                };
                case "Securing": {
                    if (_hq get "secureStarted") then { _hq set ["stateT", time - CQ_secureTimeout - 1]; "perimeter forced: installing next tick" }
                    else { "securing starts next tick, press again" };
                };
                case "Installing": { _hq set ["skipStage", true]; "next build stage now" };
                case "Hold": { _hq set ["stateT", time - CQ_holdTime - 1]; "hold ended: calling reinforcements" };
                case "Holding": { _hq set ["nextWaveT", time]; "next reinforcement wave requested" };
                case "WaitingReinf": { _hq set ["waveSkip", true]; "convoy moved to the HQ: split next" };
                default { format ["state %1 cannot be advanced", _st] };
            };
            _msg = format ["HQ #%1 (%2): %3", _id, _st, _msg];
        };
        case "ammo": {
            if ((_hq get "buildDone") && { alive (_hq get "depot") }) then {
                _hq set ["stock", ((_hq get "stock") + 200) min (_hq get "cap")];
                _msg = format ["HQ #%1 depot now %2/%3", _id, round (_hq get "stock"), _hq get "cap"];
            } else {
                _msg = format ["HQ #%1 has no depot yet", _id];
            };
        };
        case "fuel": {
            if ((_hq get "buildDone") && { alive (_hq get "tanker") }) then {
                _hq set ["fuel", ((_hq get "fuel") + 200) min (_hq get "cap")];
                _msg = format ["HQ #%1 fuel now %2/%3", _id, round (_hq get "fuel"), _hq get "cap"];
            } else {
                _msg = format ["HQ #%1 has no fuel tanker", _id];
            };
        };
        case "destroy": {
            if (_hq get "buildDone") then {
                { if (!isNull _x) then { _x setDamage 1 } } forEach [_hq get "commander", _hq get "depot"];
            } else {
                { { _x setDamage 1 } forEach units _x } forEach ((_hq get "infantry") + [_hq get "cmdGroup"]);
            };
            _msg = format ["HQ #%1 destroyed (debug)", _id];
        };
        case "fullHq": {
            // the next HQ complete with every objective and its troops: launches the landing if no
            // HQ stands, then skips every wait (perimeter, each build stage) until it is fully built
            if (!isNil "CQ_dbgFullHq") then { _msg = "a full HQ build is already running" } else {
                CQ_dbgFullHq = true;
                _msg = "full HQ: troops put on the ground at once, every build stage skipped (watch the log)";
                [] spawn {
                    private _t0 = time;
                    private _act = { [(values CQ_hqs) select { (_x get "state") in CQ_activeStates && { !(_x get "buildDone") } }, [], { _x get "id" }] call BIS_fnc_sortBy };
                    if ((call _act) isEqualTo []) then { CQ_nextRootTime = 0 };
                    waitUntil { sleep 2; (call _act) isNotEqualTo [] || { time - _t0 > 120 } };
                    private _l = call _act;
                    if (_l isEqualTo []) exitWith { CQ_dbgFullHq = nil; ["DEBUG full HQ: no landing came (carrier empty or infantry cap?)"] call CQ_fnc_log };
                    private _hq = _l select 0;
                    _hq set ["dbgDrop", true];          // troops straight to the ground, helis stay up (CQ_fnc_insertion)
                    ["DEBUG full HQ: building HQ #%1 at %2", [_hq get "id", mapGridPosition (_hq get "pos")]] call CQ_fnc_log;
                    while { !(_hq get "buildDone") && { (_hq get "state") in CQ_activeStates } && { time - _t0 < 900 } } do {
                        switch (_hq get "state") do {
                            case "Securing": { if (_hq get "secureStarted") then { _hq set ["stateT", time - CQ_secureTimeout - 1] } };
                            case "Installing": { _hq set ["skipStage", true] };
                            default {};
                        };
                        sleep 3;
                    };
                    CQ_dbgFullHq = nil;
                    ["DEBUG full HQ: HQ #%1 %2 after %3 s", [_hq get "id", ["NOT finished (state " + (_hq get "state") + ")", "fully built"] select (_hq get "buildDone"), round (time - _t0)]] call CQ_fnc_log;
                };
            };
        };
        case "root": {
            if (CQ_rootsLaunched < CQ_maxRoots) then {
                CQ_nextRootTime = 0;
                _msg = format ["root insertion %1/%2 launching", CQ_rootsLaunched + 1, CQ_maxRoots];
            } else {
                _msg = "all root insertions already used";
            };
        };
        case "killCmd": {
            private _c = _hq get "commander";
            if (alive _c) then { _c setDamage 1; _msg = format ["HQ #%1: commander killed", _id] } else { _msg = format ["HQ #%1 has no living commander", _id] };
        };
        case "capture": {
            private _c = _hq get "commander";
            if (alive _c && { !isNull _p }) then { ["capture", _c, _p] call CQ_fnc_cmdCapture; _msg = format ["HQ #%1: commander captured", _id] }
            else { _msg = format ["HQ #%1 has no living commander", _id] };
        };
        case "tower": {
            private _r = _hq getOrDefault ["radio", objNull];
            if (alive _r) then { _r setDamage 1; _msg = format ["HQ #%1: radio tower destroyed", _id] } else { _msg = format ["HQ #%1 has no tower", _id] };
        };
        case "depot": {
            private _r = _hq getOrDefault ["depot", objNull];
            if (alive _r) then { _r setDamage 1; _msg = format ["HQ #%1: depot destroyed", _id] } else { _msg = format ["HQ #%1 has no depot", _id] };
        };
        case "logPos": {
            if (!isNull _p) then {
                private _q = getPosATL _p;
                ["DEBUG position of %1: [%2, %3, 0] facing %4", [name _p, round (_q select 0), round (_q select 1), round getDir _p]] call CQ_fnc_log;
                _msg = format ["Position logged: [%1, %2, 0] facing %3", round (_q select 0), round (_q select 1), round getDir _p];
            };
        };
        case "tpRelayVeh": {
            private _rv = missionNamespace getVariable ["CQ_linkRelayVeh", objNull];
            if (!alive _rv) then { _msg = "No relay vehicle out yet" } else {
                if (!isNull _p) then {
                    private _t = _rv getPos [10, getDir _rv + 150];
                    [_p] remoteExec ["moveOut", _p];
                    [_p, _t] spawn { params ["_p", "_t"]; sleep 0.5; _p setPosATL [_t select 0, _t select 1, 0] };
                };
                _msg = format ["Next to the relay vehicle (grid %1, %2 m from its spot)", mapGridPosition _rv, round (_rv distance2D (_rv getVariable ["CQ_linkDest", getPosATL _rv]))];
            };
        };
        case "btKill": {
            private _tr = _hq getOrDefault ["buildTruck", objNull];
            if (alive _tr) then { _tr setDamage 1; _msg = format ["HQ #%1: build truck destroyed (%2 lost, carrier drops %3/%4)", _id, _hq getOrDefault ["btKills", 0], missionNamespace getVariable ["CQ_btDrops", 0], CQ_btMaxDrops] }
            else { _msg = format ["HQ #%1 has no build truck (replacement %2)", _id, ["not asked", "on its way"] select (_hq getOrDefault ["btPending", false])] };
        };
        case "btNow": {
            if (_hq getOrDefault ["btPending", false]) then { _hq set ["btNow", true]; _msg = format ["HQ #%1: replacement truck takes off now", _id] }
            else { _msg = format ["HQ #%1: no replacement truck waiting", _id] };
        };
        case "tpBt": {
            private _tr = _hq getOrDefault ["buildTruck", objNull];
            if (!alive _tr) then { _msg = format ["HQ #%1 has no build truck", _id] } else {
                if (!isNull _p) then {
                    private _t = _tr getPos [12, getDir _tr + 150];
                    [_p] remoteExec ["moveOut", _p];
                    [_p, _t] spawn { params ["_p", "_t"]; sleep 0.5; _p setPosATL [_t select 0, _t select 1, 0] };
                };
                _msg = format ["HQ #%1: next to its build truck (grid %2)", _id, mapGridPosition _tr];
            };
        };
        case "hack": {
            private _r = _hq getOrDefault ["radio", objNull];
            if (alive _r) then { [_r, _p] call CQ_fnc_towerHack; _msg = format ["HQ #%1: radio tower hacked, it is our relay", _id] } else { _msg = format ["HQ #%1 has no standing radio tower", _id] };
        };
        case "tanker": {
            private _r = _hq getOrDefault ["tanker", objNull];
            if (alive _r) then { _r setDamage 1; _msg = format ["HQ #%1: fuel tanker destroyed (%2 fuel points lost)", _id, round (_hq getOrDefault ["fuel", 0])] } else { _msg = format ["HQ #%1 has no fuel tanker", _id] };
        };
        case "wave": { _hq set ["nextWaveT", time]; _msg = format ["HQ #%1: reinforcement wave requested (state %2)", _id, _hq get "state"] };
        case "carrierMinus": {
            CQ_carrierLeft = ((missionNamespace getVariable ["CQ_carrierLeft", CQ_carrierHqs]) - 1) max 0;
            call CQ_fnc_carrierMarker; CQ_actNext = 0;
            _msg = format ["carrier: supplies for %1 more HQ(s)", CQ_carrierLeft];
        };
        case "carrierFull": { CQ_carrierLeft = CQ_carrierHqs; call CQ_fnc_carrierMarker; _msg = "carrier refilled" };
        case "killAll": {
            private _n = 0;
            { if (alive _x && { side group _x in [east, independent] }) then { _x setDamage 1; _n = _n + 1 } } forEach allUnits;
            _msg = format ["%1 enemies killed", _n];
        };
        case "actNext": {
            CQ_act = ((missionNamespace getVariable ["CQ_act", 1]) + 1) min 4;
            publicVariable "CQ_act";
            [format ["act%1", CQ_act], []] call CQ_fnc_say;
            _msg = format ["act %1", CQ_act];
        };
        case "sitrep": { CQ_sitrepT = -1e6; CQ_storyQuietUntil = -1; CQ_actNext = 0; _msg = "SITREP on the next story tick" };
        case "storyReset": { CQ_storyCrossroadT = -1e6; CQ_storyQuietUntil = -1; CQ_storyLast = createHashMap; _msg = "speech budget, silence and cooldowns reset" };
        case "magReport": { CQ_magReportT = -1e6; CQ_magNext = 0; _msg = "MAGPIE report on the next tick (only if something is new)" };
        case "crash": {
            CQ_crashLastT = time;
            _msg = if (call CQ_fnc_crashStart) then { format ["crash site placed at %1", mapGridPosition CQ_crashPos] } else { "no crash site found, try again" };
        };
        case "tpCrash": {
            if (isNil "CQ_crashPos") then { _msg = "no crash yet" } else {
                if (!isNull _p) then {
                    [_p] remoteExec ["moveOut", _p];
                    [_p, CQ_crashPos getPos [400, CQ_crashPos getDir CQ_basePos]] spawn { params ["_p", "_q"]; sleep 0.5; _p setPosATL [_q select 0, _q select 1, 0] };
                    _msg = "teleported 400 m from the crash site";
                };
            };
        };
        case "hst": {
            CQ_hstLastT = time;
            _msg = if (call CQ_fnc_hostageStart) then { format ["hostage held at %1", mapGridPosition CQ_hstPos] } else { "no house found (!)" };
        };
        case "tpHst": {
            if (isNil "CQ_hstState" || { (CQ_hstState get "phase") == "done" }) then { _msg = "no hostage event running" } else {
                if (!isNull _p) then {
                    private _h = CQ_hstState get "hostage";
                    private _c = if (alive _h) then { getPosATL _h } else { CQ_hstState get "pos" };
                    [_p] remoteExec ["moveOut", _p];
                    [_p, _c getPos [300, _c getDir CQ_basePos]] spawn { params ["_p", "_q"]; sleep 0.5; _p setPosATL [_q select 0, _q select 1, 0] };
                    _msg = format ["teleported 300 m from the hostage (phase %1)", CQ_hstState get "phase"];
                };
            };
        };
        case "hstClear": {
            if (isNil "CQ_hstState" || { (CQ_hstState get "phase") != "held" }) then { _msg = "no hostage held" } else {
                private _n = 0;
                { if (alive _x) then { _x setDamage 1; _n = _n + 1 } } forEach (CQ_hstState get "guards");
                _msg = format ["%1 guards killed", _n];
            };
        };
        case "hstFw": {
            if (isNil "CQ_hstState" || { !((CQ_hstState get "phase") in ["held", "clear"]) }) then { _msg = "no hostage waiting for the firmware" } else {
                [_p] call CQ_fnc_hostageFirmware;
                _msg = format ["firmware downloaded, extraction at %1", mapGridPosition (CQ_hstState get "lz")];
            };
        };
        case "hstBoard": {
            if (isNil "CQ_hstState" || { (CQ_hstState get "phase") != "extract" }) then { _msg = "no extraction running" } else {
                private _h = CQ_hstState get "hostage"; private _v = CQ_hstState get "heli";
                if (alive _h && { alive _v }) then { _h assignAsCargo _v; _h moveInCargo _v; _msg = "technician put in the helicopter" } else { _msg = "hostage or helicopter dead" };
            };
        };
        case "hstHome": {
            if (isNil "CQ_hstState" || { (CQ_hstState get "phase") == "done" }) then { _msg = "no hostage event running" } else {
                ["home"] call CQ_fnc_hostageEnd;
                _msg = format ["rescue done: Darter range x%1 for %2 s", CQ_hstBoost, CQ_hstBoostTime];
            };
        };
        case "hstEnd": {
            if (isNil "CQ_hstState" || { (CQ_hstState get "phase") == "done" }) then { _msg = "no hostage event running" } else {
                [] call CQ_fnc_hostageEnd; _msg = "hostage event ended (no result)";
            };
        };
        case "crashOut": {
            // skip the countdown: contact now if none yet, time already up -> the carrier drops at once
            if (isNil "CQ_crashState" || { CQ_crashState get "secured" } || { CQ_crashState get "dropped" }) then { _msg = "no crash waiting for its drop" } else {
                if ((CQ_crashState get "contactT") < 0) then { CQ_crashAlarm = true; publicVariable "CQ_crashAlarm" };
                CQ_crashState set ["contactT", time - CQ_crashTimer - 1];
                CQ_crashState set ["warned", true];
                call CQ_fnc_crashDrop;
                _msg = format ["crash countdown skipped: the carrier drops now (dropped %1)", CQ_crashState get "dropped"];
            };
        };
        case "opBuild": {
            if (!isNil "CQ_outpostState") then { _msg = "the outpost already exists" } else {
                private _hs = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
                private _site = if (_hs isEqualTo []) then { CQ_coastPoint getPos [1500, CQ_coastPoint getDir CQ_basePos] } else { (([_hs, [], { _x get "id" }] call BIS_fnc_sortBy) select 0) get "pos" };
                [_site] spawn CQ_fnc_outpostBuild;
                _msg = format ["corridor outpost being built toward %1 (see the log)", mapGridPosition _site];
            };
        };
        case "opKill": {
            if (isNil "CQ_outpostState") then { _msg = "no outpost" } else {
                { if (alive _x && { _x distance2D (CQ_outpostState get "pos") < 300 }) then { _x setDamage 1 } } forEach (CQ_outpostState get "men");
                _msg = "outpost garrison killed (gunboats spared)";
            };
        };
        case "opJam": {
            if (isNil "CQ_outpostState") then { _msg = "no outpost" } else { (CQ_outpostState get "jammer") setDamage 1; _msg = "outpost jammer destroyed" };
        };
        case "tpOp": {
            if (isNil "CQ_outpostState") then { _msg = "no outpost" } else {
                if (!isNull _p) then {
                    private _q = (CQ_outpostState get "pos") getPos [600, (CQ_outpostState get "pos") getDir CQ_basePos];
                    [_p] remoteExec ["moveOut", _p];
                    [_p, _q] spawn { params ["_p", "_q"]; sleep 0.5; _p setPosATL [_q select 0, _q select 1, 0] };
                    _msg = "teleported 600 m from the outpost (base side)";
                };
            };
        };
        case "decrypt": { [objNull] call CQ_fnc_crashSecure; _msg = format ["decryption on for %1 s", CQ_crashDecrypt] };
        case "magLaunch": {
            { if (!alive (_x get "veh")) then { _x set ["due", time] } } forEach CQ_mag;
            CQ_magNext = 0; _msg = "missing drones launch now";
        };
        case "magKill": {
            private _n = 0;
            { if (alive (_x get "veh")) then { (_x get "veh") setDamage 1; _n = _n + 1 } } forEach CQ_mag;
            _msg = format ["%1 drone(s) shot down", _n];
        };
        case "heal": { if (!isNull _p) then { _p setDamage 0; _msg = "healed" } };
        case "tpBase": {
            if (!isNull _p) then {
                [_p] remoteExec ["moveOut", _p];
                [_p] spawn { params ["_p"]; sleep 0.5; _p setPosATL CQ_musterPos };
                _msg = "teleported to the base";
            };
        };
        case "tpTower": {
            private _r = _hq getOrDefault ["radio", objNull];
            if (isNull _r) then { _r = _hq getOrDefault ["radioHacked", objNull] };
            if (isNull _r) then { _msg = format ["HQ #%1 has no radio tower yet", _id] } else {
                if (!isNull _p) then {
                    private _tm = _r getVariable ["CQ_terminal", objNull];
                    private _t = if (isNull _tm) then { (getPosATL _r) getPos [9, (getPosATL _r) getDir (_hq get "pos")] } else { (getPosATL _tm) getPos [2, getDir _tm] };
                    [_p] remoteExec ["moveOut", _p];
                    [_p, _t] spawn { params ["_p", "_t"]; sleep 0.5; _p setPosATL [_t select 0, _t select 1, 0] };
                    _msg = format ["teleported to the foot of HQ #%1's radio tower", _id];
                };
            };
        };
        case "tpHq": {
            if (!isNull _p) then {
                private _t = (_hq get "pos") getPos [250, random 360];
                if (vehicle _p != _p) then { (vehicle _p) setPosATL [_t select 0, _t select 1, 0] } else { _p setPosATL [_t select 0, _t select 1, 0] };
                _msg = format ["teleported 250 m from HQ #%1", _id];
            };
        };
        case "points": {
            private _g = group _p;
            if (isNull _p || { _g getVariable ["CQ_solo", true] }) then { _msg = "join or create a squad first" } else {
                _g setVariable ["CQ_sqPts", (_g getVariable ["CQ_sqPts", 0]) + 500, true];
                _msg = format ["%1 now has %2 squad points", groupId _g, _g getVariable ["CQ_sqPts", 0]];
            };
        };
        case "vehFix": {
            private _v = vehicle _p;
            if (isNull _p || { _v == _p }) then { _msg = "get in a vehicle first" } else {
                _v setDamage 0; [_v, 1] remoteExec ["setFuel", _v]; [_v, 1] remoteExec ["setVehicleAmmo", _v];
                _msg = format ["%1 repaired, refuelled, rearmed", typeOf _v];
            };
        };
        case "vehReset": {
            private _gone = CQ_depotVehs select { !alive _x || { ({ alive _x } count crew _x) == 0 } };
            { deleteVehicle _x } forEach (_gone select { !isNull _x });
            CQ_depotVehs = CQ_depotVehs - _gone;
            publicVariable "CQ_depotVehs";
            CQ_depotReady = createHashMap;
            publicVariable "CQ_depotReady";
            _msg = format ["%1 empty depot vehicles back in stock, cooldowns cleared", count _gone];
        };
        case "defRebuild": {
            { [_x] call CQ_fnc_baseDefBuild; _x set ["lostT", -1] } forEach CQ_baseDefs;
            _msg = format ["%1 base defence spots rebuilt", count CQ_baseDefs];
        };
        case "fullPower": {
            CQ_testFullPower = _id == 1;
            publicVariable "CQ_testFullPower";
            CQ_netNext = 0;
            call CQ_fnc_netScale;
            _msg = format ["full power %1: enemy factor %2, infantry cap %3, wave every %4 s", ["OFF", "ON"] select CQ_testFullPower, CQ_scale, CQ_maxInfantry, CQ_waveInterval];
        };
        case "logs": {
            if (isNil "CQ_logSubs") then { CQ_logSubs = createHashMap };
            private _f = [(_id mod 2) == 1, _id >= 2];
            if (_f isEqualTo [false, false]) then { CQ_logSubs deleteAt _caller } else { CQ_logSubs set [_caller, _f] };
            [missionNamespace, ["CQ_myLogs", _f]] remoteExec ["setVariable", _caller];
            _msg = format ["enemy logs %1, friendly logs %2", ["OFF", "ON"] select (_f select 0), ["OFF", "ON"] select (_f select 1)];
        };
        case "playerView": {
            CQ_playerView = _id == 1;        // the panel sends the wanted state (1 on, 0 off)
            publicVariable "CQ_playerView";
            call CQ_fnc_playerViewMarkers;
            _msg = format ["final player view %1 (debug chat, debug cards and debug map markers %2)", ["OFF", "ON"] select CQ_playerView, ["shown", "hidden"] select CQ_playerView];
        };
        case "time1": { skipTime 1; _msg = "+1 hour" };
        case "noon": { skipTime ((12 - daytime + 24) % 24); _msg = "noon" };
        case "night": { skipTime ((23 - daytime + 24) % 24); _msg = "23:00" };
        case "clearWx": { 0 setOvercast 0; 0 setRain 0; 0 setFog 0; forceWeatherChange; _msg = "clear weather" };
        case "flight": {
            if (CQ_hubId < 0) then { _msg = "no main HQ yet" } else {
                if (CQ_ammoFlightActive) then { _msg = "an ammo flight is already in the air" } else {
                    CQ_nextAmmoFlight = time - 1;
                    CQ_logiNext = 0;
                    _msg = format ["supply flight to main HQ #%1 launching", CQ_hubId];
                };
            };
        };
    };
};
if (_msg != "") then { ["DEBUG panel: %1", [_msg]] call CQ_fnc_log };

// --- answer with the HQ list and a status line
private _rows = [];
{
    private _h = _y;
    private _inf = [(_h get "infantry")] call CQ_fnc_aliveCount;
    _rows pushBack [_h get "id", format ["HQ #%1%2  %3  |  ammo %4  fuel %9 /%5  |  inf %6%7%8",
        _h get "id", ["", " MAIN"] select ((_h get "id") == CQ_hubId), _h get "state",
        round (_h get "stock"), _h get "cap", _inf,
        ["", format ["  |  child of #%1", _h get "parent"]] select ((_h get "parent") > -1),
        ["", format ["  |  site tolerance %1", _h get "siteLevel"]] select ((_h get "siteLevel") > 0),
        round (_h get "fuel")], _h get "pos"];
} forEach CQ_hqs;
_rows sort true;

private _left = missionNamespace getVariable ["CQ_carrierLeft", CQ_carrierHqs];
private _drones = (missionNamespace getVariable ["CQ_mag", []]) apply {
    format ["%1 %2", _x get "name", if (alive (_x get "veh")) then { format ["%1 %2 m", _x getOrDefault ["phase", ""], round ((getPosATL (_x get "veh")) select 2)] } else { format ["in %1 s", round (((_x get "due") - time) max 0)] }]
};
private _status = format ["<t size='0.85'>Act <t color='#918C3B'>%1</t>   |   carrier <t color='#918C3B'>%2%%</t> (%3 HQ left)   |   insertions %4/%5, next in %6 s<br/>Enemy infantry <t color='#918C3B'>%7/%8</t>   |   all AI %9/%10   |   main HQ %11   |   trucks %12   |   aircraft %13<br/>MAGPIE: %14<br/>Medics %15, engineers %16 respawns left   |   time %17   |   %18 players</t>",
    missionNamespace getVariable ["CQ_act", 1], round (100 * (_left max 0) / CQ_carrierHqs), _left max 0,
    CQ_rootsLaunched, CQ_maxRoots, round ((CQ_nextRootTime - serverTime) max 0),
    call CQ_fnc_enemyInfantry, CQ_maxInfantry, call CQ_fnc_enemyCount, CQ_maxAI,
    ["none", format ["#%1", CQ_hubId]] select (CQ_hubId > -1), CQ_trucksActive, count CQ_air,
    if (_drones isEqualTo []) then { "-" } else { _drones joinString "   " },
    (missionNamespace getVariable ["CQ_specialLeft", createHashMap]) getOrDefault ["medic", "-"],
    (missionNamespace getVariable ["CQ_specialLeft", createHashMap]) getOrDefault ["engineer", "-"],
    [daytime, "HH:MM"] call BIS_fnc_timeToString, count allPlayers];

[_rows, _msg, _status, [_hq] call CQ_fnc_debugHqDash] remoteExec ["CQ_fnc_debugUiFill", _caller];
