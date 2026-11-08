/*
    initServer.sqf - ComQuest server start
*/
["ComQuest server init (milestone 1: skeleton + base)"] call CQ_fnc_log;

enableDynamicSimulationSystem true;   // AI far from players stops simulating (used from milestone 2)

call CQ_fnc_baseSetup;

{
    _x params ["_class", "_marker", "_dir"];
    [_class, _marker, _dir] call CQ_fnc_vehRegister;
} forEach CQ_baseVehicles;

["vehicles", CQ_fnc_vehTick] call CQ_fnc_directorAddTask;

call CQ_fnc_directorStart;
