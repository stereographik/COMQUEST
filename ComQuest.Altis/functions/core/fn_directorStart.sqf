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
            private _t1 = diag_tickTime;
            [] call _code;
            _times pushBack [diag_tickTime - _t1, _name];
        } forEach CQ_directorTasks;

        private _dt = diag_tickTime - _t0;
        if (_dt > 0.5) then {
            // which tasks took the time, and how busy the scheduler is (all scripts share it)
            _times sort false;
            private _top = (_times select [0, 3]) apply { format ["%1 %2s", _x select 1, (_x select 0) toFixed 1] };
            diag_activeScripts params [["_sp", 0], ["_ex", 0], ["_sq", 0], ["_fsm", 0]];
            ["Slow tick: %1 s (slowest: %2) | scripts spawn %3 execVM %4 fsm %5 | fps %6 | units %7, groups %8",
                [_dt toFixed 2, _top joinString ", ", _sp, _ex, _fsm, round diag_fps, count allUnits, count allGroups]] call CQ_fnc_log;
        };

        sleep CQ_tickSeconds;
    };
};
