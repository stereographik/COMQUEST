/*
    CQ_fnc_hqBuild  (server, spawned by CQ_fnc_hqTick when the perimeter is secured)
    [_hq] spawn CQ_fnc_hqBuild;
    Builds the HQ composition in 6 stages, announcing each. Each stage goes up when the build truck
    (CQ_fnc_buildTruck) has driven to its site (see _truckWait).
    Offsets are [right, forward] metres in the HQ's own frame (rotated by its "dir").
      1 3 AA pits   2 HMG watchtower   3 radio tower (they can communicate)
      4 supply depot + field supply truck   5 fuel tanker
      6 command post (Django's HQ model) + helipad with the parked QRF helicopter
    Every stage puts up its Eden model around the key object (CQ_fnc_compoPlace, cfg\compositions.sqf)
    and registers its guard posts (CQ_fnc_guardSite, manned by CQ_fnc_guardTick while a player is near).
    The 7 objectives (depot, radio tower, fuel tanker, 3 AA pits, HMG tower) each stand on their
    own site anywhere CQ_objMinR..CQ_objMaxR m from the command building, at least CQ_objMinGap m
    apart, on flat open ground (no trees, rocks or buildings) so players can reach them (the HMG
    tower takes the site closest to CQ_hmgTowerDir).
    CQ_fnc_hqGarrison puts a small guard team on each site.
    At the end the squads are recalled to garrison the HQ and "buildDone" is set.
*/
params ["_hq"];

private _c = _hq get "pos";
private _d = _hq get "dir";
private _id = _hq get "id";

