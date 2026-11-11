/*
    CQ_fnc_announce  (server)
    ["Enemy insertion inbound", "Helicopters heading to grid 123456"] call CQ_fnc_announce;
    Logs the phase; admins with the enemy logs on also get a notification card.
*/
params [["_title", "", [""]], ["_text", "", [""]]];

["PHASE | %1 | %2", [_title, _text]] call CQ_fnc_log;
// debug card only for the admins who get the enemy logs (CQ_fnc_log); story lines: CQ_fnc_say
if !(missionNamespace getVariable ["CQ_playerView", false]) then {
    { if (_y select 0) then { [_title, _text] remoteExec ["CQ_fnc_notifyClient", _x] } } forEach (missionNamespace getVariable ["CQ_logSubs", createHashMap]);
};
