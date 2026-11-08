/*
    initPlayerLocal.sqf - runs on each player's machine when they join
*/
params ["_player", "_didJIP"];

waitUntil { !isNull player };
// Start on the muster area of the base camp
if (!_didJIP || { player distance2D CQ_basePos < 200 }) then {
    waitUntil { !isNil "CQ_musterPos" };
    player setPosATL (CQ_musterPos getPos [2 + random 8, random 360]);
    player setDir CQ_baseDir;
};
call CQ_fnc_playerSetup;
[] spawn CQ_fnc_rdfClient;   // radio direction finder panel
call CQ_fnc_debugMap;

["Welcome to ComQuest (%1)", [roleDescription player]] call CQ_fnc_log;