private _at = {
    params ["_ox", "_oy"];
    _c getPos [sqrt (_ox ^ 2 + _oy ^ 2), _d + (_ox atan2 _oy)]
};
// Places one object with a spacing check against the environment AND the pieces already placed.
// Blocked -> shifted up to 6 m. Still blocked -> minor piece skipped; essential piece hides the
// terrain blockers under its footprint. Enemy soldiers standing there are pushed out first.
private _placeAt = {
    params ["_cls", "_want", ["_rot", 0], ["_essential", false]];
    _want = [_want select 0, _want select 1, 0];
    private _r = (CQ_objRadius getOrDefault [_cls, 2]) + CQ_objectClearance;
    private _p = [_want, _r, 6] call CQ_fnc_clearPos;

    if (_p isEqualTo []) then {
        if (_essential) then {
            { _x hideObjectGlobal true } forEach (nearestTerrainObjects [_want, CQ_blockerTypes, _r, false, true]);
            ["HQ #%1: %2 blocked at %3, cleared terrain under it", [_id, _cls, mapGridPosition _want]] call CQ_fnc_log;
            _p = _want;
        } else {
            ["HQ #%1: %2 skipped, no clear spot near %3", [_id, _cls, mapGridPosition _want]] call CQ_fnc_log;
        };
    } else {
        if (_p isNotEqualTo _want) then {
            ["HQ #%1: %2 shifted %3 m for spacing", [_id, _cls, round (_p distance2D _want)]] call CQ_fnc_log;
        };
    };
    if (_p isEqualTo []) exitWith { objNull };

    // Push enemy soldiers out of the footprint so nothing spawns inside them
    {
        _x setPosATL (_p getPos [_r + 4, _p getDir _x]);
    } forEach ((_p nearEntities [["CAManBase"], _r + 2]) select { side group _x == east });

    private _o = createVehicle [_cls, _p, [], 0, "CAN_COLLIDE"];
    _o setDir (_d + _rot);
    (_hq get "objects") pushBack _o;
    _o
};
private _place = {
    params ["_cls", "_ox", "_oy", ["_rot", 0], ["_essential", false]];
    [_cls, [_ox, _oy] call _at, _rot, _essential] call _placeAt
};
// Objective sites: 7 spots anywhere in the HQ's area, between CQ_objMinR and CQ_objMaxR m from the
// command building, every one at least CQ_objMinGap m from the others. Each spot must be usable
// by players: dry, flat (CQ_objMaxSlope over its footprint), and no tree, bush, rock, building,
// wall or placed object within CQ_objClearR m. Random picks over the whole area; if 7 never fit,
// the gap is relaxed step by step (logged). The HMG tower takes the spot closest to CQ_hmgTowerDir.
private _sitesFor = {
    private _okSpot = {
        params ["_p"];
        !surfaceIsWater _p
        && { (_p isFlatEmpty [-1, -1, CQ_objMaxSlope, CQ_objClearR, 0, false, objNull]) isNotEqualTo [] }
        && { [_p, CQ_objClearR] call CQ_fnc_isClear }
    };
    // spots that pass the terrain test, spread uniformly over the area
    private _pool = [];
    for "_i" from 1 to 500 do {
        private _r = sqrt ((CQ_objMinR ^ 2) + random ((CQ_objMaxR ^ 2) - (CQ_objMinR ^ 2)));
        private _p = _c getPos [_r, random 360];
        _p = [_p select 0, _p select 1, 0];
        if ([_p] call _okSpot) then { _pool pushBack _p };
        if (count _pool >= 120) exitWith {};
    };
    private _gap = CQ_objMinGap;
    private _best = [];
    while { count _best < 7 && { _gap >= 60 } } do {
        for "_try" from 1 to 25 do {
            private _pts = [];
            {
                private _p = _x;
                if ((_pts findIf { _x distance2D _p < _gap }) == -1) then { _pts pushBack _p };
                if (count _pts >= 7) exitWith {};
            } forEach (_pool call BIS_fnc_arrayShuffle);
            if (count _pts > count _best) then { _best = _pts };
            if (count _best >= 7) exitWith {};
        };
        if (count _best < 7) then { _gap = _gap * 0.8 };
    };
    ["HQ #%1: %2 clear objective spots found in the area, %3 placed %4 m apart", [_id, count _pool, count _best, round _gap]] call CQ_fnc_log;
    if (count _best < 7) exitWith {
        ["HQ #%1: no room for spread objectives, built around the command building", [_id]] call CQ_fnc_log;
        [[-24, 0], [0, 26], [18, -18], [-20, 22], [20, 22], [0, -26], [CQ_hmgTowerDist * sin (CQ_hmgTowerDir - _d), CQ_hmgTowerDist * cos (CQ_hmgTowerDir - _d)]] apply { _x call _at }
    };
    // HMG tower on the site closest to CQ_hmgTowerDir, last in the list
    private _hi = 0; private _hd = 1e6;
    { private _dd = abs (((_c getDir _x) - CQ_hmgTowerDir + 540) % 360 - 180); if (_dd < _hd) then { _hd = _dd; _hi = _forEachIndex } } forEach _best;
    private _hmgSite = _best deleteAt _hi;
    _best pushBack _hmgSite;
    _best
};
// Radio and depot only take damage from engineer demolition charges
private _engineerOnly = {
    params ["_obj"];
    _obj addEventHandler ["HandleDamage", {
        params ["_o", "", "_dmg", "_src", "_ammo", "", "_inst"];
        private _who = [_inst, _src] select (isNull _inst);
        // a player is an engineer by the class he took at the base (all slots are riflemen)
        private _eng = typeOf _who in CQ_engineerClasses || { (_who getVariable ["CQ_class", ""]) == "Engineer" };
        if (_ammo in CQ_engineerCharges && { _eng }) then { _dmg } else { damage _o };
    }];
};
// Stage wait: the build truck (CQ_fnc_buildTruck) drives to the stage's site; the stage goes up
// once it stopped within CQ_btStopDist, its squad got out and CQ_btSpawnDelay s passed. No truck
// (destroyed, not landed yet): the build is frozen until the carrier's replacement arrives.
// Safety: no progress for CQ_btStuck s -> new route, then a short hop onto free ground; a leg
// longer than CQ_btLegMax s -> the truck is put at the stop. The debug panel skips the drive.
private _truckWait = {
    params ["_dest", ["_stopD", CQ_btStopDist]];
    private _legT = -1; private _lastP = [0, 0, 0]; private _moveT = time; private _stuckN = 0;
    private _tr = objNull; private _frozen = false; private _frozenT = time;
    private _stop = {
        params ["_tr"];
        private _p = (_dest getPos [_stopD - 4, _dest getDir _tr]) findEmptyPosition [0, 40, typeOf _tr];
        if (_p isEqualTo []) then { _p = _dest getPos [_stopD - 4, _dest getDir _tr] };
        _tr setVelocity [0, 0, 0];
        _tr setPosATL [_p select 0, _p select 1, 0.3];
    };
    waitUntil {
        sleep 1;
        _tr = _hq getOrDefault ["buildTruck", objNull];
        if (_hq get "skipStage") exitWith { if (alive _tr) then { [_tr] call _stop }; true };
        if (!alive _tr || { !canMove _tr } || { !alive driver _tr }) exitWith {
            if (!_frozen) then { _frozen = true; _frozenT = time; ["HQ #%1: construction frozen, no build truck", [_id]] call CQ_fnc_log };
            _hq set ["btPhase", ["frozen: no truck", "frozen: truck coming"] select ((_hq getOrDefault ["btPending", false]) || { _hq getOrDefault ["btIncoming", false] })];
            // 60 s grace: the root's Zamak may still be under its parachute
            if (!alive _tr && { time - _frozenT > 60 } && { !(_hq getOrDefault ["btIncoming", false]) } && { !(_hq getOrDefault ["btPending", false]) } && { !(_hq getOrDefault ["btNone", false]) }) then {
                ["request", [_hq]] spawn CQ_fnc_buildTruck;
            };
            if (alive _tr && { !alive driver _tr || { !canMove _tr } }) then { _tr setDamage 1 };   // crippled: counts as lost
            _legT = -1;
            // the carrier has no build truck left: the build goes on the old way, one stage
            // every CQ_btFallbackTime s (the men carry it in)
            if (_hq getOrDefault ["btNone", false] && { time - _frozenT > CQ_btFallbackTime }) exitWith {
                ["HQ #%1: no build truck left, stage built without one", [_id]] call CQ_fnc_log;
                _frozenT = time;
                true
            };
            false
        };
        _frozen = false;
        if (_legT < 0) then {
            ["board", [_hq]] call CQ_fnc_buildTruck;
            private _dg = group driver _tr;
            [_dg] call CQ_fnc_clearWaypoints;
            _dg setBehaviour "SAFE"; _dg setSpeedMode "NORMAL"; _dg setFormation "COLUMN";
            _dg move _dest;
            _legT = time; _moveT = time; _lastP = getPosATL _tr; _stuckN = 0;
            _hq set ["btPhase", format ["to site %1/6", (_hq getOrDefault ["buildStage", 0]) + 1]];
        };
        if (_tr distance2D _dest <= _stopD) exitWith { true };
        if (_tr distance2D _lastP > 5) then { _lastP = getPosATL _tr; _moveT = time };
        if (time - _moveT > CQ_btStuck) then {
            if (_stuckN == 0) then {
                ["HQ #%1: build truck stuck at grid %2, new route", [_id, mapGridPosition _tr]] call CQ_fnc_log;
                (group driver _tr) move _dest;
            } else {
                private _p = ((_tr getPos [25, _tr getDir _dest]) findEmptyPosition [0, 40, typeOf _tr]);
                if (_p isNotEqualTo []) then { _tr setVelocity [0, 0, 0]; _tr setPosATL [_p select 0, _p select 1, 0.3] };
                (group driver _tr) move _dest;
                ["HQ #%1: build truck still stuck, moved onto free ground at grid %2", [_id, mapGridPosition _tr]] call CQ_fnc_log;
            };
            _stuckN = _stuckN + 1; _moveT = time; _lastP = getPosATL _tr;
            _hq set ["btPhase", format ["stuck x%1", _stuckN]];
        };
        if (time - _legT > CQ_btLegMax) exitWith {
            ["HQ #%1: build truck leg over %2 s, put at its stop", [_id, CQ_btLegMax]] call CQ_fnc_log;
            [_tr] call _stop;
            true
        };
        false
    };
    private _skip = _hq get "skipStage";
    _hq set ["skipStage", false];
    if (alive _tr) then {
        private _dg = group driver _tr;
        [_dg] call CQ_fnc_clearWaypoints;
        _dg move (getPosATL _tr);                        // stop here (a later move order still works)
        private _sg = _hq getOrDefault ["btSquad", grpNull];
        if (!isNull _sg) then {
            _sg leaveVehicle _tr;                         // they climb out and stand guard
            _sg setBehaviour "AWARE";
        };
        ["HQ #%1: build truck at its stop (%2 m from the site)", [_id, round (_tr distance2D _dest)]] call CQ_fnc_log;
        _hq set ["btPhase", format ["building %1/6", (_hq getOrDefault ["buildStage", 0]) + 1]];
    };
    if (!_skip) then { sleep CQ_btSpawnDelay };
};

