/*
    CQ_fnc_hqNerves  (server, from CQ_fnc_hqTick, built and active HQs)
    [_hq] call CQ_fnc_hqNerves;
    Nervousness of a built HQ (CQ_nervNames), it never calms down:
      0 CALM      built, no contact since       large patrols, relaxed
      1 WARY      contact reported              today's patrol loops, aware
      2 TENSE     1st objective destroyed        tighter loops
      3 ALARMED   2nd objective destroyed        close loops, combat
      4 FORTRESS  3+ objectives, or commander killed / captured: everyone holds around the HQ
    Patrol radii per level: CQ_nervPatrolR (1st squad the smallest, then wider).
    Alarm: when an objective falls (installation destroyed, commander killed or captured)
    EVERYTHING of that HQ falls back to defend the commander, 60-150 m around the command
    building: infantry patrols, QRF hunters, armed vehicles and snipers (the squad defending
    the HQ and groups busy rearming stay as they are). Every new loss restarts the clock;
    after CQ_nervAlarmTime s without one, the same groups spread out again at the radius of
    the new level, snipers to fresh high ground (CQ_nervSniperDist). FORTRESS: they stay.
*/
params ["_hq"];
private _id = _hq get "id";
private _c = _hq get "pos";
private _all = _hq get "installations";
private _cmdGone = !alive (_hq get "commander") || { _hq getOrDefault ["cmdCaptured", false] };
private _lost = ({ !alive _x } count _all) + ([0, 1] select _cmdGone);

// ---- level (never goes down)
private _lvl = _hq getOrDefault ["nerv", 0];
private _want = switch (true) do {
    case (_cmdGone || { _lost >= 3 } || { _hq getOrDefault ["isolated", false] }): { 4 };   // nGD: cut off -> dig in
    case (_lost == 2): { 3 };
    case (_lost == 1): { 2 };
    case ((_hq get "lastContactT") > (_hq getOrDefault ["builtT", 0])): { 1 };
    default { 0 };
};
private _changed = _want > _lvl;
if (_changed) then {
    _lvl = _want;
    _hq set ["nerv", _lvl];
    ["HQ #%1 nervousness: %2", [_id, CQ_nervNames select _lvl]] call CQ_fnc_log;
    if (_lvl >= 3 && { !(_hq getOrDefault ["huntCalled", false]) }) then { _hq set ["huntCalled", true]; [_hq] spawn CQ_fnc_huntLaunch };
};

if !(_hq getOrDefault ["nervInit", false]) then { _hq set ["nervInit", true]; _changed = true };   // first pass: patrols take the CALM loops

private _behave = {
    params ["_g"];
    _g setBehaviour (["SAFE", "AWARE", "AWARE", "COMBAT", "COMBAT"] select _lvl);
    _g setSpeedMode (["LIMITED", "NORMAL", "NORMAL", "NORMAL", "FULL"] select _lvl);
    _g setCombatMode (["YELLOW", "YELLOW", "YELLOW", "RED", "RED"] select _lvl);
};
private _patrol = {     // [group, index among patrols, count]
    params ["_g", "_i", "_n"];
    (CQ_nervPatrolR select _lvl) params ["_r0", "_r1"];
    private _r = _r0 + (_r1 - _r0) * ([_i / ((_n - 1) max 1), 0] select (_n <= 1));
    [_g] call CQ_fnc_clearWaypoints;
    [_g, _c, _r] call CQ_fnc_infPatrol;
    [_g] call _behave;
};
private _hold = {       // a spot 60-150 m around the command building
    _c getPos [60 + random 90, random 360]
};

