/*
    CQ_fnc_groupWatch  (server, director task, every 30 s)
    Watchdog for HQ infantry and guerillas: a group on patrol (or a fresh reinforcement
    left standing) whose leader has not moved 5 m in CQ_watchIdle seconds outside combat
    gets a new patrol loop (CQ_fnc_infPatrol). Every restart is logged with the group's
    callsign, so a stuck squad can be found in the .rpt.
*/
if (time < CQ_watchNext) exitWith {};
CQ_watchNext = time + 30;

{
    private _hq = _x;
    if !((_hq get "state") in (CQ_activeStates - ["Inbound"])) then { continue };
    private _c = _hq get "pos";
    {
        private _g = _x;
        if (isNull _g || { ({ alive _x } count units _g) == 0 }) then { continue };
        private _role = _g getVariable ["CQ_role", ""];
        if !(_role in ["patrol", "guerilla", "reinf"]) then { continue };
        private _l = leader _g;
        if (vehicle _l != _l || { behaviour _l == "COMBAT" }) then {
            _g setVariable ["CQ_watchPos", getPosATL _l];
            _g setVariable ["CQ_watchT", time];
            continue;
        };
        if (_l distance (_g getVariable ["CQ_watchPos", [0,0,0]]) > 5) then {
            _g setVariable ["CQ_watchPos", getPosATL _l];
            _g setVariable ["CQ_watchT", time];
            continue;
        };
        if (time - (_g getVariable ["CQ_watchT", time]) < CQ_watchIdle) then { continue };
        ["Watchdog: %1 (HQ #%2, %3) idle %4 s at grid %5, %6 waypoints, new patrol",
            [groupId _g, _hq get "id", _role, round (time - (_g getVariable ["CQ_watchT", time])), mapGridPosition _l, count waypoints _g]] call CQ_fnc_log;
        if (_role == "reinf") then { _g setVariable ["CQ_role", "patrol"] };
        [_g, _g getVariable ["CQ_patrolC", _c], _g getVariable ["CQ_patrolR", CQ_patrolRadius select 0]] call CQ_fnc_infPatrol;
    } forEach ((_hq get "infantry") + (_hq getOrDefault ["guerilla", []]));
} forEach (values CQ_hqs);
