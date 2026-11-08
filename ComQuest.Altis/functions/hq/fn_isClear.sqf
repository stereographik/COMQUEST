/*
    CQ_fnc_isClear
    [_pos, _radius, _ignore, _types] call CQ_fnc_isClear  ->  true if nothing stands within _radius:
    no terrain blocker (CQ_blockerTypes: rocks, trees, bushes, houses, walls...) and no
    placed object (buildings, vehicles, statics, crates, other HQ pieces). Soldiers are not
    counted here: they can walk away; big pieces push enemy soldiers out instead.
*/
params ["_pos", "_r", ["_ignore", []], ["_types", CQ_blockerTypes]];

if ((nearestTerrainObjects [_pos, _types, _r, false, true]) isNotEqualTo []) exitWith { false };

private _objs = (nearestObjects [_pos, ["Building", "LandVehicle", "Air", "Ship", "StaticWeapon", "Thing"], _r, true]) - _ignore;
_objs = _objs select { !(_x isKindOf "HeliH") && { !(_x isKindOf "Logic") } };

_objs isEqualTo []
