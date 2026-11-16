/*
    CQ_fnc_magDormant  (server, director task, every 3 s)
    MAGPIE's dormant Darters (allaroundisland). Points every CQ_magDormantGap m on land
    (CQ_magDormantPts, built by CQ_fnc_magInit) are Darters grounded all over the island:
    coordinates only, no objects.
      wake      a ground enemy (not aircraft) within CQ_magDormantWake m of a point: a Darter takes
                off right there (the point is used up) and joins MAGPIE's fleet (role "dormant"),
                at most CQ_magDormantMax woken Darters alive at once
      get away  it first flies straight away from that enemy until it is more than 80 % of its
                sensor range from it (CQ_magDormantFlee), then hangs from the data link in a
                stretched tree toward its zone (see "stretched tree" below)
      replace   a woken Darter destroyed is replaced after CQ_magDormantReplace s by the nearest
                point left to where it went down (same get-away rule, from that spot)
    While in the air a woken Darter relays MAGPIE's data link (CQ_fnc_magTick, CQ_netCoverRelay).
*/
if (!CQ_magDormant || { isNil "CQ_magDormantPts" }) exitWith {};
// grid Darters (woken, role "dormant") cruise at CQ_gridDarterSpeed km/h toward their waypoint
// (vanilla tops out around 80): horizontal velocity set every 0.2 s while more than 250 m from it
// and above 40 m; WASP and the other drones fly at their own speed
if (CQ_gridDarterSpeed > 0 && { isNil "CQ_gridSpeedLoop" }) then {
    CQ_gridSpeedLoop = [] spawn {
        private _vmax = CQ_gridDarterSpeed / 3.6;
        while { true } do {
            {
                if ((_x getOrDefault ["role", ""]) != "dormant") then { continue };
                private _v = _x get "veh";
                if (!alive _v || { ((getPosATL _v) select 2) < 40 }) then { continue };
                private _g = group effectiveCommander _v;
                if (isNull _g) then { continue };
                private _wp = waypointPosition [_g, currentWaypoint _g];
                if (_wp isEqualTo [0, 0, 0] || { _v distance2D _wp < 250 }) then { continue };
                private _h = vectorNormalized [(_wp select 0) - ((getPosASL _v) select 0), (_wp select 1) - ((getPosASL _v) select 1), 0];
                _v setVelocity [(_h select 0) * _vmax, (_h select 1) * _vmax, (velocity _v) select 2];
            } forEach (missionNamespace getVariable ["CQ_mag", []]);
            sleep 0.2;
        };
    };
};
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

