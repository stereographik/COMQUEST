/*
    CQ_fnc_applyTraits  (client)
    [_traits] call CQ_fnc_applyTraits;    _traits: e.g. ["Medic"] or ["Engineer", "explosiveSpecialist"]
    Resets the class traits, then sets the given ones on the player.
*/
params [["_traits", []]];
{ player setUnitTrait [_x, _x in _traits] } forEach ["Medic", "Engineer", "explosiveSpecialist", "UAVHacker"];
