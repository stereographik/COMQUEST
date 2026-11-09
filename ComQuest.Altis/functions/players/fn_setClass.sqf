/*
    CQ_fnc_setClass  (client, from the CLASS tab of the U menu)
    [_label] call CQ_fnc_setClass;
    Every lobby slot is a Rifleman; the class is taken in game, at the base (within
    inside the walls of the HQ compound, CQ_compoundSize + CQ_classChangeRange margin): default loadout of that class (CQ_classes), its
    traits (medic heals fully, engineer repairs / defuses, explosive specialist), the class
    shown on the leaderboard.
    Each class has a player limit (4th field of CQ_classes). Kept through respawns. The arsenal can still customise it.
*/
params ["_label"];
private _i = CQ_classes findIf { (_x select 0) == _label };
if (_i < 0) exitWith {};
if !(player inArea [CQ_basePos, (CQ_compoundSize select 0) / 2 + CQ_classChangeRange, (CQ_compoundSize select 1) / 2 + CQ_classChangeRange, CQ_baseDir, true]) exitWith { hint "Classes can only be changed inside the HQ compound" };
(CQ_classes select _i) params ["", "_cls", "_traits", ["_max", 99]];
if (_label == (player getVariable ["CQ_class", "Rifleman"])) exitWith { hint format ["You are already %1", _label] };
private _taken = { _x != player && { (_x getVariable ["CQ_class", "Rifleman"]) == _label } } count (allPlayers select { side group _x == west });
if (_taken >= _max) exitWith { hint format ["%1: no slot left (%2 / %2 taken)", _label, _max] };
private _lo = getUnitLoadout _cls;
player setUnitLoadout _lo;
CQ_savedLoadout = _lo;
CQ_myClass = _label;
[_traits] call CQ_fnc_applyTraits;
player setVariable ["CQ_class", _label, true];
hint format ["You are now: %1", _label];
