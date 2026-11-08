/*
    initPlayerLocal.sqf - runs on each player's machine when they join
*/
params ["_player", "_didJIP"];

waitUntil { !isNull player };
call CQ_fnc_playerSetup;

["Welcome to ComQuest (%1)", [roleDescription player]] call CQ_fnc_log;