// As soon as an objective stands, a team (CQ_objGuardSize) splits off the nearest squad of the
// HQ (perimeter or patrol, never its leader, the squad keeps 2+ men) and guards it right away;
// CQ_fnc_hqGarrison skips the sites guarded this way
private _guardNow = {
    params ["_obj", ["_truckSquad", false]];
    if (isNull _obj) exitWith {};
    private _site = getPosATL _obj;
    private _donors = ((_hq get "infantry") select {
        (_x getVariable ["CQ_role", ""]) in ["patrol", "secure"] && { ({ alive _x } count units _x) >= CQ_objGuardSize + 2 }
    });
    // depot and tanker: the build truck's squad leaves a team behind first, else the nearest squad
    private _sg = _hq getOrDefault ["btSquad", grpNull];
    if (_truckSquad && { !isNull _sg } && { ({ alive _x } count units _sg) >= CQ_objGuardSize + 2 }) then { _donors = [_sg] };
    if (_donors isEqualTo []) exitWith { ["HQ #%1: no squad free to guard the new %2", [_id, typeOf _obj]] call CQ_fnc_log };
    private _donor = ([_donors, [], { (leader _x) distance2D _site }, "ASCEND"] call BIS_fnc_sortBy) select 0;
    private _men = ((units _donor) select { alive _x && { _x != leader _donor } && { vehicle _x == _x } }) select [0, CQ_objGuardSize];
    if (_men isEqualTo []) exitWith {};
    private _g = createGroup [east, true];
    _men joinSilent _g;
    _g setVariable ["CQ_role", "guard"];
    _g setBehaviour "AWARE";
    _g setSpeedMode "FULL";
    _g enableDynamicSimulation false;
    [_g, _site, 35] call CQ_fnc_infPatrol;
    (_hq get "infantry") pushBack _g;
    _obj setVariable ["CQ_guarded", true];
    ["HQ #%1: %2 men of %3 run to guard the new %4 (%5 m)", [_id, count _men, groupId _donor, typeOf _obj, round ((leader _g) distance2D _site)]] call CQ_fnc_log;
};

