/*
    initServer.sqf - ComQuest server start
*/
["ComQuest server init (milestone 3: HQ network + ammo logistics)"] call CQ_fnc_log;

enableDynamicSimulationSystem true;   // AI far from players stops simulating (used from milestone 2)

call CQ_fnc_baseSetup;
call CQ_fnc_carrierSetup;           // CSAT carrier off the east coast: every insertion starts there

{
    _x params ["_class", "_role", ["_n", 1]];
    private _spots = CQ_baseSpots getOrDefault [_role, []];
    for "_i" from 0 to _n - 1 do { [_class, _spots param [_i, []], CQ_baseDir] call CQ_fnc_vehRegister };
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
CQ_balanceForceT = -1;
["balance", CQ_fnc_hqBalance] call CQ_fnc_directorAddTask;
CQ_vehRoamNext = 0;
CQ_watchNext = 0;
CQ_airBalanceNext = 0;
CQ_rdfNext = 0;
["rdf", CQ_fnc_rdfTick] call CQ_fnc_directorAddTask;
CQ_crateNext = 0;
["crates", CQ_fnc_crateTick] call CQ_fnc_directorAddTask;
["medic"] spawn CQ_fnc_specialTeam;
["engineer"] spawn CQ_fnc_specialTeam;
["groupWatch", CQ_fnc_groupWatch] call CQ_fnc_directorAddTask;
["vehRoam", CQ_fnc_vehRoamTick] call CQ_fnc_directorAddTask;

call CQ_fnc_directorStart;
