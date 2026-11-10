/*
    CQ_fnc_objName
    [_hqId] call CQ_fnc_objName  ->  "HOSTILES #3"
    How messages name an enemy HQ (player squads use the Alpha / Bravo callsigns).
*/
params ["_id"];
format ["HOSTILES #%1", _id]
