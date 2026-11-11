/*
    CQ_fnc_outpostBuild  (server, spawned with the first HQ's insertion)
    [_hqSite] spawn CQ_fnc_outpostBuild;
    The corridor outpost: on the land corridor between the coast (CQ_coastPoint) and the first
    HQ, the highest open spot that best sees the flight corridor from the carrier (or an Altis
    military post found there): watchtower + watcher, CQ_opAA, CQ_opHMG, a mortar, a jammer and a
    barricaded squad (scaled with CQ_scale); CQ_opBoats gunboats patrol the coast. Every man is
    marked CQ_outpost (out of the AI caps, never reinforced). State: CQ_op (CQ_fnc_outpostTick).
*/
params ["_hqSite"];
if (!isServer || { !CQ_outpost }) exitWith {};
if (!isNil "CQ_op") exitWith { ["Outpost: already built"] call CQ_fnc_log };
private _a = [CQ_coastPoint select 0, CQ_coastPoint select 1, 0];
private _b = [_hqSite select 0, _hqSite select 1, 0];
private _len = _a distance2D _b;
private _dir = _a getDir _b;

// the flight corridor seen from a site: points from the carrier to the HQ, 60 m above ground / sea
private _vis = [];
for "_d" from 0 to (CQ_carrierPos distance2D _b) step 400 do {
    private _p = CQ_carrierPos getPos [_d, CQ_carrierPos getDir _b];
    _vis pushBack [_p select 0, _p select 1, ((getTerrainHeightASL _p) max 0) + 60];
};
private _blockers = ["TREE", "SMALL TREE", "ROCK", "ROCKS", "BUILDING", "HOUSE", "CHURCH", "CHAPEL", "FUEL STATION", "HOSPITAL", "RUIN", "WALL", "FENCE", "TRANSMITTER", "LIGHTHOUSE", "POWER LINES", "QUAY", "VIEW-TOWER"];
private _score = {
    params ["_c"];
    private _eye = AGLToASL _c vectorAdd [0, 0, 8];
    (getTerrainHeightASL _c) + 15 * ({ !terrainIntersectASL [_eye, _x] } count _vis)
};

// 1. an Altis military post on the corridor (within 250 m of its line)
private _center = [];
private _tower = objNull;
private _mid = [((_a select 0) + (_b select 0)) / 2, ((_a select 1) + (_b select 1)) / 2, 0];
private _posts = (nearestObjects [_mid, CQ_opReuse, _len / 2 + 300]) select {
    private _q = getPosATL _x; _q set [2, 0];
    private _t = ((_q vectorDiff _a) vectorDotProduct ((_b vectorDiff _a) vectorMultiply (1 / (_len max 1)))) / (_len max 1);
    private _onLine = _a vectorAdd ((_b vectorDiff _a) vectorMultiply ((_t max 0) min 1));
    _x distance2D _onLine < 250 && { _x distance2D _b > CQ_opHqGap } && { alive _x }
};
if (_posts isNotEqualTo []) then {
    _tower = ([_posts, [], { [getPosATL _x] call _score }, "DESCEND"] call BIS_fnc_sortBy) select 0;
    _center = getPosATL _tower; _center set [2, 0];
};

// 2. else the best open spot: flat 40 x 40 m, nothing in the way, scored on height + corridor seen
if (_center isEqualTo []) then {
    private _bestS = -1e9;
    {
        _x params ["_side", "_flat", "_gap"];
        for "_d" from 0 to _len step 40 do {
            for "_o" from -_side to _side step 40 do {
                private _c = (_a getPos [_d, _dir]) getPos [_o, _dir + 90];
                _c = [_c select 0, _c select 1, 0];
                if (surfaceIsWater _c || { _c distance2D _b < _gap }) then { continue };
                private _hs = [_c, _c getPos [20, 0], _c getPos [20, 90], _c getPos [20, 180], _c getPos [20, 270]] apply { getTerrainHeightASL _x };
                if (((selectMax _hs) - (selectMin _hs)) > _flat) then { continue };
                if (({ surfaceIsWater (_c getPos [25, _x]) } count [0, 90, 180, 270]) > 0) then { continue };
                if ((nearestTerrainObjects [_c, _blockers, 22, false, true]) isNotEqualTo []) then { continue };
                if ((_c nearRoads 22) isNotEqualTo []) then { continue };
                if ((allPlayers findIf { _x distance2D _c < 300 }) > -1) then { continue };
                private _s = [_c] call _score;
                if (_s > _bestS) then { _bestS = _s; _center = _c };
            };
        };
        if (_center isNotEqualTo []) exitWith {};
    } forEach [[200, CQ_opFlat, CQ_opHqGap], [400, CQ_opFlat * 1.6, CQ_opHqGap * 0.7]];   // then relaxed
};
if (_center isEqualTo []) then { _center = [_mid, 0, 400, true, 40] call CQ_fnc_findSite };
if (_center isEqualTo []) exitWith { ["Outpost: no site on the corridor (%1 m long)", [round _len]] call CQ_fnc_log };