// ---- alarm: an objective just fell
if (_lost > (_hq getOrDefault ["nervLost", 0])) then {
    _hq set ["nervLost", _lost];
    _hq set ["alarmT", time];
    if !(_hq getOrDefault ["alarm", false]) then {
        _hq set ["alarm", true];
        private _inf = (_hq get "infantry") select { !isNull _x && { ({ alive _x } count units _x) > 0 } && { (_x getVariable ["CQ_role", ""]) in ["patrol", "qrf", "reinf", "secure", ""] } };
        private _vg = ((_hq get "vehicles") select { alive _x && { canMove _x } && { !(_x getVariable ["CQ_busy", false]) } && { getAmmoCargo _x == 0 && getFuelCargo _x == 0 && getRepairCargo _x == 0 } })
            apply { group effectiveCommander _x } select { !isNull _x && { (_x getVariable ["CQ_role", ""]) in ["patrol", "qrf", ""] } };
        private _recalled = [];
        {
            [_x] call CQ_fnc_clearWaypoints;
            _x setVariable ["CQ_role", "alarm"];
            _x move (call _hold);
            _x setBehaviour "COMBAT"; _x setCombatMode "RED"; _x setSpeedMode "FULL";
            _recalled pushBack _x;
        } forEach (_inf + _vg);
        private _sn = (_hq getOrDefault ["snipers", []]) select { alive _x };
        { [_x, call _hold] spawn CQ_fnc_sniperPost } forEach _sn;
        _hq set ["alarmGroups", _recalled];
        ["HQ #%1 ALARM: objective lost (%2), %3 groups and %4 snipers fall back to the commander", [_id, _lost, count _recalled, count _sn]] call CQ_fnc_log;
    } else {
        ["HQ #%1 ALARM: another objective lost (%2), they hold %3 s more", [_id, _lost, CQ_nervAlarmTime]] call CQ_fnc_log;
    };
};

// ---- end of alarm: spread out again at the new level (FORTRESS: they stay)
if ((_hq getOrDefault ["alarm", false]) && { time - (_hq get "alarmT") > CQ_nervAlarmTime } && { _lvl < 4 }) then {
    _hq set ["alarm", false];
    private _gs = (_hq getOrDefault ["alarmGroups", []]) select { !isNull _x && { ({ alive _x } count units _x) > 0 } };
    private _inf = _gs select { vehicle leader _x == leader _x };
    { _x setVariable ["CQ_role", "patrol"]; [_x, _forEachIndex, count _inf] call _patrol } forEach _inf;
    {
        _x setVariable ["CQ_role", "patrol"];
        private _v = vehicle leader _x;
        [_x] call CQ_fnc_clearWaypoints;
        [_x, _v, _c] call CQ_fnc_vehRoam;
        [_x] call _behave;
    } forEach (_gs - _inf);
    private _sn = (_hq getOrDefault ["snipers", []]) select { alive _x };
    if (_sn isNotEqualTo []) then {
        private _spots = [_c, count _sn, CQ_nervSniperDist select _lvl] call CQ_fnc_sniperSpots;
        { if (_forEachIndex < count _spots) then { [_x, _spots select _forEachIndex] spawn CQ_fnc_sniperPost } } forEach _sn;
    };
    ["HQ #%1: no new loss for %2 s, %3 groups spread out again (%4), %5 snipers to new spots", [_id, CQ_nervAlarmTime, count _gs, CQ_nervNames select _lvl, count _sn]] call CQ_fnc_log;
    _changed = false;    // just applied
};

// ---- level went up without an alarm running: patrols take the new radius right away
if (_changed && { !(_hq getOrDefault ["alarm", false]) }) then {
    private _pat = (_hq get "infantry") select { !isNull _x && { ({ alive _x } count units _x) > 0 } && { (_x getVariable ["CQ_role", ""]) == "patrol" } };
    if (_lvl == 4) then {
        { [_x] call CQ_fnc_clearWaypoints; _x setVariable ["CQ_role", "alarm"]; _x move (call _hold); [_x] call _behave } forEach _pat;
    } else {
        { [_x, _forEachIndex, count _pat] call _patrol } forEach _pat;
    };
};
