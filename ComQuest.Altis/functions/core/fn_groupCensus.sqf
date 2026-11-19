/*
    CQ_fnc_groupCensus  (server, director task)
    1) Every 60 s: groups left with no units at all (living or dead) for two passes in a row
       are deleted (safety net: every group is already created with deleteWhenEmpty).
    2) Every CQ_censusEvery s: a census in the .rpt, to find what keeps adding units and groups:
       - units / groups per side (players apart),
       - CSAT live units by kind (group role, event, crew, air, static...),
       - CSAT infantry as the CQ_maxInfantry cap sees it, by kind,
       - CSAT units per HQ (groups listed in the HQ) and the ones no HQ lists,
       - a few samples of the unlisted groups (callsign, grid, size, leader class).
*/
if (time < (missionNamespace getVariable ["CQ_censusSweepT", 0])) exitWith {};
CQ_censusSweepT = time + 60;

// --- 1) empty group sweep
private _swept = 0;
{
    private _g = _x;
    if (!local _g || { count units _g > 0 }) then { _g setVariable ["CQ_emptySeen", nil]; continue };
    if (_g getVariable ["CQ_emptySeen", false]) then { deleteGroup _g; _swept = _swept + 1 } else { _g setVariable ["CQ_emptySeen", true] };
} forEach allGroups;
CQ_censusSwept = (missionNamespace getVariable ["CQ_censusSwept", 0]) + _swept;

if (time < (missionNamespace getVariable ["CQ_censusT", 0])) exitWith {};
CQ_censusT = time + CQ_censusEvery;

// --- 2) census
private _fmt = { params ["_h"]; private _l = (_h toArray false) apply { [_x select 1 select 0, _x select 0, _x select 1 select 1] }; _l sort false; (_l apply { format ["%1 %2u/%3g", _x select 1, _x select 0, _x select 2] }) joinString ", " };
private _add = { params ["_h", "_k", "_n", "_gAdd"]; private _v = _h getOrDefault [_k, [0, 0]]; _h set [_k, [(_v select 0) + _n, (_v select 1) + _gAdd]] };

// groups listed by each HQ (any group, or array of groups, stored in the HQ): tagged on the group
// for this census only (groups cannot be hashmap keys)
private _stamp = time;
{
    private _hq = _x;
    private _tag = format ["HQ#%1 %2 %3", _hq get "id", _hq getOrDefault ["lRole", "-"], _hq get "state"];
    {
        private _v = _y;
        if (_v isEqualType grpNull) then { if (!isNull _v) then { _v setVariable ["CQ_cenOwn", [_stamp, _tag]] } };
        if (_v isEqualType []) then { { if (_x isEqualType grpNull && { !isNull _x }) then { _x setVariable ["CQ_cenOwn", [_stamp, _tag]] } } forEach _v };
    } forEach _hq;
} forEach (values CQ_hqs);

private _sides = createHashMap;
private _kinds = createHashMap;
private _infKinds = createHashMap;
private _hqUse = createHashMap;
private _samples = [];
private _emptyG = 0;
private _players = { isPlayer _x } count allUnits;

{
    private _g = _x;
    private _live = (units _g) select { alive _x };
    if (count units _g == 0) then { _emptyG = _emptyG + 1 };
    private _n = { !isPlayer _x } count _live;
    [_sides, str side _g, _n, 1] call _add;
    if (side _g != east) then { continue };

    private _l = leader _g;
    private _veh = vehicle _l;
    private _role = _g getVariable ["CQ_role", ""];
    private _kind = call {
        if (_g getVariable ["CQ_event", false]) exitWith { "event " + ([_role, "-"] select (_role == "")) };
        if ((units _g) findIf { _x getVariable ["CQ_outpost", false] } > -1) exitWith { "outpost" };
        if (_role != "") exitWith { _role };
        if (_veh isKindOf "Air") exitWith { "air" };
        if (_veh isKindOf "StaticWeapon") exitWith { "static" };
        if (_veh != _l) exitWith { "crew" };
        if (_g getVariable ["CQ_noInfCap", false]) exitWith { "noInfCap" };
        "none"
    };
    [_kinds, _kind, _n, 1] call _add;

    // infantry the way CQ_fnc_enemyInfantry counts it
    private _inf = { !(_x getVariable ["CQ_outpost", false]) && { !(_x getVariable ["CQ_noCap", false]) } && { !(_g getVariable ["CQ_noInfCap", false]) } && { !((_g getVariable ["CQ_role", ""]) in ["guerilla", "escort"]) } && { private _r = (assignedVehicleRole _x) param [0, ""]; (vehicle _x == _x && { !(_r in ["driver", "turret"]) }) || { _r == "cargo" } } } count _live;
    if (_inf > 0) then { [_infKinds, _kind, _inf, 1] call _add };

    (_g getVariable ["CQ_cenOwn", [-1, ""]]) params ["_ot", "_otag"];
    private _o = ["no HQ", _otag] select (_ot == _stamp);
    [_hqUse, _o, _n, 1] call _add;
    if (_o == "no HQ" && { _n > 0 } && { count _samples < 10 }) then {
        _samples pushBack format ["%1 [%2] %3u %4 grid %5", groupId _g, _kind, _n, typeOf _l, mapGridPosition _l];
    };
} forEach allGroups;

["CENSUS: units %1 (players %2), groups %3 (empty %4, swept %5) | AI by side: %6 | caps all %7/%8, infantry %9/%10",
    [count allUnits, _players, count allGroups, _emptyG, CQ_censusSwept, [_sides] call _fmt,
     call CQ_fnc_enemyCount, CQ_maxAI, call CQ_fnc_enemyInfantry, CQ_maxInfantry]] call CQ_fnc_log;
["CENSUS CSAT by kind: %1", [[_kinds] call _fmt]] call CQ_fnc_log;
["CENSUS CSAT infantry (cap view) by kind: %1", [[_infKinds] call _fmt]] call CQ_fnc_log;
["CENSUS CSAT by HQ: %1", [[_hqUse] call _fmt]] call CQ_fnc_log;
if (_samples isNotEqualTo []) then { ["CENSUS CSAT not listed by any HQ: %1", [_samples joinString " | "]] call CQ_fnc_log };
