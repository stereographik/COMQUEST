/*
    CQ_fnc_conduct  -  server rules, teamkill warnings, admin tools, player reports
    [_mode, _args] call / remoteExec CQ_fnc_conduct

    Rules gate (first join of the session)
      server "check"   [player]         known UID: CQ_rulesOk; else the client opens the RULES tab
      server "agree"   [player]         UID remembered for the session, CQ_rulesOk on the unit
      client "can"     []  -> bool      rules agreed and not locked out (hint otherwise); used by
                                        vehicles (GetInMan), the arsenal and the class choice
      client "respawn" []               the new body keeps the agreement (CQ_rulesOkLocal)
    Teamkills (server, from the EntityKilled handler of initServer)
      server "tk"      [victim, killer, accident]
        1st within CQ_tkWindow: private warning (gentler if accidental); the victim is told it is logged
        2nd: stronger warning, admins alerted on screen
        3rd and more: sent back to base, no vehicles / arsenal / class for CQ_tkLockTime s, admins alerted
    Admin tools (server, from the debug panel; host or logged-in admin only)
      server "admin"   [cmd, uid, text, admin]   cmd: pWarn, pMute, pBase, pKick
    Reports (server, from the RULES tab)
      server "report"  [reporter, uid, reason]   admins alerted, logged; the reported player is not told
    Client helpers: "msg" [title, text, colour], "lock" [seconds], "mute" [seconds], "kicked" []
    CQ_conductPub (public): [[uid, teamkills, warnings], ...] for the admin player list
*/
params ["_mode", ["_a", []]];

private _admins = {
    allPlayers select { owner _x == 2 || { (admin (owner _x)) == 2 } }
};
private _alert = {
    params ["_txt"];
    ["CQ admin: %1", [_txt]] call CQ_fnc_log;
    { ["msg", ["ADMIN", _txt, "#BA392C"]] remoteExec ["CQ_fnc_conduct", _x] } forEach (call _admins);
};
private _byUid = { params ["_uid"]; (allPlayers select { getPlayerUID _x == _uid }) param [0, objNull] };
private _pub = {
    CQ_conductPub = (keys CQ_conduct) apply { private _r = CQ_conduct get _x; [_x, count (_r select 0), _r select 1] };
    publicVariable "CQ_conductPub";
};
if (isServer && { isNil "CQ_conduct" }) then { CQ_conduct = createHashMap; CQ_rulesUids = [] };   // uid -> [[tk times], warnings]