// Relaxed site (tolerance 3+): the troops clear trees and bushes from the footprint first
if ((_hq get "siteLevel") >= 3) then {
    private _veg = nearestTerrainObjects [_c, ["TREE", "SMALL TREE", "BUSH"], CQ_siteRadius, false, true];
    { _x hideObjectGlobal true } forEach _veg;
    ["HQ #%1: site tolerance %2, cleared %3 trees and bushes", [_id, _hq get "siteLevel", count _veg]] call CQ_fnc_log;
};

private _stage = {
    params ["_n", "_what"];
    _hq set ["buildStage", _n];
    ["Enemy HQ construction", format ["HQ #%1, stage %2/6: %3 (grid %4)", _id, _n, _what, mapGridPosition _c]] call CQ_fnc_announce;
    private _sk = ["", "stage1", "", "stage3", "", "", "operational"] select _n;
    if (_sk != "") then { [_sk, [[_id] call CQ_fnc_objName], _hq] call CQ_fnc_say };
};

// Django's Eden models (CQ_compos, cfg\compositions.sqf): footprint of each, the build truck stops outside it
private _cR = {
    params ["_name"];
    private _r = 6;
    { private _o = _x select 1; _r = _r max (sqrt (((_o select 0) ^ 2) + ((_o select 1) ^ 2))) } forEach (CQ_compos getOrDefault [_name, []]);
    _r + 8
};
private _hqR = ["hq"] call _cR;

// Objective sites first: every installation goes on its own spot of the ring
private _sites = call _sitesFor;
_hq set ["objSites", _sites];

