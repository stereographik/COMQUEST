/*
    CQ_fnc_vehFillSpot  (server and client)
    [_vehicle] call CQ_fnc_vehFillSpot  ->  true when the vehicle stands on a depot helipad or at
    its repair depot (CQ_depots: [depot furniture, pad, facing]), within CQ_fillPadRange m.
    That is where vehicles are kitted (squad autofill, vehicle arsenal box beside the pad).
*/
params ["_v"];
((missionNamespace getVariable ["CQ_depots", []]) findIf { _v distance2D (_x select 1) < CQ_fillPadRange || { _v distance2D (_x select 0) < CQ_fillPadRange } }) > -1
