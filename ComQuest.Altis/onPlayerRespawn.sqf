/*
    onPlayerRespawn.sqf - runs on the player's machine after each respawn
*/
params ["_newUnit", "_oldUnit"];

if (!isNil "CQ_savedLoadout") then {
    _newUnit setUnitLoadout CQ_savedLoadout;
};

// keep the class taken in game (traits are per unit)
if (!isNil "CQ_myClass") then {
    private _i = CQ_classes findIf { (_x select 0) == CQ_myClass };
    if (_i > -1) then { [(CQ_classes select _i) select 2] call CQ_fnc_applyTraits };
    _newUnit setVariable ["CQ_class", CQ_myClass, true];
};
call CQ_fnc_playerSetup;
