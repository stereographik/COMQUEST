/*
    CQ_fnc_linkRepair  (server, director task "linkRepair", every 5 s)
    LINK REPAIR: WASP or the base's relay vehicle out of the data link for CQ_lrDelay s: MAGPIE
    bridges the gap from the nearest linked node with a chain of Darters CQ_lrHop m apart
    (90 % of a drone's range), at most CQ_lrMax. Too long a gap, or not enough free Darters:
    no chain, WASP pulls back inside the network instead (CQ_lrWaspPull, read by CQ_fnc_magTick).
    The chain is re-planned every CQ_lrEvery s; CQ_lrRelease s after the link holds again the
    Darters go back to their jobs (drone entry key "repair", skipped by the fleet's flight plans).
    Free Darter: any flying Darter but WASP and the chain Darters, not getting away from an enemy,
    not looking at a fresh objective; the nearest to its slot goes.
*/
if (!CQ_lrOn) exitWith {};
if (time < (missionNamespace getVariable ["CQ_lrNext", 0])) exitWith {};
CQ_lrNext = time + 5;
if (isNil "CQ_lr") then { CQ_lr = createHashMapFromArray [["since", createHashMap], ["target", objNull], ["planT", -1e6], ["okT", -1], ["pull", false]] };

private _wasp = ((missionNamespace getVariable ["CQ_mag", []]) select { (_x getOrDefault ["role", ""]) == "wasp" && { alive (_x get "veh") } && { (_x getOrDefault ["phase", ""]) == "air" } }) apply { _x get "veh" };
private _rv = missionNamespace getVariable ["CQ_linkRelayVeh", objNull];
private _watch = _wasp + ([[], [_rv]] select (alive _rv));
private _since = CQ_lr get "since";
{
    private _k = hashValue _x;
    if (_x getVariable ["CQ_linked", false]) then { _since deleteAt _k } else { if !(_k in _since) then { _since set [_k, time] } };
} forEach _watch;
{ if !(_x in (_watch apply { hashValue _x })) then { _since deleteAt _x } } forEach (keys _since);

private _repairs = { (missionNamespace getVariable ["CQ_mag", []]) select { _x getOrDefault ["repair", false] } };
private _release = {
    params ["_why"];
    { _x set ["repair", false]; _x set ["planT", -1e6]; _x set ["target", []] } forEach (call _repairs);
    if (CQ_lr get "pull") then { CQ_lrWaspPull = nil };
    private _t = CQ_lr get "target";
    if (!isNull _t || { CQ_lr get "pull" }) then { ["LINK REPAIR: ended (%1)", [_why]] call CQ_fnc_log };
    CQ_lr set ["target", objNull]; CQ_lr set ["pull", false]; CQ_lr set ["okT", -1];
};

// a repair running: target relinked -> release after CQ_lrRelease s; target gone -> release now
private _t = CQ_lr get "target";
if (!isNull _t || { CQ_lr get "pull" }) then {
    if (!alive _t) exitWith { ["target lost"] call _release };
    if (_t getVariable ["CQ_linked", false]) then {
        if ((CQ_lr get "okT") < 0) then {
            CQ_lr set ["okT", time];
            ["LINK REPAIR: %1 back in the network, the Darters hold %2 s more", [["the relay vehicle", "WASP"] select (_t isKindOf "Air"), CQ_lrRelease]] call CQ_fnc_log;
            ["lrDone", [["the relay vehicle", "WASP"] select (_t isKindOf "Air")]] call CQ_fnc_say;
        };
        if (time - (CQ_lr get "okT") > CQ_lrRelease) then { ["link holds"] call _release };
    } else { CQ_lr set ["okT", -1] };
};
_t = CQ_lr get "target";
if (isNull _t) then {
    // new repair: the first node stranded for CQ_lrDelay s
    private _s = _watch select { time - (_since getOrDefault [hashValue _x, time]) >= CQ_lrDelay };
    if (_s isEqualTo []) exitWith {};
    _t = _s select 0;
    CQ_lr set ["target", _t]; CQ_lr set ["planT", -1e6]; CQ_lr set ["okT", -1];
};
if (isNull _t || { (CQ_lr get "okT") >= 0 }) exitWith {};
if (time - (CQ_lr get "planT") < CQ_lrEvery) exitWith {};
CQ_lr set ["planT", time];

