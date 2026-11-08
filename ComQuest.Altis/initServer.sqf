/*
    initServer.sqf - ComQuest server start
*/
["ComQuest server init (milestone 2: first HQ cycle)"] call CQ_fnc_log;

enableDynamicSimulationSystem true;   // AI far from players stops simulating (used from milestone 2)

call CQ_fnc_baseSetup;

{
    _x params ["_class", "_marker", "_dir"];
    [_class, _marker, _dir] call CQ_fnc_vehRegister;
} forEach CQ_baseVehicles;

// Enemy network state
CQ_hqs = createHashMap;
CQ_hqNextId = 1;
CQ_rootsLaunched = 0;
CQ_nextRootTime = serverTime + CQ_firstRootDelay;
["First root insertion in %1 s (debug runway: %2)", [CQ_firstRootDelay, CQ_debugFirstAtRunway]] call CQ_fnc_log;

["vehicles", CQ_fnc_vehTick] call CQ_fnc_directorAddTask;
["roots", CQ_fnc_rootTick] call CQ_fnc_directorAddTask;
["hqs", CQ_fnc_hqTick] call CQ_fnc_directorAddTask;

call CQ_fnc_directorStart;
