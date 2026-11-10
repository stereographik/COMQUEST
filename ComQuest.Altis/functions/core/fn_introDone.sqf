/*
    CQ_fnc_introDone  (server, remoteExec'd by a client when its intro ends or is skipped)
    The mission starts CQ_startAfterIntro s after the FIRST player's intro: only the first
    call counts (CQ_introDoneT), initServer.sqf waits for it.
*/
if (!isServer || { !isNil "CQ_introDoneT" }) exitWith {};
CQ_introDoneT = time;
["First intro over: the mission starts in %1 s", [CQ_startAfterIntro]] call CQ_fnc_log;
