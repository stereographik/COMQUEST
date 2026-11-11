/*
    CQ_fnc_log
    ["Base vehicle spawned: %1", [_class]] call CQ_fnc_log;
    Writes to the .rpt with a [CQ] prefix. In chat only for the admins who asked for it from the
    debug panel ("Show all enemy logs" / "Show all friendly logs"): the server keeps who gets what
    in CQ_logSubs (owner -> [enemy, friendly]); a client keeps its own choice in CQ_myLogs for the
    lines logged on its own machine. A line is friendly when it starts with a word of
    CQ_logFriendlyRx (MAGPIE, Base, Depot, Squads...), else enemy.
    In debug missions the host starts with both on. Nothing in chat in the final player view.
*/
params [["_msg", "", [""]], ["_args", [], [[]]]];

private _text = format ([_msg] + _args);
diag_log text format ["[CQ] %1", _text];

if (missionNamespace getVariable ["CQ_playerView", false]) exitWith {};
private _friend = _text regexMatch CQ_logFriendlyRx;
if (isServer) then {
    if (isNil "CQ_logSubs") then {
        CQ_logSubs = createHashMap;
        if (CQ_debug && { hasInterface }) then { CQ_logSubs set [clientOwner, [true, true]]; CQ_myLogs = [true, true] };
    };
    private _line = format ["[CQ] %1", _text];
    { if (_y select ([0, 1] select _friend)) then { _line remoteExec ["systemChat", _x] } } forEach CQ_logSubs;
} else {
    if (hasInterface && { (missionNamespace getVariable ["CQ_myLogs", [false, false]]) select ([0, 1] select _friend) }) then {
        systemChat format ["[CQ] %1", _text];
    };
};
