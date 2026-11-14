/*
    CQ_fnc_magDormant  (server, director task, every 3 s)
    MAGPIE's dormant Darters (allaroundisland). Points every CQ_magDormantGap m on land
    (CQ_magDormantPts, built by CQ_fnc_magInit) are Darters grounded all over the island:
    coordinates only, no objects.
      wake      a ground enemy (not aircraft) within CQ_magDormantWake m of a point: a Darter takes
                off right there (the point is used up) and joins MAGPIE's fleet (role "dormant"),
                at most CQ_magDormantMax woken Darters alive at once
      get away  it first flies straight away from that enemy until it is more than 80 % of its
                sensor range from it (CQ_magDormantFlee), then connects to the data link and
                spreads around the zone (see "connect, then spread" below)
      replace   a woken Darter destroyed is replaced after CQ_magDormantReplace s by the nearest
                point left to where it went down (same get-away rule, from that spot)
    While in the air a woken Darter relays MAGPIE's data link (CQ_fnc_magTick, CQ_netCoverRelay).
*/
if (!CQ_magDormant || { isNil "CQ_magDormantPts" }) exitWith {};
if (time < (missionNamespace getVariable ["CQ_magDormantNext", 0])) exitWith {};
CQ_magDormantNext = time + 3;

CQ_magSensor params ["_r0", "_rk", "_rmax"];
private _range = (_r0 + CQ_magDormantAlt * _rk) min _rmax;
private _boost = [1, CQ_hstBoost] select (time < (missionNamespace getVariable ["CQ_hstBoostUntil", -1]));   // rescued technician's firmware
_range = _range * _boost;

// forget the lost woken Darters (the replacement is queued in CQ_magDormantDead by CQ_fnc_magTick)
CQ_mag = CQ_mag select { !((_x getOrDefault ["role", ""]) == "dormant" && { _x get "lost" }) };

// known anti-air (a Tigris MAGPIE identified recently, the corridor outpost once spotted): a point
// within CQ_magAaAvoid of it stays asleep, it would only wake to be shot down
private _aaKnown = ((values CQ_magSeen) select { alive (_x select 0) && { time - (_x select 2) < CQ_magMemory } && { (typeOf (_x select 0)) in CQ_magAaClasses } }) apply { _x select 3 };
if (!isNil "CQ_outpostState" && { CQ_outpostState get "spotted" } && { !(CQ_outpostState get "fallen") }) then { _aaKnown pushBack (missionNamespace getVariable ["CQ_opMarkPos", CQ_outpostState get "pos"]) };
private _aaSafe = { params ["_p"]; (_aaKnown findIf { _x distance2D _p < CQ_magAaAvoid }) == -1 };

private _awake = { count (CQ_mag select { (_x getOrDefault ["role", ""]) == "dormant" && { alive (_x get "veh") } }) };

// wake the point _k: a Darter takes off there and gets away from _from (an object or a position)
private _wake = {
    params ["_k", "_from", "_why"];
    private _p = CQ_magDormantPts get _k;
    CQ_magDormantPts deleteAt _k;
    private _fromPos = if (_from isEqualType objNull) then { getPosATL _from } else { _from };
    private _away = _fromPos getDir _p;
    private _nv = createVehicle ["B_UAV_01_F", [_p select 0, _p select 1, 40], [], 0, "FLY"];
    _nv setDir _away;
    _nv setPosATL [_p select 0, _p select 1, 40];
    _nv setVelocityModelSpace [0, 12, 0];
    createVehicleCrew _nv;
    { _nv setPylonLoadout [_forEachIndex + 1, ""] } forEach (getPylonMagazines _nv);
    CQ_magDormantN = CQ_magDormantN + 1;
    private _name = format ["Watcher %1", CQ_magDormantN];
    private _g = group effectiveCommander _nv;
    _g setGroupIdGlobal [_name];
    _g setBehaviour "CARELESS";
    _g setCombatMode "BLUE";
    _nv flyInHeight CQ_magDormantAlt;
    _nv engineOn true;
    _nv setVariable ["CQ_magpie", true, true];
    _nv setVariable ["CQ_magName", _name, true];
    CQ_mag pushBack createHashMapFromArray [
        ["i", 100 + CQ_magDormantN], ["name", _name], ["cls", "B_UAV_01_F"], ["alt", CQ_magDormantAlt], ["scale", 0.8],
        ["veh", _nv], ["due", 1e12], ["phase", "air"], ["tries", 0], ["rollT", time],
        ["planT", time], ["explore", false], ["target", []], ["lost", false],
        ["role", "dormant"], ["flee", true], ["fleeFrom", _from], ["fleePos", _fromPos], ["fleeT", time], ["wpT", -1e6],
        ["wakePos", _p], ["seenT", time], ["sneak", false]
    ];
    CQ_magVehs = (CQ_mag apply { _x get "veh" }) select { alive _x };
    publicVariable "CQ_magVehs";
    ["MAGPIE: %1 wakes at %2 (%3), %4 points left, %5 awake", [_name, mapGridPosition _p, _why, count CQ_magDormantPts, call _awake]] call CQ_fnc_log;
};

