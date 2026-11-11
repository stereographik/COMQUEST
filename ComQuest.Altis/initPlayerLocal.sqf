/*
    initPlayerLocal.sqf - runs on each player's machine when they join
*/
params ["_player", "_didJIP"];

waitUntil { !isNull player };
// Start on the muster area of the base camp
if (!_didJIP || { player distance2D CQ_basePos < 200 }) then {
    waitUntil { !isNil "CQ_musterPos" };
    // a free spot outside, close to the muster point (never in a building or on another player)
    private _sp = CQ_musterPos findEmptyPosition [0, 8, "B_Soldier_F"];
    if (_sp isEqualTo []) then { _sp = CQ_musterPos };
    player setPosATL [_sp select 0, _sp select 1, 0];
    player setDir CQ_baseDir;
};
// Every slot is a Rifleman: the class is taken in game (U -> CLASS)
if (isNil "CQ_myClass") then { CQ_myClass = "Rifleman"; player setVariable ["CQ_class", "Rifleman", true] };
call CQ_fnc_playerSetup;
// Everyone starts unassigned: squads are chosen or created in the squad manager (U)
if (isNil "CQ_unassignedDone") then {
    CQ_unassignedDone = true;
    ["unassign", player] remoteExec ["CQ_fnc_squadCmd", 2];
    [] spawn { sleep 6; hint parseText "<t size='1.1' color='#F2F1DF'>You are unassigned.</t><br/>Press <t color='#918C3B'>U</t> to join or create a squad."; };
};
call CQ_fnc_grassCut;      // no grass around the base (local objects)
[] spawn CQ_fnc_opClient;   // map: Operation (progress checklist) - first section of the briefing
[] spawn CQ_fnc_intro;   // 5 s cinematic intro
player createDiarySubject ["CQ_op", "Operation"];     // first in the map's briefing panel
// Briefing tab: the opening orders
player createDiaryRecord ["Diary", ["Orders", "<font face='PuristaSemibold' size='16' color='#F2F1DF'>GET YOUR STUFF UP FAST, SOLDIERS</font><br/><br/>CSAT has a carrier group offshore and will start landing troops on Altis within minutes.<br/><br/><font color='#918C3B'>1.</font> Press <font color='#F2F1DF'>U</font>: join or create a squad, pick your class inside the HQ compound. Every class comes fully kitted.<br/><font color='#918C3B'>2.</font> Grab a ride at the shop pad.<br/><font color='#918C3B'>3.</font> Find where they ground, then cut the network: HQs, radio towers, supply lines.<br/><br/><font color='#A6A381'>Progress is tracked in the Operation tab.</font>"]];
// Credits (map diary)
player createDiarySubject ["CQ_credits", "Credits"];
player createDiaryRecord ["CQ_credits", ["ComQuest.Altis", format [
    "<font face='PuristaSemibold' size='18' color='#F2F1DF'>COMQUEST</font><br/><font color='#A6A381'>Arma 3 multiplayer co-op on Altis</font><br/><br/>Mission by <font color='#F2F1DF'>Django aka stereographik</font><br/>Version <font color='#F2F1DF'>%1</font>, built %2<br/><br/><font color='#A6A381'>github.com/stereographik/COMQUEST</font>",
    CQ_version, CQ_build]]];
[] spawn CQ_fnc_rdfClient;   // radio direction finder panel
[] spawn CQ_fnc_statsClient; // shots, heals, distances, time played
call CQ_fnc_heatMapClient;   // MAGPIE heatmap under everything else
call CQ_fnc_rangeMapClient;   // range map: ground the seen enemies can fire on (drawn by magMapClient)
call CQ_fnc_magMapClient;
call CQ_fnc_rankBoard;
// version, branch and build stamp, tiny at the bottom right of the screen
[] spawn {
    disableSerialization;
    waitUntil { sleep 0.5; !isNull findDisplay 46 };
    private _c = (findDisplay 46) ctrlCreate ["RscText", -1];
    _c ctrlSetPosition [safeZoneX + safeZoneW - 0.42, safeZoneY + safeZoneH - 0.028, 0.41, 0.026];
    _c ctrlSetFont "PuristaLight";
    _c ctrlSetFontHeight 0.022;
    _c ctrlSetTextColor [0.95, 0.94, 0.87, 0.45];
    _c ctrlSetText format ["ComQuest %1  ·  %2  ·  %3", CQ_version, missionNamespace getVariable ["CQ_branch", "?"], CQ_build];
    _c ctrlSetStyle 1;     // right aligned
    _c ctrlCommit 0;
};       // squad ranking under the base billboard banner    // MAGPIE drones + enemies in their sight, live on the map
call CQ_fnc_debugMap;

["Welcome to ComQuest (%1)", [roleDescription player]] call CQ_fnc_log;