// ---- plan: nearest linked node (repair Darters left out), hops of CQ_lrHop m
private _rp = (call _repairs) apply { getPosATL (_x get "veh") };
private _anchors = (((missionNamespace getVariable ["CQ_linkPub", []]) param [0, []]) select { (_x select 2) && { private _p = _x select 0; (_rp findIf { _x distance2D _p < 30 }) == -1 } && { (_x select 0) distance2D _t > 30 } });
if (_anchors isEqualTo []) exitWith {};
private _tp = getPosATL _t;
private _tr = [CQ_linkRelayVehR, CQ_linkDroneR] select (_t isKindOf "Air");
_anchors = [_anchors, [], { (_x select 0) distance2D _tp }, "ASCEND"] call BIS_fnc_sortBy;
(_anchors select 0) params ["_ap", "_ar"];
private _d = _ap distance2D _tp;
private _a = CQ_linkReach * (_ar max CQ_linkDroneR);        // first hop, from the anchor
private _b = CQ_linkReach * (_tr max CQ_linkDroneR);        // last hop, to the stranded node
private _n = if (_d <= _a || { _d <= _b }) then { 1 } else { (ceil ((_d - _a - _b) / CQ_lrHop) max 0) + 1 };
private _free = (missionNamespace getVariable ["CQ_mag", []]) select {
    private _v = _x get "veh";
    alive _v && { _v isKindOf "UAV_01_base_F" } && { (_x getOrDefault ["phase", ""]) == "air" }
    && { !((_x getOrDefault ["role", ""]) in ["wasp", "chain"]) } && { !(_x getOrDefault ["flee", false]) }
    && { time >= (_x getOrDefault ["lookUntil", 0]) }
};
if (_n > CQ_lrMax || { _n > count _free }) exitWith {
    // can't bridge it: WASP pulls back inside the network (the relay vehicle has to wait)
    { _x set ["repair", false]; _x set ["planT", -1e6] } forEach (call _repairs);
    if (_t isKindOf "Air") then {
        CQ_lrWaspPull = [_ap, _a];
        if !(CQ_lr get "pull") then {
            CQ_lr set ["pull", true];
            ["LINK REPAIR: gap %1 m needs %2 Darters (%3 free, max %4): WASP pulls back to grid %5", [round _d, _n, count _free, CQ_lrMax, mapGridPosition _ap]] call CQ_fnc_log;
            ["lrPull", []] call CQ_fnc_say;
        };
    } else {
        ["LINK REPAIR: relay vehicle cut off, gap %1 m needs %2 Darters (%3 free, max %4): no chain", [round _d, _n, count _free, CQ_lrMax]] call CQ_fnc_log;
    };
};
CQ_lrWaspPull = nil; CQ_lr set ["pull", false];
// slots: the first _a from the anchor, the last _b from the target, the others evenly between
private _dir = _ap getDir _tp;
private _slots = if (_n == 1) then {
    [_ap getPos [((_a + (_d - _b)) / 2) min _a max (_d - _b), _dir]]
} else {
    private _s0 = _a min (_d - _b); private _s1 = (_d - _b) max _s0;
    private _out = [];
    for "_i" from 0 to _n - 1 do { _out pushBack (_ap getPos [_s0 + (_s1 - _s0) * _i / (_n - 1), _dir]) };
    _out
};
// the Darters already on the job keep it if still needed, the nearest free ones fill the rest
private _team = (call _repairs) select { alive (_x get "veh") };
if (count _team > _n) then { { _x set ["repair", false]; _x set ["planT", -1e6] } forEach (_team select [_n]); _team resize _n };
private _pool = _free select { !(_x in _team) };
private _new = 0;
while { count _team < _n && { _pool isNotEqualTo [] } } do {
    private _sl = _slots select (count _team);
    private _m = ([_pool, [], { (_x get "veh") distance2D _sl }, "ASCEND"] call BIS_fnc_sortBy) select 0;
    _pool = _pool - [_m];
    _m set ["repair", true]; _m set ["sneak", false];
    _team pushBack _m; _new = _new + 1;
};
{
    private _m = _x;
    private _sl = _slots select _forEachIndex;
    private _v = _m get "veh";
    private _g = group effectiveCommander _v;
    [_g] call CQ_fnc_clearWaypoints;
    _v flyInHeight CQ_lrAlt;
    private _wp = _g addWaypoint [[_sl select 0, _sl select 1, 0], 0];
    _wp setWaypointType "LOITER";
    _wp setWaypointLoiterRadius 80;
    _g setCurrentWaypoint _wp;
    _m set ["target", _sl];
} forEach _team;
if (_new > 0) then {
    ["LINK REPAIR: %1 cut off for %2 s, %3 Darter(s) bridge %4 m from grid %5 (%6 new)", [["relay vehicle", "WASP"] select (_t isKindOf "Air"), round (time - (_since getOrDefault [hashValue _t, time])), _n, round _d, mapGridPosition _ap, _new]] call CQ_fnc_log;
    if (_new == count _team) then { ["lrStart", [["the relay vehicle", "WASP"] select (_t isKindOf "Air"), _n]] call CQ_fnc_say };
};
