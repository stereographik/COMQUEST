/*
    CQ_fnc_magInit  (server, once)
    MAGPIE, the friendly UAV operator (a bot). Three drones (CQ_magDrones) + the scan chain
    Darters: each spawns on the take-off spot in turn and takes off by itself (vanilla AI,
    CQ_fnc_magTick); a lost drone is replaced after CQ_magRespawn s. CQ_fnc_magTick flies them, identifies enemies and writes her reports.
    Also builds the search grid over CQ_magArea (dry cells clear of the east coast).
*/
if (!isServer) exitWith {};
// runway: threshold (ilsPosition) and take-off heading (opposite of the approach vector)
private _ils = getArray (configFile >> "CfgWorlds" >> worldName >> "ilsPosition");
private _ilsDir = getArray (configFile >> "CfgWorlds" >> worldName >> "ilsDirection");
CQ_magRunway = [];
if (count _ils >= 2 && { count _ilsDir >= 3 }) then {
    private _hdg = (-(_ilsDir select 0)) atan2 (-(_ilsDir select 2));
    if (CQ_magRunwayFlip) then { _hdg = _hdg + 180 };
    private _p = [_ils select 0, _ils select 1, 0] getPos [80, _hdg];
    CQ_magRunway = [[_p select 0, _p select 1, 0], _hdg];
} else {
    CQ_magRunway = [CQ_basePos getPos [150, CQ_baseDir], CQ_baseDir];
};
// clear the take-off strip: everything on the runway goes (terrain objects hidden, mission
// objects deleted), from 150 m behind the spawn point to CQ_runwayLength ahead, CQ_runwayHalfWidth
// either side of the centre line. Vehicles and people are left alone.
CQ_magRunway params ["_rp0", "_hdg0"];
private _hiddenT = 0; private _deleted = 0;
private _inStrip = {
    params ["_o"];
    private _rel = (getPosATL _o) vectorDiff _rp0;
    private _along = (_rel select 0) * sin _hdg0 + (_rel select 1) * cos _hdg0;
    private _side = (_rel select 0) * cos _hdg0 - (_rel select 1) * sin _hdg0;
    _along > -150 && { _along < CQ_runwayLength } && { abs _side < CQ_runwayHalfWidth }
};
private _mid = _rp0 getPos [CQ_runwayLength / 2 - 75, _hdg0];
private _rad = CQ_runwayLength / 2 + 100;
private _roads = _mid nearRoads _rad;
{
    if (!(_x in _roads) && { [_x] call _inStrip }) then { hideObjectGlobal _x; _hiddenT = _hiddenT + 1 };
} forEach (nearestTerrainObjects [_mid, [], _rad, false, true]);
{
    if (!(_x isKindOf "CAManBase") && { !(_x isKindOf "LandVehicle") || { _x isKindOf "StaticWeapon" } } && { !(_x isKindOf "Air") }
        && { !(_x isKindOf "Logic") } && { [_x] call _inStrip }) then {
        { deleteVehicle _x } forEach (crew _x);
        deleteVehicle _x;
        _deleted = _deleted + 1;
    };
} forEach (nearestObjects [_mid, ["All"], _rad]);
["MAGPIE: runway cleared (%1 terrain objects hidden, %2 mission objects removed)", [_hiddenT, _deleted]] call CQ_fnc_log;

CQ_magEastOk = {
    params ["_p"];
    !surfaceIsWater _p && {
        private _ok = true;
        { if (surfaceIsWater (_p getPos [_x select 0, _x select 1])) exitWith { _ok = false } }
            forEach [[CQ_magCoastGap * 0.5, 90], [CQ_magCoastGap, 90], [CQ_magCoastGap, 45], [CQ_magCoastGap, 135]];
        _ok
    }
};
CQ_magCells = [];                         // [center, scanned]
CQ_magArea params ["_x0", "_y0", "_x1", "_y1"];
for "_x" from _x0 + CQ_magCell / 2 to _x1 step CQ_magCell do {
    for "_y" from _y0 + CQ_magCell / 2 to _y1 step CQ_magCell do {
        private _c = [_x, _y, 0];
        if ([_c] call CQ_magEastOk) then { CQ_magCells pushBack [_c, false] };
    };
};
CQ_magSeen = createHashMap;               // hashValue -> [object, firstT, lastT, pos, cat, reported]
CQ_magHqSeen = createHashMap;             // hq id -> last reported stage (-1 = site only)
CQ_magReportT = time;
CQ_magDetectT = 0;
CQ_magNewSince = 0;                       // new identifications in the last report
CQ_mag = [];
{
    _x params ["_name", "_classes", "_alt", "_scale"];
    private _cls = _classes param [_classes findIf {
        private _c = configFile >> "CfgVehicles" >> _x;
        isClass _c && { getText (_c >> "DLC") == "" }
    }, ""];
    if (_cls == "") then { ["MAGPIE: no airframe available for %1", [_name]] call CQ_fnc_log; continue };
    CQ_mag pushBack createHashMapFromArray [
        ["i", _forEachIndex], ["name", _name], ["cls", _cls], ["alt", _alt], ["scale", _scale],
        ["veh", objNull], ["due", time + CQ_magFirstDelay], ["phase", "none"], ["tries", 0], ["rollT", 0],
        ["planT", 0], ["explore", false], ["target", []], ["lost", false]
    ];
} forEach CQ_magDrones;
// the scan chain: Darters with a slot on the moving north-south line
for "_j" from 0 to CQ_magChainCount - 1 do {
    CQ_mag pushBack createHashMapFromArray [
        ["i", count CQ_mag], ["name", format ["Chain %1", _j + 1]], ["cls", "B_UAV_01_F"], ["alt", CQ_magChainAlt], ["scale", 1],
        ["veh", objNull], ["due", time + CQ_magFirstDelay], ["phase", "none"], ["tries", 0], ["rollT", 0],
        ["planT", 0], ["explore", false], ["target", []], ["lost", false], ["role", "chain"], ["slot", _j]
    ];
};
CQ_magChainX = (CQ_basePos select 0) + 1000;      // the line starts just east of the base
CQ_magChainT = time;
CQ_magChainSlots = [];
CQ_magNext = 0;
["MAGPIE: %1 drones (%2), runway %3 heading %4, %5 search cells", [count CQ_mag, (CQ_mag apply { _x get "cls" }) joinString ", ",
    mapGridPosition (CQ_magRunway select 0), round (CQ_magRunway select 1), count CQ_magCells]] call CQ_fnc_log;