// ---- debug "Full tentacle" (CQ_fnc_debugCmd magTentacle): the CQ_tntTestN sleeping points nearest
// the outpost (outside CQ_magAaAvoid of it) wake at once, past CQ_magDormantMax, already clear and
// connected; the tentacle's only memory is the outpost (kept CQ_tntTestPin s), WASP replans now, and
// the Darters are put straight on their slots for the next 20 s (chain, then the ring)
if (!isNil "CQ_tntTestReq") then {
    CQ_tntTestReq = nil;
    private _op = CQ_outpostState get "pos";
    private _ks = (keys CQ_magDormantPts) select { (CQ_magDormantPts get _x) distance2D _op > CQ_magAaAvoid };
    _ks = [_ks, [], { (CQ_magDormantPts get _x) distance2D _op }, "ASCEND"] call BIS_fnc_sortBy;
    _ks = _ks select [0, CQ_tntTestN];
    private _names = [];
    {
        [_x, _op, "debug full tentacle"] call _wake;
        private _m = CQ_mag select (count CQ_mag - 1);
        _m set ["flee", false];
        _names pushBack (_m get "name");
    } forEach _ks;
    CQ_tntMem = createHashMapFromArray [["TEST outpost", [_op, time]]];
    CQ_tntShared = (missionNamespace getVariable ["CQ_tntShared", []]) + _names;   // no wake-point memory of their own
    CQ_tntUnits = [];
    CQ_tntKey = [];
    CQ_tntRoot = [];
    CQ_tntTestUntil = time + CQ_tntTestPin;
    CQ_tntTeleportUntil = time + 20;
    { if ((_x getOrDefault ["role", ""]) == "wasp") then { _x set ["planT", -1e6] } } forEach CQ_mag;
    CQ_magNext = 0;
    ["MAGPIE: debug full tentacle toward the outpost at %1: %2 Darters woken (%3)", [mapGridPosition _op, count _names, _names joinString ", "]] call CQ_fnc_log;
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

// ---- TENTACLE (every 3 s, recomputed only when something changed): the woken Darters reach out
// from the data link toward the fight, then encircle it.
//   memory     starts with the wake points: a woken Darter connecting for the first time sends where it
//              woke (CQ_tntMem: [pos, lastT]). Then at every report check (2 min, CQ_fnc_magTick) it
//              holds the ground contacts MAGPIE saw in the last CQ_magMemory s (CQ_tntUnits, aircraft
//              excluded), at their live position while seen; a wake point is dropped once such a
//              contact lies within CQ_magWjZone of it (else it goes after CQ_magMemory s with nothing around)
//   zones      memories within CQ_magWjZone of each other; the tentacle serves a zone with live
//              enemies first (seen in the last CQ_magMemory s), the nearest to the network within each
//              kind; an empty zone is forgotten CQ_tntEmptyDrop s after a Darter of ours reached it
//   perimeter  smallest circle around the zone's memories and live contacts + CQ_tntStandoff x
//              sensor range (centre = their centroid)
//   chain      root = the linked node nearest to the zone (base, relays, relay vehicle, Sentinels, and
//              WASP once it bridges toward the zone: CQ_fnc_magTick turns it there after a first memory), first hop CQ_linkReach x its range, then CQ_lrHop each: straight
//              toward the zone's centroid, the tip stopping on the perimeter; a link slot within
//              CQ_tntAaR of known anti-air is pushed sideways. Too few Darters: the chain stops short.
//   ring       once the tip Darter is on its slot and 2+ Darters are spare: they fan out left and
//              right from the tip along the perimeter, CQ_lrHop apart (1 spare waits behind the tip)
//   stability  a Darter keeps its slot index; the layout is recomputed only when the centroid moves
//              more than CQ_tntMove m, the zone, the root or the set of Darters changes, or the ring opens.
//              Transit at full speed (MOVE), then a 60 m loiter on the slot.
// Published for the debug map (CQ_tntPub = [[root, chain slots...], [ring slots], [centre, radius]]).
call {
    private _woke = CQ_mag select { (_x getOrDefault ["role", ""]) == "dormant" && { alive (_x get "veh") } && { !(_x getOrDefault ["flee", false]) } && { !(_x getOrDefault ["repair", false]) } };
    if (isNil "CQ_tntMem") then { CQ_tntMem = createHashMap };       // Darter name -> [wake pos, lastT]
    if (isNil "CQ_tntShared") then { CQ_tntShared = [] };            // Darters that already shared (once each)
    // a grid Darter connecting for the first time sends its memory (where it woke)
    {
        private _m = _x;
        private _nm = _m get "name";
        if (_nm in CQ_tntShared || { !((_m get "veh") getVariable ["CQ_linked", false]) }) then { continue };
        CQ_tntShared pushBack _nm;
        private _wp = _m getOrDefault ["wakePos", getPosATL (_m get "veh")];
        CQ_tntMem set [_nm, [_wp, time]];
        ["MAGPIE: %1 connected, sends its memory (woke at %2)", [_nm, mapGridPosition _wp]] call CQ_fnc_log;
        ["memory", format ["%1 sends its memory (woke at %2)", _nm, mapGridPosition _wp]] call CQ_fnc_netEvent;
    } forEach _woke;
    // only HQ zones count: memories and contacts within CQ_magAoRange of an enemy HQ we know (MAGPIE
    // saw it, or a captured commander revealed it); sabotage teams never count. So the side events
    // and the sabotage routes do not pull the tentacle (the debug "Full tentacle" test is exempt)
    private _tst = time < (missionNamespace getVariable ["CQ_tntTestUntil", -1]);
    private _hqK = ((values CQ_hqs) select { (_x get "state") in CQ_activeStates && { (_x get "id") in (missionNamespace getVariable ["CQ_magHqSeen", createHashMap]) || { _x getOrDefault ["revealed", false] } } }) apply { _x get "pos" };
    private _inHq = { params ["_p"]; _tst || { (_hqK findIf { _x distance2D _p < CQ_magAoRange }) > -1 } };
    // keep alive the memories MAGPIE still sees enemies around, forget the others
    private _live = (((values CQ_magSeen) select { alive (_x select 0) && { time - (_x select 2) < CQ_magMemory } && { !((_x select 0) getVariable ["CQ_sabotage", false]) } }) apply { _x select 3 }) select { [_x] call _inHq };
    {
        _y params ["_mp", "_mt"];
        if ((_live findIf { _x distance2D _mp < CQ_magWjZone }) > -1) then { _y set [1, time] };
    } forEach CQ_tntMem;
    if (time < (missionNamespace getVariable ["CQ_tntTestUntil", -1]) && { "TEST outpost" in CQ_tntMem }) then { (CQ_tntMem get "TEST outpost") set [1, time] };   // debug: pinned
    { if (time - ((CQ_tntMem get _x) select 1) > CQ_magMemory) then { CQ_tntMem deleteAt _x } } forEach (keys CQ_tntMem);
    // memory points: the wake points still kept + the ground contacts of the last report check
    // (CQ_tntUnits, CQ_fnc_magTick), each at its live position while seen, else where last seen
    CQ_tntUnits = (missionNamespace getVariable ["CQ_tntUnits", []]) select { alive _x && { !(_x getVariable ["CQ_sabotage", false]) } };
    private _memPts = (((values CQ_tntMem) apply { _x select 0 }) + (CQ_tntUnits apply {
        private _rec = CQ_magSeen getOrDefault [hashValue _x, []];
        if (_rec isEqualTo []) then { getPosATL _x } else { _rec select 3 }
    })) select { [_x] call _inHq };
    if (_woke isEqualTo [] || { _memPts isEqualTo [] }) exitWith {
        if (!isNil "CQ_tntPub" && { CQ_tntPub isNotEqualTo [] }) then { CQ_tntPub = []; publicVariable "CQ_tntPub" };
        CQ_tntZoneC = [];
        CQ_tntRoot = [];
        { _x set ["wjob", ""]; _x set ["tntI", -1] } forEach _woke;
        CQ_tntKey = [];
    };
    // zones of memories
    private _zones = [];                                     // [[centroid of memories, [points]], ...]
    {
        private _p = _x;
        private _zi = _zones findIf { ((_x select 1) findIf { _x distance2D _p < CQ_magWjZone }) > -1 };
        if (_zi < 0) then { _zones pushBack [[], [_p]] } else { ((_zones select _zi) select 1) pushBack _p };
    } forEach _memPts;
    // anchors: every linked node that is not a woken Darter
    // ...and not WASP while it faces the carrier
    // WASP only while it bridges toward the zone (CQ_waspBridge): then it is the natural root
    private _wv = (_woke apply { _x get "veh" }) + ([(CQ_mag select { (_x getOrDefault ["role", ""]) == "wasp" }) apply { _x get "veh" }, []] select (missionNamespace getVariable ["CQ_waspBridge", false]));
    private _anch = (((missionNamespace getVariable ["CQ_linkPub", []]) param [0, []]) select { (_x select 2) && { private _p = _x select 0; (_wv findIf { _x distance2D _p < 60 }) == -1 } }) apply { [[(_x select 0) select 0, (_x select 0) select 1, 0], _x select 1] };
    if (_anch isEqualTo []) then { _anch = [[[CQ_basePos select 0, CQ_basePos select 1, 0], CQ_netCoverBase]] };
    // each zone: centroid of its memories, perimeter around memories + live contacts, distance to the network
    {
        private _pts = _x select 1;
        private _sx = 0; private _sy = 0;
        { _sx = _sx + (_x select 0); _sy = _sy + (_x select 1) } forEach _pts;
        private _cm = [_sx / count _pts, _sy / count _pts, 0];
        private _all = _pts + (_live select { _x distance2D _cm < CQ_magWjZone * 1.5 });
        _sx = 0; _sy = 0;
        { _sx = _sx + (_x select 0); _sy = _sy + (_x select 1) } forEach _all;
        private _cc = [_sx / count _all, _sy / count _all, 0];
        private _rad = 0;
        { _rad = _rad max (_x distance2D _cc) } forEach _all;
        _rad = _rad + CQ_tntStandoff * _range;
        private _dn = 1e9;
        { _dn = _dn min (((_x select 0) distance2D _cc) - _rad) } forEach _anch;
        _x set [0, [_cm, _cc, _rad, _dn]];
    } forEach _zones;
    // zone choice: a zone with live enemies (seen in the last CQ_magMemory s) beats an empty one,
    // the nearest to the network first within each kind
    {
        private _zi = _x select 0;
        private _zc = _zi select 1;
        private _zr = _zi select 2;
        _zi pushBack ({ _x distance2D _zc < _zr } count _live);
    } forEach _zones;
    _zones = [_zones, [], { ((_x select 0) select 3) + ([1e7, 0] select (((_x select 0) select 4) > 0)) }] call BIS_fnc_sortBy;
    ((_zones select 0) select 0) params ["_cm", "_cc", "_rad", "_dn0", "_zn"];
    // empty zone: once a Darter of ours is on its perimeter and no live enemy has been seen there for
    // CQ_tntEmptyDrop s, the zone is forgotten (its wake points and the contacts no longer seen there)
    private _onSite = (_woke findIf { ((_x get "veh") distance2D _cc) < _rad + 100 }) > -1;
    private _et = missionNamespace getVariable ["CQ_tntEmpty", []];
    if (_zn == 0 && { _onSite }) then {
        if (_et isEqualTo [] || { ((_et select 0) distance2D _cc) > CQ_magWjZone }) then { CQ_tntEmpty = [_cc, time]; _et = CQ_tntEmpty };
        if (time - (_et select 1) >= CQ_tntEmptyDrop) then {
            CQ_tntEmpty = [];
            private _zp = (_zones select 0) select 1;
            private _nw = 0;
            { if (((CQ_tntMem get _x) select 0) in _zp) then { CQ_tntMem deleteAt _x; _nw = _nw + 1 } } forEach (keys CQ_tntMem);
            private _nu = count CQ_tntUnits;
            CQ_tntUnits = CQ_tntUnits select {
                private _rec = CQ_magSeen getOrDefault [hashValue _x, []];
                ((if (_rec isEqualTo []) then { getPosATL _x } else { _rec select 3 }) distance2D _cc) >= _rad
            };
            ["MAGPIE: tentacle zone at %1 empty for %2 s, forgotten (%3 wake point(s), %4 contact(s))", [mapGridPosition _cc, CQ_tntEmptyDrop, _nw, _nu - count CQ_tntUnits]] call CQ_fnc_log;
        };
    } else { CQ_tntEmpty = [] };
    CQ_tntZoneC = _cc;                                    // WASP bridges toward it (CQ_fnc_magTick)
    // root: the linked node nearest to the zone
    private _root = []; private _rr0 = 0; private _bd = 1e12;
    { private _d = (_x select 0) distance2D _cc; if (_d < _bd) then { _bd = _d; _root = _x select 0; _rr0 = _x select 1 } } forEach _anch;
    // ...but the previous root is kept while it is still a linked node, unless the new one is
    // CQ_tntRootBetter m closer to the zone (moving drones made the root flip every few seconds)
    private _pr = missionNamespace getVariable ["CQ_tntRoot", []];
    if (_pr isNotEqualTo []) then {
        private _ai = _anch findIf { (_x select 0) distance2D (_pr select 0) < 300 };
        // brackets: "-" binds tighter than distance2D
        if (_ai > -1 && { ((((_anch select _ai) select 0) distance2D _cc) - _bd) < CQ_tntRootBetter }) then {
            _root = (_anch select _ai) select 0; _rr0 = (_anch select _ai) select 1;
        };
    };
    CQ_tntRoot = [_root, _rr0];
    // arrived on its slot: loiter quietly (the tip's arrival opens the ring)
    {
        private _m = _x;
        if ((_m getOrDefault ["wjob", ""]) != "tree" || { _m getOrDefault ["tntArr", true] }) then { continue };
        private _v = _m get "veh";
        private _pt = _m getOrDefault ["wjPos", getPosATL _v];
        if (_v distance2D _pt > CQ_tntArrive) then { continue };
        _m set ["tntArr", true];
        private _g = group effectiveCommander _v;
        [_g] call CQ_fnc_clearWaypoints;
        _g setSpeedMode "LIMITED";
        private _wp = _g addWaypoint [[_pt select 0, _pt select 1, 0], 0];
        _wp setWaypointType "LOITER";
        _wp setWaypointLoiterRadius 60;
        _g setCurrentWaypoint _wp;
    } forEach _woke;
    // recompute only when something changed
    private _ids = (_woke apply { _x get "name" }); _ids sort true;
    private _old = missionNamespace getVariable ["CQ_tntKey", []];
    _old params [["_oCm", [0, 0, 0]], ["_oIds", []], ["_oRoot", [0, 0, 0]], ["_oRing", false]];
    private _tipM = _woke select { (_x getOrDefault ["tntI", -1]) == (missionNamespace getVariable ["CQ_tntTipI", -99]) };
    if (_cm distance2D _oCm > CQ_magWjZone) then { _oRing = false };   // another zone: the chain reaches out again before any ring
    private _ringNow = _oRing || { _tipM isNotEqualTo [] && { ((_tipM select 0) get "veh") distance2D ((_tipM select 0) getOrDefault ["wjPos", [0, 0, 0]]) < CQ_tntArrive } };
    if (_cm distance2D _oCm < CQ_tntMove && { _ids isEqualTo _oIds } && { _root distance2D _oRoot < CQ_tntMove } && { _ringNow isEqualTo _oRing }) exitWith {};
    CQ_tntKey = [_cm, _ids, _root, _ringNow];
    // the chain: straight from the root toward the centroid, the tip on the perimeter
    private _dir = _root getDir _cc;
    private _tip = if (_root distance2D _cc > _rad) then { _cc getPos [_rad, _cc getDir _root] } else { _root };
    private _len = _root distance2D _tip;
    private _first = CQ_linkReach * (_rr0 max CQ_linkDroneR);
    private _need = if (_len <= _first) then { 1 } else { 1 + ceil ((_len - _first) / CQ_lrHop) };
    private _n = count _woke;
    private _nChain = _need min _n;
    private _aaClear = { params ["_p", "_r"]; (_aaKnown findIf { _x distance2D _p < _r }) == -1 };
    private _aaFix = {
        params ["_p", "_dirC"];
        if ([_p, CQ_tntAaR] call _aaClear) exitWith { _p };
        private _out = _p;
        { private _c = _p getPos [_x, _dirC + 90]; if ([_c, CQ_tntAaR] call _aaClear) exitWith { _out = _c }; _c = _p getPos [_x, _dirC - 90]; if ([_c, CQ_tntAaR] call _aaClear) exitWith { _out = _c } } forEach [200, 400, 600, 800, 1000, 1200];
        _out
    };
    private _chain = [];
    for "_i" from 1 to _nChain do {
        private _d = (_first + (_i - 1) * CQ_lrHop) min _len;
        private _p = _root getPos [_d, _dir];
        _chain pushBack ([[_p select 0, _p select 1, 0], _dir] call _aaFix);
    };
    // ring (or reserve behind the tip)
    private _spare = _n - _nChain;
    private _ring = [];
    if (_spare > 0) then {
        if (_ringNow && { _spare >= 2 } && { _nChain >= _need }) then {
            private _step = 2 * asin ((CQ_lrHop / (2 * _rad)) min 1);
            private _a0 = _cc getDir _tip;
            for "_k" from 1 to _spare do {
                private _side = [1, -1] select (_k mod 2 == 0);
                private _a = _a0 + _side * _step * ceil (_k / 2);
                private _p = _cc getPos [_rad, _a];
                if !([_p, CQ_tntAaR] call _aaClear) then { continue };
                _ring pushBack [_p select 0, _p select 1, 0];
            };
        };
        while { count _ring < _spare } do {
            private _t = if (_chain isEqualTo []) then { _root } else { _chain select (count _chain - 1) };
            private _p = _t getPos [150 + 100 * (count _ring), _dir + 180];
            _ring pushBack [_p select 0, _p select 1, 0];
        };
    };
    private _slots = _chain + _ring;
    CQ_tntTipI = count _chain - 1;
    // assignment: a Darter keeps its slot index when it is still valid, the others take the free
    // slots nearest to them
    private _taken = [];
    private _free = [];
    { private _i = _x getOrDefault ["tntI", -1]; if (_i > -1 && { _i < count _slots } && { !(_i in _taken) }) then { _taken pushBack _i } else { _x set ["tntI", -1]; _free pushBack _x } } forEach _woke;
    for "_si" from 0 to (count _slots - 1) do {
        if (_si in _taken) then { continue };
        if (_free isEqualTo []) exitWith {};
        private _sp = _slots select _si;
        private _m = ([_free, [], { (_x get "veh") distance2D _sp }, "ASCEND"] call BIS_fnc_sortBy) select 0;
        _free = _free - [_m];
        _m set ["tntI", _si];
    };
    // orders: transit at full speed, loiter on arrival
    private _moved = 0;
    {
        private _m = _x;
        private _i = _m getOrDefault ["tntI", -1];
        if (_i < 0) then { continue };
        private _pt = _slots select _i;
        if ((_m getOrDefault ["wjob", ""]) == "tree" && { (_m getOrDefault ["wjPos", [0, 0, 0]]) distance2D _pt < 100 }) then { continue };
        _moved = _moved + 1;
        _m set ["wjob", "tree"]; _m set ["wjPos", _pt]; _m set ["sneak", false]; _m set ["target", _pt]; _m set ["tntArr", false];
        private _v = _m get "veh";
        private _g = group effectiveCommander _v;
        [_g] call CQ_fnc_clearWaypoints;
        _v flyInHeight CQ_magDormantAlt;
        _g setSpeedMode "FULL";
        private _wp = _g addWaypoint [[_pt select 0, _pt select 1, 0], 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "FULL";
        _wp setWaypointCompletionRadius 80;
        _g setCurrentWaypoint _wp;
    } forEach _woke;
    // debug "Full tentacle": straight onto the slots (the tip on its slot opens the ring next tick)
    if (time < (missionNamespace getVariable ["CQ_tntTeleportUntil", -1])) then {
        {
            private _i = _x getOrDefault ["tntI", -1];
            if (_i < 0) then { continue };
            private _pt = _slots select _i;
            private _v = _x get "veh";
            _v setPosATL [_pt select 0, _pt select 1, CQ_magDormantAlt];
            _v setVelocityModelSpace [0, 15, 0];
        } forEach _woke;
        CQ_magDormantNext = time + 1;                // check the tip's arrival right away
    };
    CQ_tntPub = [[_root] + _chain, _ring select [0, [0, count _ring] select (_ringNow && { _spare >= 2 })], [_cc, _rad]];
    publicVariable "CQ_tntPub";
    ["MAGPIE: tentacle to the zone at %1 (%2 zone(s)): %3/%4 chain Darters, %5 %6, %7 re-tasked", [mapGridPosition _cc, count _zones, _nChain, _need, _spare, ["in reserve", "on the ring"] select (_ringNow && { _spare >= 2 }), _moved]] call CQ_fnc_log;
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
