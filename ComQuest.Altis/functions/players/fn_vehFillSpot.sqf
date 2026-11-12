/*
    CQ_fnc_vehFillSpot  (server and client)
    [_vehicle] call CQ_fnc_vehFillSpot  ->  true when the vehicle stands where it can be
    autofilled: in a loading zone (CQ_loadZones) or within CQ_fillBoxRange m of a vehicle
    arsenal box (CQ_vehBoxes: next to every depot pad and loading zone).
*/
params ["_v"];
((missionNamespace getVariable ["CQ_loadZones", []]) findIf { _v distance2D _x < CQ_loadZoneRadius }) > -1
|| { ((missionNamespace getVariable ["CQ_vehBoxes", []]) findIf { !isNull _x && { _v distance2D _x < CQ_fillBoxRange } }) > -1 }
