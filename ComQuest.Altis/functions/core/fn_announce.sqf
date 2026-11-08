/*
    CQ_fnc_announce  (server)
    ["Enemy insertion inbound", "Helicopters heading to grid 123456"] call CQ_fnc_announce;
    Logs the phase and shows it to every player (notification + systemChat).
*/
params [["_title", "", [""]], ["_text", "", [""]]];

["PHASE | %1 | %2", [_title, _text]] call CQ_fnc_log;
if (CQ_debug) then { [_title, _text] remoteExec ["CQ_fnc_notifyClient", 0] };   // story lines: CQ_fnc_say