// Stage 1 - 3 AA pits (air cover before anything else)
[_sites select 3, ["aaPit"] call _cR] call _truckWait;
private _aaGroup = createGroup [east, true];
{
    private _sp = _x;
    private _aa = ["O_static_AA_F", _sp, 0, true] call _placeAt;
    if (!isNull _aa) then {
        private _ap = getPosATL _aa;
        // the pit model around it; its other gun spot gets a second AA (same pit: neutralised when both crews are dead)
        private _guns = [_aa];
        {
            _x params ["_role", "_sp2", "_dir2"];
            if (_role == "aa") then {
                private _a2 = createVehicle ["O_static_AA_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
                _a2 setDir _dir2; _a2 setPosATL _sp2;
                (_hq get "objects") pushBack _a2;
                _guns pushBack _a2;
            };
        } forEach (["aaPit", _ap, _d, _hq get "objects"] call CQ_fnc_compoPlace);
        _aa setVariable ["CQ_pitGuns", _guns];
        {
            if (_x != _aa) then {
                createVehicleCrew _x;
                (crew _x) joinSilent _aaGroup;
                { _x setVariable ["CQ_crewOf", _aa] } forEach crew _x;
                [_x, 1] call CQ_fnc_vehAmmoInit;
            };
        } forEach _guns;
        createVehicleCrew _aa;
        _aa setVariable ["CQ_objType", "AA"];
        (_hq get "installations") pushBack _aa;
        (crew _aa) joinSilent _aaGroup;
        // the pit is neutralised once the crews of both its guns are dead: marker gone, counted as destroyed
        private _allCrew = [];
        { _allCrew append (crew _x) } forEach _guns;
        { _x setVariable ["CQ_crewOf", _aa]; _x addEventHandler ["Killed", {
            params ["_u", "_k", "_i"];
            private _aa = _u getVariable ["CQ_crewOf", objNull];
            if (isNull _aa || { _aa getVariable ["CQ_neutral", false] } || { ((_aa getVariable ["CQ_pitGuns", [_aa]]) findIf { ((crew _x) findIf { alive _x }) > -1 }) > -1 }) exitWith {};
            _aa setVariable ["CQ_neutral", true, true];
            private _w = [_i, _k] select (isNull _i);
            if (!isNull _w && { !(_w isKindOf "CAManBase") }) then { _w = effectiveCommander _w };
            private _c = _aa getVariable ["CQ_opEntry", []];
            if (_c isNotEqualTo [] && { (_c select 1) < 0 }) then { _c set [1, time]; _c set [2, if (!isNull _w && { isPlayer _w }) then { groupId group _w } else { "" }] };
            _aa lock 2;
            CQ_opNext = 0;
            ["AA pit at %1 neutralised (crew dead)", [mapGridPosition _aa]] call CQ_fnc_log;
        }] } forEach _allCrew;
        [_aa, 1] call CQ_fnc_vehAmmoInit;
        [_hq, "aaPit", _ap, ["aaPit"] call _cR] call CQ_fnc_guardSite;
    };
} forEach (_sites select [3, 3]);
_aaGroup setBehaviour "AWARE";
_aaGroup setCombatMode "RED";
(_hq get "support") pushBack _aaGroup;
[1, "3 AA pits"] call _stage;

// Stage 2 - HMG watchtower on the west side (facing the player's side of the island)
[_sites select 6, ["hmgTower"] call _cR] call _truckWait;
private _ta = CQ_hmgTowerDir - _d;
private _tower = ["Land_Cargo_Patrol_V3_F", _sites select 6, _ta, true] call _placeAt;
if (!isNull _tower) then {
    ["hmgTower", getPosATL _tower, getDir _tower, _hq get "objects"] call CQ_fnc_compoPlace;
    private _bp = _tower buildingPos 0;
    if (_bp isEqualTo [0, 0, 0]) then { _bp = (getPosATL _tower) vectorAdd [0, 0, 4.3] };
    private _hmg = createVehicle ["O_HMG_01_high_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
    _hmg setDir CQ_hmgTowerDir;
    _hmg setPosATL _bp;
    createVehicleCrew _hmg;
    private _tg = createGroup [east, true];
    (crew _hmg) joinSilent _tg;
    [crew _hmg] call CQ_fnc_unitPrep;
    [_hmg, 1] call CQ_fnc_vehAmmoInit;
    _tg setBehaviour "AWARE";
    _tg setCombatMode "RED";
    (_hq get "objects") pushBack _hmg;
    (_hq get "installations") pushBack _hmg;
    _hmg setVariable ["CQ_objType", "HMG tower"];
    (_hq get "support") pushBack _tg;
    ["HQ #%1: HMG watchtower up at grid %2 (west side)", [_id, mapGridPosition _tower]] call CQ_fnc_log;
    [_hq, "hmgTower", getPosATL _tower, ["hmgTower"] call _cR] call CQ_fnc_guardSite;
};

[2, "HMG watchtower"] call _stage;

// Stage 3 - radio tower, so the HQ can talk to the network
[_sites select 1, ["radio"] call _cR] call _truckWait;
private _radio = ["Land_TTowerBig_2_F", _sites select 1, 0, true] call _placeAt;
private _termSpot = [];
if (!isNull _radio) then {
    { if ((_x select 0) == "term") then { _termSpot = _x } } forEach (["radio", getPosATL _radio, getDir _radio, _hq get "objects"] call CQ_fnc_compoPlace);
};
// the tower is never blown up: it is hacked by an engineer (CQ_fnc_towerHack) and becomes our relay
_radio addEventHandler ["HandleDamage", {
    params ["_o", "", "", "_src", "", "", "_inst"];
    private _w = [_inst, _src] select (isNull _inst);
    if (isPlayer _w && { time > (_o getVariable ["CQ_hintT", 0]) }) then {
        _o setVariable ["CQ_hintT", time + 20];
        "Radio tower: it can't be destroyed. An Engineer must hack it (hold 20 s at its foot)." remoteExec ["hint", _w];
    };
    damage _o
}];
_radio setVariable ["CQ_hackable", true, true];
// the hack is done like defusing a bomb: on a field terminal at the tower's foot, it opens while
// anyone works on it (an Engineer CQ_hackTime s, others CQ_hackSlowFactor times longer; interrupted if he moves away or is hit)
if (!isNull _radio) then {
    // the field terminal on the model's computer spot (else 6 m from the tower, HQ side)
    private _tp = if (_termSpot isNotEqualTo []) then { _termSpot select 1 } else { (getPosATL _radio) getPos [6, (getPosATL _radio) getDir _c] };
    _tp = [_tp select 0, _tp select 1, 0];
    private _term = createVehicle ["Land_DataTerminal_01_F", _tp, [], 0, "CAN_COLLIDE"];
    _term setDir (if (_termSpot isNotEqualTo []) then { _termSpot select 2 } else { (_tp getDir (getPosATL _radio)) + 180 });
    _term setVectorUp surfaceNormal _tp;
    _term allowDamage false;
    _term setVariable ["CQ_tower", _radio, true];
    _radio setVariable ["CQ_terminal", _term, true];
    (_hq get "objects") pushBack _term;
    // anyone can hack; an Engineer twice as fast (two actions, one shows per player)
    {
        _x params ["_cond", "_time", "_label"];
        [_term,
            format ["<t color='#BA392C'>Hack radio tower%1</t>", _label],
            "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_hack_ca.paa",
            "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_hack_ca.paa",
            _cond + " && { _this distance _target < 3 } && { (_target getVariable ['CQ_tower', objNull]) getVariable ['CQ_hackable', false] }",
            "_caller distance _target < 3 && { alive _caller } && { lifeState _caller != 'INCAPACITATED' }",
            { params ["_target"]; [_target, 3] call BIS_fnc_dataTerminalAnimate },
            {},
            { params ["_target", "_caller"]; [_target getVariable ["CQ_tower", objNull], _caller] remoteExec ["CQ_fnc_towerHack", 2] },
            { params ["_target"]; [_target, 0] call BIS_fnc_dataTerminalAnimate },
            [], _time, 1000, false, false
        ] remoteExec ["BIS_fnc_holdActionAdd", 0, _term];
    } forEach [
        ["(_this getVariable ['CQ_class', '']) == 'Engineer'", CQ_hackTime, ""],
        ["(_this getVariable ['CQ_class', '']) != 'Engineer'", CQ_hackTime * CQ_hackSlowFactor, " (slow: not an engineer)"]
    ];
};
// guarded by posted men (CQ_fnc_guardSite / CQ_fnc_guardTick), there while a player is near
if (!isNull _radio) then { [_hq, "radio", getPosATL _radio, ["radio"] call _cR] call CQ_fnc_guardSite };
_radio setVariable ["CQ_objType", "Radio tower"];
_radio setVariable ["CQ_hqId", _id];
_hq set ["radio", _radio];
if (!isNull _radio) then { _hq set ["radioPos", getPosATL _radio] };     // nGD: where a relay can go once the HQ falls
_radio addEventHandler ["Killed", {
    if ((_this select 0) getVariable ["CQ_hacked", false]) exitWith {};          // our relay by then (CQ_fnc_relayDeploy logic)
    private _hq = CQ_hqs get ((_this select 0) getVariable ["CQ_hqId", -1]);
    if (isNil "_hq") exitWith {};
    ["Radio tower destroyed", format ["HQ #%1 is cut off from the network", _hq get "id"]] call CQ_fnc_announce;
    ["killTower", [[_hq get "id"] call CQ_fnc_objName]] call CQ_fnc_say;
    params ["", "_k", "_i"];
    [[_i, _k] select (isNull _i), 50, "radio tower"] call CQ_fnc_scoreAdd;
}];
(_hq get "installations") pushBack _radio;
[3, "radio tower"] call _stage;

// Stage 4 - supply depot + ammo boxes, field resupply truck
[_sites select 0, ["depot"] call _cR] call _truckWait;
private _depot = ["Land_Cargo_House_V3_F", _sites select 0, 90, true] call _placeAt;
if (!isNull _depot) then {
    ["depot", getPosATL _depot, getDir _depot, _hq get "objects"] call CQ_fnc_compoPlace;
    [_hq, "depot", getPosATL _depot, ["depot"] call _cR] call CQ_fnc_guardSite;
};
[_depot] call _engineerOnly;
_depot setVariable ["CQ_objType", "Depot"];
_depot setVariable ["CQ_hqId", _id];
_hq set ["depot", _depot];
_depot addEventHandler ["Killed", {
    private _hq = CQ_hqs get ((_this select 0) getVariable ["CQ_hqId", -1]);
    if (isNil "_hq" || { !((_hq get "state") in CQ_activeStates) }) exitWith {};   // fallen HQ: no score, no announce
    ["Supply depot destroyed", format ["HQ #%1 lost its %2 ammo: no more rearming there", _hq get "id", round (_hq get "stock")]] call CQ_fnc_announce;
    ["killDepot", [[_hq get "id"] call CQ_fnc_objName]] call CQ_fnc_say;
    params ["", "_k", "_i"];
    [[_i, _k] select (isNull _i), 50, "supply depot"] call CQ_fnc_scoreAdd;
    _hq set ["stock", 0];
}];

// Field resupply truck: driven out to groups short of ammo (CQ_fnc_fieldResupply)
private _ftruck = [CQ_fieldTruckClass, -_hqR, -12, 90] call _place;     // outside the HQ model
if (!isNull _ftruck) then {
    _ftruck setAmmoCargo 0;
    _ftruck lock 2;
    _ftruck setVariable ["CQ_hqId", _id];
    _ftruck addEventHandler ["Killed", {
        private _hq = CQ_hqs get ((_this select 0) getVariable ["CQ_hqId", -1]);
        if (isNil "_hq") exitWith {};
        ["Field supply truck destroyed", format ["HQ #%1 can no longer resupply its squads in the field", _hq get "id"]] call CQ_fnc_announce;
    }];
    _hq set ["fieldTruckHome", getPosATL _ftruck];
};
_hq set ["fieldTruck", _ftruck];
if (!isNull _depot) then { (_hq get "installations") pushBack _depot };
_hq set ["stock", (_hq get "stockInit") min (_hq get "cap")];
[4, format ["supply depot (%1 ammo), field supply truck", round (_hq get "stock")]] call _stage;

// Stage 5 - fuel tanker
[_sites select 2, ["fuel"] call _cR] call _truckWait;
// Fuel tanker: holds the HQ's fuel. Any weapon can destroy it. It is parked in the model's hangar.
private _hangar = ["Land_Airport_01_hangar_F", _sites select 2, 90, true] call _placeAt;
private _tanker = objNull;
if (!isNull _hangar) then {
    ["fuel", getPosATL _hangar, getDir _hangar, _hq get "objects"] call CQ_fnc_compoPlace;
    _tanker = createVehicle [CQ_tankerClass, [0, 0, 0], [], 0, "CAN_COLLIDE"];
    _tanker setDir (getDir _hangar);
    _tanker setPosATL [(getPosATL _hangar) select 0, (getPosATL _hangar) select 1, 0];
    (_hq get "objects") pushBack _tanker;
    [_hq, "fuel", getPosATL _hangar, ["fuel"] call _cR] call CQ_fnc_guardSite;
} else {
    _tanker = [CQ_tankerClass, _sites select 2, 90] call _placeAt;
};
if (!isNull _tanker) then {
    _tanker setFuelCargo 0;           // players can't refuel from it
    _tanker lock 2;
    _tanker setVariable ["CQ_hqId", _id];
    _tanker addEventHandler ["Killed", {
        private _hq = CQ_hqs get ((_this select 0) getVariable ["CQ_hqId", -1]);
        if (isNil "_hq" || { !((_hq get "state") in CQ_activeStates) }) exitWith {};   // fallen HQ: nothing to announce
        ["Fuel tanker destroyed", format ["HQ #%1 lost its %2 fuel: no more refuelling there", _hq get "id", round (_hq get "fuel")]] call CQ_fnc_announce;
        _hq set ["fuel", 0];
    }];
};
_hq set ["tanker", _tanker];
if (!isNull _tanker) then { _tanker setVariable ["CQ_objType", "Fuel tanker"] };

if (!isNull _tanker) then { (_hq get "installations") pushBack _tanker };
_hq set ["fuel", [(_hq get "fuelInit") min (_hq get "cap"), 0] select (isNull _tanker)];
[5, format ["fuel tanker (%1 fuel)", round (_hq get "fuel")]] call _stage;

// Stage 6 - command post (HQ model), helipad with the QRF helicopter
[[-_hqR, -_hqR] call _at] call _truckWait;     // outside the HQ model
private _bld = ["Land_Cargo_HQ_V3_F", 0, 0, 0, true] call _place;
_hq set ["building", _bld];
private _padSpot = [];
if (!isNull _bld) then {
    { if ((_x select 0) == "pad") then { _padSpot = _x } } forEach (["hq", getPosATL _bld, getDir _bld, _hq get "objects"] call CQ_fnc_compoPlace);
};
private _pad = objNull;
if (_padSpot isNotEqualTo []) then {
    _pad = createVehicle ["Land_HelipadSquare_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
    _pad setDir (_padSpot select 2);
    _pad setPosATL [(_padSpot select 1) select 0, (_padSpot select 1) select 1, 0];
    (_hq get "objects") pushBack _pad;
} else {
    _pad = ["Land_HelipadSquare_F", _hqR, 0, 0, true] call _place;
};
_hq set ["pad", _pad];
if (!isNull _pad) then {
    private _heli = createVehicle [CQ_hqHeliClass, getPosATL _pad, [], 0, "CAN_COLLIDE"];
    _heli setDir (getDir _pad);
    private _hg = [_heli] call CQ_fnc_crewVehicle;
    _hg setBehaviour "SAFE";
    _heli engineOn false;
    [_heli] call CQ_fnc_airLoadout;
    [_heli, 1] call CQ_fnc_vehAmmoInit;
    [_heli, _hg, "armed", _id, _pad, [], true] call CQ_fnc_airRegister;
    (_hq get "support") pushBack _hg;
};
if (!isNull _bld) then { [_hq, "hq", getPosATL _bld, _hqR - 8] call CQ_fnc_guardSite };

[6, "command post, helipad with QRF helicopter"] call _stage;

// Recall the perimeter squads and set the garrison
[_hq] call CQ_fnc_hqGarrison;
_hq set ["buildDone", true];
["board", [_hq]] spawn CQ_fnc_buildTruck;   // the squad gets back in: the truck waits there to found the next HQ
_hq set ["builtT", time];
[["medic", "engineer"] select ((_hq get "id") mod 2 == 1), _hq get "id"] spawn CQ_fnc_specialTeam;   // its own support team
[_hq] call CQ_fnc_hqStatusMarker;
[_hq] call CQ_fnc_hqGuerilla;
