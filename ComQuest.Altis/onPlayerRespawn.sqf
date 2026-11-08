/*
    onPlayerRespawn.sqf - runs on the player's machine after each respawn
*/
params ["_newUnit", "_oldUnit"];

if (!isNil "CQ_savedLoadout") then {
    _newUnit setUnitLoadout CQ_savedLoadout;
};

call CQ_fnc_playerSetup;
