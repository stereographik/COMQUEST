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

        {
            _x params ["_name", "_code"];
            [] call _code;
        } forEach CQ_directorTasks;

        private _dt = diag_tickTime - _t0;
        if (_dt > 0.5) then {
            ["Slow tick: %1 s", [_dt toFixed 2]] call CQ_fnc_log;
        };

        sleep CQ_tickSeconds;
    };
};