switch (_mode) do {
    // ---------------------------------------------------------------- rules gate
    case "check": {
        _a params ["_p"];
        if (!CQ_rulesGate || { (getPlayerUID _p) in CQ_rulesUids }) exitWith { _p setVariable ["CQ_rulesOk", true, true] };
        ["openRules", []] remoteExec ["CQ_fnc_conduct", _p];
    };
    case "agree": {
        _a params ["_p"];
        CQ_rulesUids pushBackUnique (getPlayerUID _p);
        _p setVariable ["CQ_rulesOk", true, true];
        ["%1 agreed to the server rules", [name _p]] call CQ_fnc_log;
    };
    case "openRules": {
        if (!hasInterface) exitWith {};
        [] spawn {
            waitUntil { sleep 1; !isNull findDisplay 46 && { alive player } && { isNull findDisplay 49 } };
            sleep 8;                                   // after the intro
            if (player getVariable ["CQ_rulesOk", false]) exitWith {};
            uiNamespace setVariable ["CQ_sqView", "rules"];
            ["rules"] spawn CQ_fnc_squadUi;
        };
    };
    case "can": {
        if !(player getVariable ["CQ_rulesOk", !CQ_rulesGate]) exitWith {
            hint parseText "<t color='#BA392C'>Read and accept the server rules first.</t><br/>Press U, then RULES.";
            false
        };
        private _lock = missionNamespace getVariable ["CQ_lockUntil", 0];
        if (time < _lock) exitWith {
            hint parseText format ["<t color='#BA392C'>Locked out for %1 s more</t><br/>after repeated teamkills.", round (_lock - time)];
            false
        };
        true
    };
    case "respawn": {
        if (missionNamespace getVariable ["CQ_rulesOkLocal", false]) then { player setVariable ["CQ_rulesOk", true, true] };
    };

    // ---------------------------------------------------------------- teamkills
    case "tk": {
        if (!CQ_tkWatch) exitWith {};
        _a params ["_victim", "_killer", ["_accident", false]];
        private _uid = getPlayerUID _killer;
        private _r = CQ_conduct getOrDefault [_uid, [[], 0]];
        private _times = ((_r select 0) select { time - _x < CQ_tkWindow }) + [time];
        CQ_conduct set [_uid, [_times, _r select 1]];
        private _n = count _times;
        ["Teamkill: %1 killed %2 (%3, %4 in %5 min)", [name _killer, name _victim, ["intentional or reckless", "accident"] select _accident, _n, round (CQ_tkWindow / 60)]] call CQ_fnc_log;
        ["msg", ["LOGGED", format ["You were killed by a teammate (%1). It has been logged.", name _killer], "#A6A381"]] remoteExec ["CQ_fnc_conduct", _victim];
        switch (true) do {
            case (_n == 1): {
                private _t = if (_accident) then {
                    format ["You killed %1 by accident. Watch your fire and your driving.", name _victim]
                } else {
                    format ["You killed a teammate: %1. Teamkilling breaks rule 2. This is your warning.", name _victim]
                };
                ["msg", ["WARNING", _t, "#918C3B"]] remoteExec ["CQ_fnc_conduct", _killer];
            };
            case (_n == 2): {
                ["msg", ["SECOND TEAMKILL", format ["Second teamkill in %1 minutes (%2). One more and you are sent back to base and locked out.", round (CQ_tkWindow / 60), name _victim], "#BA392C"]] remoteExec ["CQ_fnc_conduct", _killer];
                [format ["%1: 2nd teamkill in %2 min (victim %3)", name _killer, round (CQ_tkWindow / 60), name _victim]] call _alert;
            };
            default {
                ["lock", [CQ_tkLockTime]] remoteExec ["CQ_fnc_conduct", _killer];
                ["msg", ["LOCKED OUT", format ["%1 teamkills in %2 minutes. You are sent back to base: no vehicles, arsenal or class change for %3 minutes.", _n, round (CQ_tkWindow / 60), round (CQ_tkLockTime / 60)], "#BA392C"]] remoteExec ["CQ_fnc_conduct", _killer];
                [format ["%1: %2 teamkills in %3 min, sent to base and locked out %4 min (victim %5)", name _killer, _n, round (CQ_tkWindow / 60), round (CQ_tkLockTime / 60), name _victim]] call _alert;
            };
        };
        call _pub;
    };

    // ---------------------------------------------------------------- admin tools
    case "admin": {
        _a params ["_cmd", "_uid", ["_text", ""], ["_adm", objNull]];
        private _p = [_uid] call _byUid;
        if (isNull _p) exitWith { ["msg", ["ADMIN", "That player is no longer connected.", "#A6A381"]] remoteExec ["CQ_fnc_conduct", _adm] };
        private _who = if (isNull _adm) then { "an admin" } else { name _adm };
        switch (_cmd) do {
            case "pWarn": {
                if (_text == "") then { _text = "Please follow the server rules (U, then RULES)." };
                ["msg", ["ADMIN WARNING", _text, "#BA392C"]] remoteExec ["CQ_fnc_conduct", _p];
                private _r = CQ_conduct getOrDefault [_uid, [[], 0]];
                CQ_conduct set [_uid, [_r select 0, (_r select 1) + 1]];
                ["Admin %1 warned %2: %3", [_who, name _p, _text]] call CQ_fnc_log;
            };
            case "pMute": {
                ["mute", [CQ_muteTime]] remoteExec ["CQ_fnc_conduct", _p];
                ["msg", ["MUTED", format ["An admin muted your global, side and command channels for %1 minutes.", round (CQ_muteTime / 60)], "#BA392C"]] remoteExec ["CQ_fnc_conduct", _p];
                ["Admin %1 muted %2 for %3 s", [_who, name _p, CQ_muteTime]] call CQ_fnc_log;
            };
            case "pBase": {
                ["lock", [0]] remoteExec ["CQ_fnc_conduct", _p];
                ["msg", ["SENT TO BASE", ["An admin sent you back to base.", _text] select (_text != ""), "#BA392C"]] remoteExec ["CQ_fnc_conduct", _p];
                ["Admin %1 sent %2 to base", [_who, name _p]] call CQ_fnc_log;
            };
            case "pKick": {
                ["Admin %1 kicked %2 (%3)", [_who, name _p, _text]] call CQ_fnc_log;
                // the server's own kick when it may (#kick needs serverCommandPassword on a dedicated server),
                // else the player's mission ends on his machine
                private _done = if (CQ_serverCmdPassword != "") then { CQ_serverCmdPassword serverCommand format ["#kick %1", getPlayerID _p] } else { serverCommand format ["#kick %1", getPlayerID _p] };
                if (!_done) then { ["kicked", [_text]] remoteExec ["CQ_fnc_conduct", _p] };
            };
        };
        call _pub;
        ["msg", ["ADMIN", format ["Done: %1 on %2.", _cmd select [1], name _p], "#8FD16A"]] remoteExec ["CQ_fnc_conduct", _adm];
    };

    // ---------------------------------------------------------------- reports
    case "report": {
        _a params ["_rep", "_uid", ["_reason", "Other"]];
        private _p = [_uid] call _byUid;
        if (isNull _p || { _p == _rep }) exitWith {};
        if (time - (_rep getVariable ["CQ_reportT", -1e6]) < CQ_reportCooldown) exitWith {
            ["msg", ["REPORT", "You sent a report a moment ago. Wait a little before the next one.", "#A6A381"]] remoteExec ["CQ_fnc_conduct", _rep];
        };
        _rep setVariable ["CQ_reportT", time];
        [format ["REPORT by %1: %2 - %3", name _rep, name _p, _reason]] call _alert;
        ["msg", ["REPORT SENT", format ["Your report on %1 (%2) went to the admins. Thank you.", name _p, _reason], "#8FD16A"]] remoteExec ["CQ_fnc_conduct", _rep];
    };

    // ---------------------------------------------------------------- client helpers
    case "msg": {
        if (!hasInterface) exitWith {};
        _a params ["_title", "_text", ["_col", "#918C3B"]];
        hint parseText format ["<t size='1.2' font='PuristaSemibold' color='%1'>%2</t><br/><t color='#F2F1DF'>%3</t>", _col, _title, _text];
        systemChat format ["[%1] %2", _title, _text];
    };
    case "lock": {
        if (!hasInterface) exitWith {};
        _a params [["_secs", 0]];
        if (_secs > 0) then { CQ_lockUntil = time + _secs };
        moveOut player;
        [] spawn {
            sleep 0.5;
            private _m = ["respawn_west", "respawn_base"] select (markerType "respawn_west" == "");
            private _p = if (markerType _m != "") then { getMarkerPos _m } else { CQ_basePos };
            player setPosATL ((_p getPos [3 + random 5, random 360]) vectorAdd [0, 0, 0.2]);
        };
    };
    case "mute": {
        if (!hasInterface) exitWith {};
        _a params [["_secs", 600]];
        { _x enableChannel [false, false] } forEach [0, 1, 2];
        [_secs] spawn { params ["_s"]; sleep _s; { _x enableChannel [true, true] } forEach [0, 1, 2]; systemChat "[MUTED] Your channels are open again." };
    };
    case "kicked": {
        if (!hasInterface) exitWith {};
        ["CQ_kicked", false] call BIS_fnc_endMission;
    };
};