// ---- build
private _f = _center getDir CQ_carrierPos;          // facing the corridor / the sea
{ _x hideObjectGlobal true } forEach (nearestTerrainObjects [_center, ["BUSH"], 24, false, true]);
private _objs = [];
private _put = {
    params ["_cls", "_r", "_ang", ["_face", _f]];
    private _p = _center getPos [_r, _f + _ang];
    _p = [_p select 0, _p select 1, 0];
    private _o = createVehicle [_cls, _p, [], 0, "CAN_COLLIDE"];
    _o setDir _face;
    _o setVectorUp surfaceNormal _p;
    _o allowDamage false;
    _objs pushBack _o;
    _o
};
private _reused = !isNull _tower;
if (!_reused) then { _tower = [CQ_opTower, 0, 0, _f + 180] call _put };
private _jcls = CQ_opJammer param [CQ_opJammer findIf { isClass (configFile >> "CfgVehicles" >> _x) }, "Land_TTowerSmall_1_F"];
private _jammer = [_jcls, 16, 90] call _put;
private _aa = []; private _hmg = [];
{ _aa pushBack ([_x, 13, [-40, 40] select _forEachIndex] call _put) } forEach CQ_opAA;
{ _hmg pushBack ([_x, 13, [-140, 140] select _forEachIndex] call _put) } forEach CQ_opHMG;
private _mortar = [CQ_opMortar, 11, 180] call _put;
{
    private _s = _x;
    private _bp = (getPosATL _s) getPos [2.4, _f];
    private _bag = createVehicle ["Land_BagFence_Round_F", [_bp select 0, _bp select 1, 0], [], 0, "CAN_COLLIDE"];
    _bag setDir (_f + 180);
    _objs pushBack _bag;
} forEach (_aa + _hmg);
[_objs] spawn { params ["_o"]; sleep 8; { if (!isNull _x) then { _x allowDamage true } } forEach _o };

// crews: every static, CSAT gunners
private _men = [];
{
    private _g = [_x] call CQ_fnc_crewVehicle;
    _g setBehaviour "AWARE"; _g setCombatMode "RED";
    { _x setSkill CQ_opSkill; _men pushBack _x } forEach units _g;
    _x setVariable ["CQ_outpost", true, true];
} forEach (_aa + _hmg + [_mortar]);

// watcher on the tower top, squad around the sandbags and in the tower (barricaded: they hold)
private _g = createGroup [east, true];
_g setGroupIdGlobal ["Corridor outpost"];
private _bps = (_tower buildingPos -1) select { _x isNotEqualTo [0, 0, 0] };
_bps = [_bps, [], { _x select 2 }, "DESCEND"] call BIS_fnc_sortBy;
private _watcher = _g createUnit [CQ_opWatcher, _center, [], 0, "NONE"];
if (_bps isNotEqualTo []) then { _watcher setPosATL (_bps deleteAt 0) };
_watcher disableAI "PATH";
private _n = (round (count CQ_opSquad * ((missionNamespace getVariable ["CQ_scale", 1]) max 0.5))) min count CQ_opSquad;
for "_i" from 0 to _n - 1 do {
    private _u = _g createUnit [CQ_opSquad select _i, _center, [], 0, "NONE"];
    if (_bps isNotEqualTo []) then { _u setPosATL (_bps deleteAt 0) } else {
        private _p = _center getPos [7 + random 8, _f + (_i * 360 / _n)];
        _u setPosATL [_p select 0, _p select 1, 0];
    };
    _u disableAI "PATH";
    _u setUnitPos "MIDDLE";
};
[units _g] call CQ_fnc_unitPrep;
{ _x setSkill CQ_opSkill; _men pushBack _x } forEach units _g;
_g setBehaviour "AWARE"; _g setCombatMode "RED";
_g enableDynamicSimulation false;

// gunboats along the coast around the coast point
private _sea = CQ_coastPoint getDir CQ_carrierPos;
private _pts = [];
{
    private _p = (CQ_coastPoint getPos [700, _sea]) getPos [_x, _sea + 90];
    if (surfaceIsWater _p && { getTerrainHeightASL _p < -3 }) then { _pts pushBack [_p select 0, _p select 1, 0] };
} forEach [-1400, -700, 0, 700, 1400];
private _boats = [];
if (count _pts >= 2) then {
    for "_k" from 0 to CQ_opBoats - 1 do {
        private _route = +_pts;
        if (_k mod 2 == 1) then { reverse _route };
        private _bt = createVehicle [CQ_opBoat, _route select 0, [], 30, "NONE"];
        _bt setVariable ["CQ_outpost", true, true];
        private _bg = [_bt] call CQ_fnc_crewVehicle;
        { _x setSkill CQ_opSkill; _men pushBack _x } forEach units _bg;
        _bg setBehaviour "AWARE"; _bg setCombatMode "RED"; _bg setSpeedMode "LIMITED";
        { (_bg addWaypoint [_x, 0]) setWaypointType "MOVE" } forEach _route;
        (_bg addWaypoint [_route select 0, 0]) setWaypointType "CYCLE";
        _boats pushBack _bt;
    };
};
{ _x setVariable ["CQ_outpost", true, true] } forEach _men;

private _off = (CQ_opFuzz select 0) + random ((CQ_opFuzz select 1) - (CQ_opFuzz select 0));
CQ_op = createHashMapFromArray [
    ["pos", _center], ["fuzzPos", _center getPos [_off, random 360]], ["objs", _objs], ["men", _men],
    ["tower", _tower], ["watcher", _watcher], ["jammer", _jammer], ["aa", _aa], ["mortar", _mortar], ["boats", _boats],
    ["hqSite", _b], ["hqId", -1], ["spotted", false], ["fallen", false], ["mark", ""], ["jam", true],
    ["mortarT", 0], ["mortarAim", []]
];
CQ_opJamPos = _center; publicVariable "CQ_opJamPos";
CQ_opJam = true; publicVariable "CQ_opJam";
["Outpost: corridor outpost at %1 (%2, %3 m from the coast, %4 m from the HQ site), %5 men, %6 gunboats",
    [mapGridPosition _center, ["built", "Altis post reused"] select _reused, round (_center distance2D _a), round (_center distance2D _b), count _men, count _boats]] call CQ_fnc_log;