// ---- get away first: straight away from the enemy until > 80 % of the sensor range
{
    private _m = _x;
    if (!((_m getOrDefault ["role", ""]) == "dormant") || { !(_m getOrDefault ["flee", false]) }) then { continue };
    private _v = _m get "veh";
    if (!alive _v) then { continue };
    private _f = _m get "fleeFrom";
    if (_f isEqualType objNull && { alive _f }) then { _m set ["fleePos", getPosATL _f] };
    private _fp = _m get "fleePos";
    private _d = _v distance2D _fp;
    if (_d > 0.8 * _range || { time - (_m get "fleeT") > 180 }) then {
        _m set ["flee", false];
        CQ_magWjNext = 0;                                // connect / spread right away
        ["MAGPIE: %1 clear (%2 m from the enemy), connects to the network", [_m get "name", round _d]] call CQ_fnc_log;
        continue;
    };
    if (time - (_m get "wpT") < 8) then { continue };
    _m set ["wpT", time];
    private _dest = _fp getPos [CQ_magDormantFlee * _range + 150, _fp getDir _v];
    private _g = group effectiveCommander _v;
    [_g] call CQ_fnc_clearWaypoints;
    _v flyInHeight CQ_magDormantAlt;
    private _wp = _g addWaypoint [[_dest select 0, _dest select 1, 0], 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointCompletionRadius 50;
    _g setCurrentWaypoint _wp;
    _m set ["target", []];
} forEach CQ_mag;

// ---- sneak back: a woken Darter that has seen nothing for CQ_magSneakIdle s (after getting away)
// slips back, low, to the spot where it woke and circles it quietly; anything in its sight again
// and it rejoins the fleet's flight plans
{
    private _m = _x;
    if ((_m getOrDefault ["role", ""]) != "dormant" || { _m getOrDefault ["flee", false] } || { time < (_m getOrDefault ["lookUntil", 0]) } || { _m getOrDefault ["repair", false] } || { (_m getOrDefault ["wjob", ""]) != "" }) then { continue };
    private _v = _m get "veh";
    if (!alive _v) then { continue };
    private _idle = time - (_m getOrDefault ["seenT", time]);
    if (_m getOrDefault ["sneak", false]) then {
        if (_idle < CQ_magDetectEvery * 2) then {
            _m set ["sneak", false]; _m set ["planT", -1e6];
            ["MAGPIE: %1 has company again near its wake point, back to the fleet", [_m get "name"]] call CQ_fnc_log;
        };
        continue;
    };
    if (_idle < CQ_magSneakIdle) then { continue };
    private _p = _m getOrDefault ["wakePos", getPosATL _v];
    if !([_p] call _aaSafe) then { continue };                   // known anti-air there now: stays with the fleet
    _m set ["sneak", true];
    private _g = group effectiveCommander _v;
    [_g] call CQ_fnc_clearWaypoints;
    _v flyInHeight CQ_magSneakAlt;
    private _wp = _g addWaypoint [[_p select 0, _p select 1, 0], 0];
    _wp setWaypointType "LOITER";
    _wp setWaypointLoiterRadius CQ_magSneakR;
    _wp setWaypointSpeed "LIMITED";
    _g setCurrentWaypoint _wp;
    _m set ["target", []];
    ["MAGPIE: %1 saw nothing for %2 min, sneaks back to its wake point at %3", [_m get "name", round (_idle / 60), mapGridPosition _p]] call CQ_fnc_log;
} forEach CQ_mag;

// ---- connect, then spread (every CQ_magWjEvery s): a woken Darter's first job is to be in the
// data link. The woken Darters are grouped by the zone where they woke (CQ_magWjZone); for each
// zone the nearest linked point of the network (base, relay, vehicle, other drone) is the anchor:
//   chain   slots every CQ_lrHop m from the edge of the anchor's range toward the zone, the last
//           one on the zone's ring; the Darters nearest to them fill them first (from the anchor
//           out: with too few, the chain stays connected and falls short of the zone)
//   spread  the Darters left over take points on a ring of CQ_magWjRing x sensor range around the
//           zone (around the enemies MAGPIE saw there), next to where the chain arrives and then
//           alternately on both sides, never further than CQ_lrHop from the previous one
// LINK REPAIR takes its Darters first (spread ones before chain ones); the fleet's own flight
// plans leave the Darters with a job ("wjob") alone.
if (time >= (missionNamespace getVariable ["CQ_magWjNext", 0])) then {
    CQ_magWjNext = time + CQ_magWjEvery;
    { if (_x getOrDefault ["repair", false]) then { _x set ["wjob", ""] } } forEach CQ_mag;
    private _woke = CQ_mag select { (_x getOrDefault ["role", ""]) == "dormant" && { alive (_x get "veh") } && { !(_x getOrDefault ["flee", false]) } && { !(_x getOrDefault ["repair", false]) } };
    if (_woke isEqualTo []) exitWith {};
    private _wv = _woke apply { _x get "veh" };
    private _anch = ((missionNamespace getVariable ["CQ_linkPub", []]) param [0, []]) select { (_x select 2) && { private _p = _x select 0; (_wv findIf { _x distance2D _p < 40 }) == -1 } };
    if (_anch isEqualTo []) then { _anch = [[CQ_basePos, CQ_netCoverBase, true]] };
    private _zones = [];
    {
        private _m = _x;
        private _wp = _m getOrDefault ["wakePos", getPosATL (_m get "veh")];
        private _zi = _zones findIf { (_x select 0) distance2D _wp < CQ_magWjZone };
        if (_zi < 0) then { _zones pushBack [_wp, [_m]] } else { ((_zones select _zi) select 1) pushBack _m };
    } forEach _woke;
    {
        _x params ["_zc0", "_mem"];
        private _near = (values CQ_magSeen) select { time - (_x select 1) < CQ_magMemory && { (_x select 3) distance2D _zc0 < CQ_magWjZone } };
        private _zc = [_zc0 select 0, _zc0 select 1, 0];
        if (_near isNotEqualTo []) then {
            private _sx = 0; private _sy = 0;
            { _sx = _sx + ((_x select 3) select 0); _sy = _sy + ((_x select 3) select 1) } forEach _near;
            _zc = [_sx / count _near, _sy / count _near, 0];
        };
        private _rr = CQ_magWjRing * _range;
        private _an = ([_anch, [], { ((_x select 0) distance2D _zc) - (_x select 1) }, "ASCEND"] call BIS_fnc_sortBy) select 0;
        private _ap = [(_an select 0) select 0, (_an select 0) select 1, 0];
        private _d0 = (_an select 1) * CQ_linkReach;
        private _dz = _ap distance2D _zc;
        private _dir = _ap getDir _zc;
        // chain slots (none when the anchor's range already reaches the ring)
        private _slots = [];
        if (_dz - _rr > _d0) then {
            private _dEnd = _dz - _rr;
            private _k = ceil ((_dEnd - _d0) / CQ_lrHop) + 1;
            for "_i" from 0 to _k - 1 do { _slots pushBack (_ap getPos [(_d0 + _i * CQ_lrHop) min _dEnd, _dir]) };
        };
        private _n = count _mem;
        private _chainN = (count _slots) min _n;
        _slots resize _chainN;
        // ring points, from where the chain arrives, alternately on both sides
        private _step = (360 / ((_n - _chainN + 1) max 2)) min (2 * asin ((CQ_lrHop / (2 * (_rr max 1))) min 1));
        private _a0 = _zc getDir _ap;
        private _ringPts = [];
        private _j = 1;
        while { count _ringPts < (_n - _chainN) && { _j <= 12 } } do {
            private _side = [1, -1] select ((_j mod 2) == 0);
            private _p = _zc getPos [_rr, _a0 + _side * ceil (_j / 2) * _step];
            if ([_p] call _aaSafe) then { _ringPts pushBack [_p select 0, _p select 1, 0] };
            _j = _j + 1;
        };
        if (_chainN == 0 && { _ringPts isNotEqualTo [] }) then { _ringPts set [0, _zc getPos [_rr, _a0]] };   // first one faces the anchor
        // fill: chain slots first (from the anchor out), then the ring; the nearest free Darter each time
        private _free = +_mem;
        private _jobs = [];
        { if (_free isEqualTo []) exitWith {}; private _sl = _x; private _m = ([_free, [], { (_x get "veh") distance2D _sl }, "ASCEND"] call BIS_fnc_sortBy) select 0; _free = _free - [_m]; _jobs pushBack [_m, "chain", _sl, CQ_lrAlt] } forEach _slots;
        { if (_free isEqualTo []) exitWith {}; private _sl = _x; private _m = ([_free, [], { (_x get "veh") distance2D _sl }, "ASCEND"] call BIS_fnc_sortBy) select 0; _free = _free - [_m]; _jobs pushBack [_m, "spread", _sl, CQ_magDormantAlt] } forEach _ringPts;
        { _jobs pushBack [_x, "spread", _zc getPos [_rr, random 360], CQ_magDormantAlt] } forEach _free;   // anything left (AA everywhere): somewhere on the ring
        private _changed = false;
        {
            _x params ["_m", "_job", "_pt", "_alt"];
            private _old = _m getOrDefault ["wjPos", [0, 0, 0]];
            if ((_m getOrDefault ["wjob", ""]) == _job && { _old distance2D _pt < 120 }) then { continue };
            _changed = true;
            _m set ["wjob", _job]; _m set ["wjPos", _pt]; _m set ["sneak", false]; _m set ["target", _pt];
            private _v = _m get "veh";
            private _g = group effectiveCommander _v;
            [_g] call CQ_fnc_clearWaypoints;
            _v flyInHeight _alt;
            private _wp = _g addWaypoint [[_pt select 0, _pt select 1, 0], 0];
            _wp setWaypointType "LOITER";
            _wp setWaypointLoiterRadius 60;
            _g setCurrentWaypoint _wp;
        } forEach _jobs;
        if (_changed) then {
            ["MAGPIE: woken Darters near %1: %2 chain, %3 spread (anchor %4 m away, %5 hops needed)", [mapGridPosition _zc,
                { (_x select 1) == "chain" } count _jobs, { (_x select 1) == "spread" } count _jobs, round _dz, count _slots]] call CQ_fnc_log;
        };
    } forEach _zones;
};

// ---- replacements: the nearest point left to where a woken Darter went down
private _keep = [];
{
    _x params ["_dp", "_t"];
    if (time - _t < CQ_magDormantReplace || { (call _awake) >= CQ_magDormantMax } || { count CQ_magDormantPts == 0 }) then { _keep pushBack _x; continue };
    private _best = []; private _bd = 1e9;
    { private _d = _y distance2D _dp; if (_d < _bd && { [_y] call _aaSafe }) then { _bd = _d; _best = _x } } forEach CQ_magDormantPts;
    if (_best isEqualTo []) then { _keep pushBack _x; continue };          // every point left is under known anti-air
    [_best, _dp, format ["replaces a Darter lost %1 m away", round _bd]] call _wake;
} forEach CQ_magDormantDead;
CQ_magDormantDead = _keep;

// ---- wake: ground enemies near a point (grid lookup: the 9 cells around)
if ((call _awake) >= CQ_magDormantMax || { count CQ_magDormantPts == 0 }) exitWith {};
private _gap = CQ_magDormantGap;
{
    if !(side _x in [east, resistance]) then { continue };
    private _o = vehicle leader _x;
    if (!alive _o || { _o isKindOf "Air" } || { _o isKindOf "Ship" } || { _o isKindOf "StaticWeapon" }) then { continue };
    if ((leader _x) getVariable ["CQ_outpost", false]) then { continue };      // the corridor outpost's jammer keeps the sleepers asleep
    private _pos = getPosATL _o;
    if ((_pos select 2) > 5 || { surfaceIsWater _pos }) then { continue };     // still under a parachute, or at sea
    private _ci = floor ((_pos select 0) / _gap);
    private _cj = floor ((_pos select 1) / _gap);
    private _hit = [];
    for "_di" from -1 to 1 do {
        for "_dj" from -1 to 1 do {
            private _k = [_ci + _di, _cj + _dj];
            private _p = CQ_magDormantPts getOrDefault [_k, []];
            if (_p isNotEqualTo [] && { _p distance2D _pos < CQ_magDormantWake * _boost } && { [_p] call _aaSafe }) exitWith { _hit = _k };
        };
        if (_hit isNotEqualTo []) exitWith {};
    };
    if (_hit isEqualTo []) then { continue };
    [_hit, _o, format ["%1 within %2 m", typeOf _o, round ((CQ_magDormantPts get _hit) distance2D _pos)]] call _wake;
    if ((call _awake) >= CQ_magDormantMax) then { break };
} forEach allGroups;
