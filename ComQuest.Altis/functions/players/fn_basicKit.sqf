/*
    CQ_fnc_basicKit  (client)
    Adds what every equipment preset must carry: binoculars and a GPS (CQ_basicKit).
*/
if (binocular player == "") then { player addWeapon "Binocular" };
{ if !(_x in assignedItems player) then { player linkItem _x } } forEach CQ_basicKit;
