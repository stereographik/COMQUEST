/*
    CQ_fnc_directorAddTask  (server)
    ["vehicles", CQ_fnc_vehTick] call CQ_fnc_directorAddTask;
    Registers code the director runs every tick, in registration order.
*/
params [["_name", "", [""]], ["_code", {}, [{}]]];

if (!isServer) exitWith {};
if (isNil "CQ_directorTasks") then { CQ_directorTasks = [] };

CQ_directorTasks pushBack [_name, _code];
["Director task added: %1", [_name]] call CQ_fnc_log;
