/*
    initServer.sqf - ComQuest server start
*/
["ComQuest server init (milestone 3: HQ network + ammo logistics)"] call CQ_fnc_log;

enableDynamicSimulationSystem true;   // AI far from players stops simulating (used from milestone 2)

call CQ_fnc_baseSetup;
call CQ_fnc_carrierSetup;           // CSAT carrier off the east coast: every insertion starts there

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

// Logistics and air state
CQ_hubId = -1;
CQ_air = [];
CQ_trucksActive = 0;
CQ_nextAmmoFlight = -1;          // set when the first main HQ exists
CQ_ammoFlightActive = false;
CQ_logiNext = 0;
CQ_logiReportT = 0;

["vehicles", CQ_fnc_vehTick] call CQ_fnc_directorAddTask;
["roots", CQ_fnc_rootTick] call CQ_fnc_directorAddTask;
["hqs", CQ_fnc_hqTick] call CQ_fnc_directorAddTask;
["logistics", CQ_fnc_logiTick] call CQ_fnc_directorAddTask;
["air", CQ_fnc_airTick] call CQ_fnc_directorAddTask;
CQ_balanceNext = 0;
["balance", CQ_fnc_hqBalance] call CQ_fnc_directorAddTask;
CQ_vehRoamNext = 0;
["vehRoam", CQ_fnc_vehRoamTick] call CQ_fnc_directorAddTask;

call CQ_fnc_directorStart;
