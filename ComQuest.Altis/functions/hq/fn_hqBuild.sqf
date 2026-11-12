/*
    CQ_fnc_hqBuild  (server, spawned by CQ_fnc_hqTick when the perimeter is secured)
    [_hq] spawn CQ_fnc_hqBuild;
    Builds the HQ composition in 6 stages, CQ_hqBuildStageTime seconds apart, announcing each.
    Offsets are [right, forward] metres in the HQ's own frame (rotated by its "dir").
      1 3 AA pits   2 HMG watchtower   3 radio tower (they can communicate)
      4 supply depot + field supply truck   5 fuel tanker
      6 helipad + parked QRF helicopter, command building, sandbag ring (gaps front and back)
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
// Stage wait: CQ_hqBuildStageTime of calm, or until the debug panel skips it. The clock stops
// during a battle (no construction under fire): contact reported by the HQ less than
// CQ_buildPauseAfterContact s ago, or BLUFOR within CQ_buildPauseRange of the site.
private _wait = {
    private _left = CQ_hqBuildStageTime;
    private _paused = false;
    waitUntil {
        sleep 1;
        private _fight = (time - (_hq get "lastContactT") < CQ_buildPauseAfterContact)
            || { ((_c nearEntities [["CAManBase", "LandVehicle", "Air"], CQ_buildPauseRange]) findIf { alive _x && { side group _x == west } }) > -1 };
        // nGD: players near or a recent contact slow the work down (CQ_buildSlowNear) instead of
        // stopping it: hanging around a site is no longer a pause button, the build is a race
        if (_fight) then {
            if (!_paused) then { _paused = true; ["HQ #%1: construction slowed down, battle at the site", [_id]] call CQ_fnc_log };
            _left = _left - CQ_buildSlowNear;
        } else {
            if (_paused) then { _paused = false; ["HQ #%1: construction back to full speed", [_id]] call CQ_fnc_log };
            _left = _left - 1;
        };
        _left <= 0 || { _hq get "skipStage" }
    };
    _hq set ["skipStage", false];
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

// Objective sites first: every installation goes on its own spot of the ring
private _sites = call _sitesFor;
_hq set ["objSites", _sites];

// Stage 1 - 3 AA pits (air cover before anything else)
call _wait;
private _aaGroup = createGroup [east, true];
{
    private _sp = _x;
    private _aa = ["O_static_AA_F", _sp] call _placeAt;
    if (!isNull _aa) then {
        private _ap = getPosATL _aa;
        { ["Land_BagFence_Round_F", _ap getPos [2.6, _d + _x], _x + 180] call _placeAt } forEach [0, 120, 240];
        createVehicleCrew _aa;
        _aa setVariable ["CQ_objType", "AA"];
        (_hq get "installations") pushBack _aa;
        (crew _aa) joinSilent _aaGroup;
        [_aa, 1] call CQ_fnc_vehAmmoInit;
    };
} forEach (_sites select [3, 3]);
_aaGroup setBehaviour "AWARE";
_aaGroup setCombatMode "RED";
(_hq get "support") pushBack _aaGroup;
[1, "3 AA pits"] call _stage;

// Stage 2 - HMG watchtower on the west side (facing the player's side of the island)
call _wait;
private _ta = CQ_hmgTowerDir - _d;
private _tower = ["Land_Cargo_Patrol_V1_F", _sites select 6, _ta, true] call _placeAt;
if (!isNull _tower) then {
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
};

[2, "HMG watchtower"] call _stage;

// Stage 3 - radio tower, so the HQ can talk to the network
call _wait;
private _radio = ["Land_TTowerBig_2_F", _sites select 1, 0, true] call _placeAt;
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
// an Engineer works on it (CQ_hackTime s, interrupted if he moves away or is hit)
if (!isNull _radio) then {
    private _tp = (getPosATL _radio) getPos [6, (getPosATL _radio) getDir _c];
    _tp = [_tp select 0, _tp select 1, 0];
    private _term = createVehicle ["Land_DataTerminal_01_F", _tp, [], 0, "CAN_COLLIDE"];
    _term setDir ((_tp getDir (getPosATL _radio)) + 180);
    _term setVectorUp surfaceNormal _tp;
    _term allowDamage false;
    _term setVariable ["CQ_tower", _radio, true];
    _radio setVariable ["CQ_terminal", _term, true];
    (_hq get "objects") pushBack _term;
    [_term,
        "<t color='#BA392C'>Hack radio tower</t>",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_hack_ca.paa",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_hack_ca.paa",
        "(_this getVariable ['CQ_class', '']) == 'Engineer' && { _this distance _target < 3 } && { (_target getVariable ['CQ_tower', objNull]) getVariable ['CQ_hackable', false] }",
        "_caller distance _target < 3 && { alive _caller } && { lifeState _caller != 'INCAPACITATED' }",
        { params ["_target"]; [_target, 3] call BIS_fnc_dataTerminalAnimate },
        {},
        { params ["_target", "_caller"]; [_target getVariable ["CQ_tower", objNull], _caller] remoteExec ["CQ_fnc_towerHack", 2] },
        { params ["_target"]; [_target, 0] call BIS_fnc_dataTerminalAnimate },
        [], CQ_hackTime, 1000, false, false
    ] remoteExec ["BIS_fnc_holdActionAdd", 0, _term];
};
// heavily guarded: a squad of its own around the tower (scaled, out of the AI caps)
if (!isNull _radio) then {
    private _gg = createGroup [east, true];
    _gg setGroupIdGlobal [format ["Tower guard %1", _id]];
    private _n = (round (count CQ_towerGuard * ((missionNamespace getVariable ["CQ_scale", 1]) max 0.5))) min count CQ_towerGuard;
    for "_i" from 0 to _n - 1 do {
        private _p = (getPosATL _radio) getPos [12 + random 10, _i * 360 / _n];
        private _u = _gg createUnit [CQ_towerGuard select _i, [_p select 0, _p select 1, 0], [], 0, "NONE"];
        _u setSkill CQ_towerGuardSkill;
        _u setVariable ["CQ_noCap", true, true];
    };
    [units _gg] call CQ_fnc_unitPrep;
    _gg setBehaviour "AWARE"; _gg setCombatMode "RED";
    _gg enableDynamicSimulation false;
    [_gg, getPosATL _radio, 35] call BIS_fnc_taskDefend;
    (_hq get "support") pushBack _gg;
    ["HQ #%1: radio tower guarded by %2 men", [_id, count units _gg]] call CQ_fnc_log;
};
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
call _wait;
private _depot = ["Land_Cargo_House_V1_F", _sites select 0, 90, true] call _placeAt;
if (!isNull _depot) then { { ["Box_East_Ammo_F", (getPosATL _depot) getPos [7, _d + 180 + _x]] call _placeAt } forEach [-25, 0, 25] };
[_depot] call _engineerOnly;
_depot setVariable ["CQ_objType", "Depot"];
_depot setVariable ["CQ_hqId", _id];
_hq set ["depot", _depot];
_depot addEventHandler ["Killed", {
    private _hq = CQ_hqs get ((_this select 0) getVariable ["CQ_hqId", -1]);
    if (isNil "_hq") exitWith {};
    ["Supply depot destroyed", format ["HQ #%1 lost its %2 ammo: no more rearming there", _hq get "id", round (_hq get "stock")]] call CQ_fnc_announce;
    ["killDepot", [[_hq get "id"] call CQ_fnc_objName]] call CQ_fnc_say;
    params ["", "_k", "_i"];
    [[_i, _k] select (isNull _i), 50, "supply depot"] call CQ_fnc_scoreAdd;
    _hq set ["stock", 0];
}];

// Field resupply truck: driven out to groups short of ammo (CQ_fnc_fieldResupply)
private _ftruck = [CQ_fieldTruckClass, -18, -20, 90] call _place;
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
call _wait;
// Fuel tanker: holds the HQ's fuel. Any weapon can destroy it.
private _tanker = [CQ_tankerClass, _sites select 2, 90] call _placeAt;
if (!isNull _tanker) then {
    _tanker setFuelCargo 0;           // players can't refuel from it
    _tanker lock 2;
    _tanker setVariable ["CQ_hqId", _id];
    _tanker addEventHandler ["Killed", {
        private _hq = CQ_hqs get ((_this select 0) getVariable ["CQ_hqId", -1]);
        if (isNil "_hq") exitWith {};
        ["Fuel tanker destroyed", format ["HQ #%1 lost its %2 fuel: no more refuelling there", _hq get "id", round (_hq get "fuel")]] call CQ_fnc_announce;
        _hq set ["fuel", 0];
    }];
};
_hq set ["tanker", _tanker];
if (!isNull _tanker) then { _tanker setVariable ["CQ_objType", "Fuel tanker"] };

if (!isNull _tanker) then { (_hq get "installations") pushBack _tanker };
_hq set ["fuel", [(_hq get "fuelInit") min (_hq get "cap"), 0] select (isNull _tanker)];
[5, format ["fuel tanker (%1 fuel)", round (_hq get "fuel")]] call _stage;

// Stage 6 - helipad with the QRF helicopter, command building, sandbag ring
call _wait;
private _pad = ["Land_HelipadSquare_F", 26, 0, 0, true] call _place;
_hq set ["pad", _pad];
if (!isNull _pad) then {
    private _heli = createVehicle [CQ_hqHeliClass, getPosATL _pad, [], 0, "CAN_COLLIDE"];
    _heli setDir _d;
    private _hg = [_heli] call CQ_fnc_crewVehicle;
    _hg setBehaviour "SAFE";
    _heli engineOn false;
    [_heli] call CQ_fnc_airLoadout;
    [_heli, 1] call CQ_fnc_vehAmmoInit;
    [_heli, _hg, "armed", _id, _pad, [], true] call CQ_fnc_airRegister;
    (_hq get "support") pushBack _hg;
};

private _bld = ["Land_Cargo_HQ_V1_F", 0, 0, 0, true] call _place;
_hq set ["building", _bld];

// sandbag ring, radius 13 m, gaps at the front (0) and back (180)
for "_a" from 15 to 345 step 15 do {
    if (_a != 180) then {
        ["Land_BagFence_Long_F", 13 * sin _a, 13 * cos _a, _a + 90] call _place;
    };
};

[6, "helipad with QRF helicopter, command building, sandbag ring"] call _stage;

// Recall the perimeter squads and set the garrison
[_hq] call CQ_fnc_hqGarrison;
_hq set ["buildDone", true];
_hq set ["builtT", time];
[_hq] call CQ_fnc_hqStatusMarker;
[_hq] call CQ_fnc_hqGuerilla;
