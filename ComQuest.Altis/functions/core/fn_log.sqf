/*
    CQ_fnc_log
    ["Base vehicle spawned: %1", [_class]] call CQ_fnc_log;
    Writes to the .rpt with a [CQ] prefix; also to systemChat when CQ_debug is on.
*/
params [["_msg", "", [""]], ["_args", [], [[]]]];

private _text = format ([_msg] + _args);
diag_log text format ["[CQ] %1", _text];

if (CQ_debug && { hasInterface } && { !(missionNamespace getVariable ["CQ_playerView", false]) }) then {
    systemChat format ["[CQ] %1", _text];
};
