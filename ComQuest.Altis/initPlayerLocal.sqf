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
// Every slot is a Rifleman: the class is taken in game (U -> CLASS)
if (isNil "CQ_myClass") then { CQ_myClass = "Rifleman"; player setVariable ["CQ_class", "Rifleman", true] };
call CQ_fnc_playerSetup;
// Everyone starts unassigned: squads are chosen or created in the squad manager (U)
if (isNil "CQ_unassignedDone") then {
    CQ_unassignedDone = true;
    ["unassign", player] remoteExec ["CQ_fnc_squadCmd", 2];
    [] spawn { sleep 6; hint parseText "<t size='1.1' color='#9FD3FF'>You are unassigned.</t><br/>Press <t color='#c8e07a'>U</t> to join or create a squad."; };
};
[] spawn CQ_fnc_rdfClient;   // radio direction finder panel
[] spawn CQ_fnc_statsClient; // shots, heals, distances, time played
call CQ_fnc_debugMap;

["Welcome to ComQuest (%1)", [roleDescription player]] call CQ_fnc_log;
