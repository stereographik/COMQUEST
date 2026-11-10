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
// respawned at the base: on a free spot outside next to the muster point (not stacked on the
// marker or inside a building)
if (!isNil "CQ_musterPos" && { _newUnit distance2D CQ_musterPos < 30 }) then {
    private _sp = CQ_musterPos findEmptyPosition [0, 8, "B_Soldier_F"];
    if (_sp isNotEqualTo []) then { _newUnit setPosATL [_sp select 0, _sp select 1, 0] };
};
call CQ_fnc_playerSetup;
