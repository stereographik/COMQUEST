/*
    CQ_fnc_debugCmd  (server, from the debug panel CQ_fnc_debugUi)
    [_cmd, _hqId] remoteExec ["CQ_fnc_debugCmd", 2];
    Allowed for debug missions, the host and logged-in admins.
    Enemy HQ (selected):  next, ammo, fuel, killCmd, capture, tower, depot, destroy, wave
    Carrier and forces:   root, flight, carrierMinus, carrierFull, killAll
    Story:                actNext, sitrep, storyReset
    MAGPIE:               magReport, magLaunch, magKill
    Player (the caller):  heal, tpBase, tpHq, points, vehFix
    Base and world:       vehReset, defRebuild, time1, noon, night, clearWx
    View:                 playerView (the game as a final player sees it: no debug output)
    list                  just refresh
    Answers the caller with the HQ list (CQ_fnc_debugUiFill).
*/
params [["_cmd", "list"], ["_id", -1]];
private _caller = remoteExecutedOwner;
if !(CQ_debug || { _caller == 2 } || { (admin _caller) > 0 }) exitWith {};
private _p = (allPlayers select { owner _x == _caller }) param [0, objNull];
private _hq = CQ_hqs getOrDefault [_id, createHashMap];
private _msg = "";
private _needHq = _cmd in ["next", "ammo", "fuel", "destroy", "killCmd", "capture", "tower", "depot", "wave", "tpHq"];

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
            private _n = 0;
            {
                private _v = _x get "veh";
                if (isNull _v || { !alive _v } || { ({ alive _x } count crew _v) == 0 }) then {
                    if (!isNull _v) then { deleteVehicle _v };
                    [_x] call CQ_fnc_vehSpawn;
                    _n = _n + 1;
                };
            } forEach CQ_vehEntries;
            _msg = format ["%1 base vehicles respawned on their spots", _n];
        };
        case "defRebuild": {
            { [_x] call CQ_fnc_baseDefBuild; _x set ["lostT", -1] } forEach CQ_baseDefs;
            _msg = format ["%1 base defence spots rebuilt", count CQ_baseDefs];
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

[_rows, _msg, _status] remoteExec ["CQ_fnc_debugUiFill", _caller];
