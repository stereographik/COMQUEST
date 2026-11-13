/*
    CQ_fnc_directorStart  (server)
    The one server loop. Every CQ_tickSeconds it runs each registered task.
    Systems never start their own sleep loops: they register a task instead.
*/
if (!isServer) exitWith {};
if (!isNil "CQ_directorHandle") exitWith { ["Director already running"] call CQ_fnc_log };
if (isNil "CQ_directorTasks") then { CQ_directorTasks = [] };

CQ_directorHandle = [] spawn {
    ["Director started, tick %1 s, %2 task(s)", [CQ_tickSeconds, count CQ_directorTasks]] call CQ_fnc_log;

    while { true } do {
        private _t0 = diag_tickTime;

        private _times = [];
        {
            _x params ["_name", "_code"];
            // heavy tasks run in one go (unscheduled): no time-slicing against every other script,
            // so they finish in the frame they start and their time is their real cost (timed
            // inside the same unscheduled block, "*" in the log)
            if (_name in CQ_directorAtomic) then {
                private _dt1 = 0;
                isNil { private _t1 = diag_tickTime; [] call _code; _dt1 = diag_tickTime - _t1 };
                _times pushBack [_dt1, _name + "*"];
            } else {
                private _t1 = diag_tickTime;
                [] call _code;
                _times pushBack [diag_tickTime - _t1, _name];
            };
        } forEach CQ_directorTasks;

        private _dt = diag_tickTime - _t0;
        if (_dt > 0.5) then {
            // which tasks took the time, and how busy the scheduler is (all scripts share it)
            _times sort false;
            private _top = (_times select [0, 3]) apply { format ["%1 %2s", _x select 1, (_x select 0) toFixed 2] };
            diag_activeScripts params [["_sp", 0], ["_ex", 0], ["_sq", 0], ["_fsm", 0]];
            ["Slow tick: %1 s (slowest: %2) | scripts spawn %3 execVM %4 fsm %5 | fps %6 | units %7, groups %8",
                [_dt toFixed 2, _top joinString ", ", _sp, _ex, _fsm, round diag_fps, count allUnits, count allGroups]] call CQ_fnc_log;
            // once a minute: which scripts are running (file:line, most common first)
            if (time - (missionNamespace getVariable ["CQ_scriptDumpT", -1e6]) > 60 && { _sp > CQ_scriptDumpMin }) then {
                CQ_scriptDumpT = time;
                private _h = createHashMap;
                { private _f = (_x select 1) splitString "\/"; private _k = format ["%1 (%2:%3)", _x select 0, _f param [count _f - 1, "?"], _x select 3]; _h set [_k, (_h getOrDefault [_k, 0]) + 1] } forEach diag_activeSQFScripts;
                private _l = (_h toArray false) apply { [_x select 1, _x select 0] };
                _l sort false;
                ["Scripts running: %1", [((_l select [0, 8]) apply { format ["%1x %2", _x select 0, _x select 1] }) joinString " | "]] call CQ_fnc_log;
            };
        };

        sleep CQ_tickSeconds;
    };
};
