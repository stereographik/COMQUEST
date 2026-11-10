/*
    CQ_fnc_assaultTick  (server, director task, every 10 s)
    Drives the enemy groups sent against the player base (CQ_role "assault", from
    CQ_fnc_hqSplit) all the way to the friendly commander:
      approach  move on the command post (CQ_cmdPost), AWARE, full speed
      sweep     within CQ_assaultSweep m of it: COMBAT, search and destroy around the post
      breach    within CQ_assaultBreach m: the infantry goes inside, one man per building
                position, Colonel Harlan revealed to them (they know where he is)
    Vehicles only approach and sweep (they cannot go in), again and again.
    A group whose orders ran out (SAD finished) gets them again: an assault never stops
    until the group is dead. Stages only go forward. One log line per group every 60 s.
*/
if (time < (missionNamespace getVariable ["CQ_assaultNext", 0])) exitWith {};
CQ_assaultNext = time + 10;

private _groups = allGroups select { side _x == east && { (_x getVariable ["CQ_role", ""]) == "assault" } && { ({ alive _x } count units _x) > 0 } };
if (_groups isEqualTo []) exitWith {};

private _post = missionNamespace getVariable ["CQ_cmdPost", objNull];
private _cmd = missionNamespace getVariable ["CQ_friendlyCmd", objNull];
private _tgt = if (!isNull _post) then { getPosATL _post } else { if (alive _cmd) then { getPosATL _cmd } else { CQ_basePos } };
private _bps = if (isNull _post) then { [] } else { _post buildingPos -1 };
if (_bps isEqualTo [] && { alive _cmd }) then { _bps = [getPosATL _cmd] };
private _rank = createHashMapFromArray [["", -1], ["approach", 0], ["sweep", 1], ["breach", 2]];
private _report = time > (missionNamespace getVariable ["CQ_assaultReportT", 0]);
if (_report) then { CQ_assaultReportT = time + 60 };

{
    private _g = _x;
    private _l = leader _g;
    private _isVeh = vehicle _l != _l;
    private _d = _l distance2D _tgt;
    private _stage = _g getVariable ["CQ_aStage", ""];
    private _want = call {
        if (!_isVeh && { _d < CQ_assaultBreach }) exitWith { "breach" };
        if (_d < CQ_assaultSweep) exitWith { "sweep" };
        "approach"
    };
    if ((_rank get _want) < (_rank get _stage)) then { _want = _stage };
    private _done = (count waypoints _g) == 0 || { currentWaypoint _g >= count waypoints _g };
    private _new = _want != _stage;

    switch (_want) do {
        case "approach": {
            if (_new || _done) then {
                [_g] call CQ_fnc_clearWaypoints;
                _g setBehaviour "AWARE";
                _g setCombatMode "RED";
                _g setSpeedMode "FULL";
                private _wp = _g addWaypoint [_tgt, 20];
                _wp setWaypointType "MOVE";
                _wp setWaypointCompletionRadius 40;
            };
        };
        case "sweep": {
            if (_new || _done) then {
                [_g] call CQ_fnc_clearWaypoints;
                _g setBehaviour "COMBAT";
                _g setCombatMode "RED";
                _g setSpeedMode "FULL";
                private _wp = _g addWaypoint [_tgt, [40, 120] select _isVeh];
                _wp setWaypointType "SAD";
                if (!_isVeh) then {
                    private _wp2 = _g addWaypoint [_tgt, 0];
                    _wp2 setWaypointType "MOVE";
                    _wp2 setWaypointCompletionRadius 10;
                };
            };
        };
        case "breach": {
            if (_new) then {
                [_g] call CQ_fnc_clearWaypoints;
                _g setBehaviour "COMBAT";
                _g setCombatMode "RED";
                _g setSpeedMode "FULL";
                ["Enemy breach", format ["%1 is storming the command post (%2 men)", groupId _g, { alive _x } count units _g]] call CQ_fnc_announce;
                if (time > (missionNamespace getVariable ["CQ_breachSaidT", -1e6])) then {
                    CQ_breachSaidT = time + 120;
                    ["breach", []] call CQ_fnc_say;
                };
            };
            if (alive _cmd) then { _g reveal [_cmd, 4] };
            // each man to a building position (spread), re-sent when he stopped short of it
            {
                private _u = _x;
                if (!alive _u || { vehicle _u != _u }) then { continue };
                private _p = _bps select (_forEachIndex mod (count _bps max 1));
                if (isNil "_p") then { _p = _tgt };
                if (_new || { unitReady _u && { _u distance _p > 3 } }) then { _u doMove _p };
                if (alive _cmd && { _u distance _cmd < 25 }) then { _u doTarget _cmd; _u doFire _cmd };
            } forEach units _g;
        };
    };
    _g setVariable ["CQ_aStage", _want];
    if (_new) then {
        ["Assault: %1 (HQ #%2) -> %3, %4 m from the command post, %5 alive%6",
            [groupId _g, _g getVariable ["CQ_aHq", -1], _want, round _d, { alive _x } count units _g, ["", " (vehicle)"] select _isVeh]] call CQ_fnc_log;
    } else {
        if (_report) then {
            ["Assault: %1 (HQ #%2) %3, %4 m from the command post, %5 alive, %6 waypoints, behaviour %7",
                [groupId _g, _g getVariable ["CQ_aHq", -1], _want, round _d, { alive _x } count units _g, count waypoints _g, behaviour _l]] call CQ_fnc_log;
        };
    };
} forEach _groups;
