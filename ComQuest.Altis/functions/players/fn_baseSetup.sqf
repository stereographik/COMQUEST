/*
    CQ_fnc_baseSetup  (server)
    Builds the player base from the zones drawn on the map (cfg/settings.sqf):
    1. HQ compound at CQ_basePos, front toward CQ_baseDir (CQ_compoundSize), H-barrier walls,
       vehicle gate flanked by two H-barrier towers, guard towers in the corners, tank traps:
         back row     warehouse | HQ offices (friendly commander inside) | cargo HQ
         courtyard    radar + watchtower, flag, medical post, 4 squad equipment boxes aligned
                      in the centre (arsenal + squad resupply)
       Terrain objects inside the compound are hidden.
    2. Vehicle zone: 4 parallel rows starting at CQ_rayStarts and running along CQ_baseDir.
       Vehicles parked side by side, PERPENDICULAR to the row, from the smallest to the
       largest (gap = footprint from the bounding box + CQ_raySpacing), helicopters on pads.
       Vehicles are shared out so every row gets a similar mix.
    3. At the far end of each row a crate dispenser (CQ_dispensers, pushed further if the row
       is longer): CQ_dispenserCrates ready-filled loadable crates + a loadout zone.
    4. Repair stations at CQ_repairSpots (CQ_fnc_baseRepairTick).
    5. Defence spots around the perimeter, respawn, a few map markers.
    Every class is checked (exists, no DLC); a missing one falls back or is skipped and logged.
*/
if (!isServer) exitWith {};

private _o = CQ_basePos;
private _d = CQ_baseDir;
CQ_baseDir = _d;
publicVariable "CQ_baseDir";

private _at = {
    params ["_x0", "_y0"];
    private _p = _o getPos [sqrt (_x0 ^ 2 + _y0 ^ 2), _d + (_x0 atan2 _y0)];
    [_p select 0, _p select 1, 0]
};
// first class of the list that exists and needs no DLC
// (_free: objects from free platform updates, allowed even if their config names a DLC)
private _pick = {
    params ["_list", ["_free", []]];
    private _i = _list findIf {
        private _c = configFile >> "CfgVehicles" >> _x;
        isClass _c && { getNumber (_c >> "scope") >= 1 } && { getText (_c >> "DLC") == "" || { _x in _free } }
    };
    if (_i < 0) exitWith { ["Base: none of %1 available, skipped", [_list]] call CQ_fnc_log; "" };
    _list select _i
};
// footprint [width (x), length (y)] from the model bounding box, cached
if (isNil "CQ_dimCache") then { CQ_dimCache = createHashMap };
private _dims = {
    params ["_cls"];
    if (_cls in CQ_dimCache) exitWith { CQ_dimCache get _cls };
    private _t = createSimpleObject [_cls, [50, 50, 500]];
    private _r = [4, 4];
    if (!isNull _t) then {
        (boundingBoxReal _t) params ["_a", "_b"];
        _r = [abs ((_b select 0) - (_a select 0)), abs ((_b select 1) - (_a select 1))];
        deleteVehicle _t;
    };
    CQ_dimCache set [_cls, _r];
    _r
};
private _placed = 0;
private _put = {
    params ["_list", "_x0", "_y0", ["_rot", 0], ["_upright", false]];
    private _cls = [_list] call _pick;
    if (_cls == "") exitWith { objNull };
    private _p = [_x0, _y0] call _at;
    private _obj = createVehicle [_cls, _p, [], 0, "CAN_COLLIDE"];
    _obj setDir (_d + _rot);
    _obj setPosATL _p;
    if (_upright) then { _obj setVectorUp [0, 0, 1] } else { _obj setVectorUp surfaceNormal _p };
    _obj allowDamage false;
    _placed = _placed + 1;
    _obj
};
// straight wall of segments from A to B (local coordinates)
private _wall = {
    params ["_list", "_a", "_b"];
    private _cls = [_list] call _pick;
    if (_cls == "") exitWith {};
    private _seg = (([_cls] call _dims) select 0) max 2;
    private _len = (_a distance2D _b);
    if (_len < 1) exitWith {};
    private _n = ceil (_len / _seg);
    private _ux = ((_b select 0) - (_a select 0)) / _len;
    private _uy = ((_b select 1) - (_a select 1)) / _len;
    private _rot = (_ux atan2 _uy) - 90;
    for "_i" from 0 to _n - 1 do {
        private _t = (_i + 0.5) * (_len / _n);
        [[_cls], (_a select 0) + _ux * _t, (_a select 1) + _uy * _t, _rot] call _put;
    };
};

// ---------------------------------------------------------------- 1. compound
CQ_compoundSize params ["_W", "_D"];
private _hw = _W / 2;
private _hd = _D / 2;
// clear the ground: hide every terrain object inside the compound (+ 6 m)
private _hidden = 0;
{
    private _p = getPosATL _x;
    private _dx = (_p select 0) - (_o select 0);
    private _dy = (_p select 1) - (_o select 1);
    private _lx = _dx * cos _d - _dy * sin _d;      // local x (right)
    private _ly = _dx * sin _d + _dy * cos _d;      // local y (front)
    if (abs _lx < _hw + 6 && { abs _ly < _hd + 6 }) then { hideObjectGlobal _x; _hidden = _hidden + 1 };
} forEach (nearestTerrainObjects [_o, [], sqrt ((_hw + 6) ^ 2 + (_hd + 6) ^ 2), false, true]);

private _hb = ["Land_HBarrier_Big_F", "Land_HBarrier_5_F", "Land_HBarrier_3_F"];
private _gate = 9;                                  // half width of the vehicle gate
[_hb, [-_hw, -_hd], [_hw, -_hd]] call _wall;        // back
[_hb, [-_hw, -_hd], [-_hw, _hd]] call _wall;        // left
[_hb, [_hw, -_hd], [_hw, _hd]] call _wall;          // right
[_hb, [-_hw, _hd], [-_gate, _hd]] call _wall;       // front, left of the gate
[_hb, [_gate, _hd], [_hw, _hd]] call _wall;         // front, right of the gate
// gate towers (H-barrier bunkers) and short chicane walls outside the gate
[["Land_HBarrierTower_F", "Land_BagBunker_Tower_F"], -_gate - 4, _hd + 1, 0] call _put;
[["Land_HBarrierTower_F", "Land_BagBunker_Tower_F"], _gate + 4, _hd + 1, 0] call _put;
[["Land_CncBarrierMedium4_F", "Land_CncBarrier_F"], -_gate - 10, _hd + 9, 15] call _put;
[["Land_CncBarrierMedium4_F", "Land_CncBarrier_F"], _gate + 10, _hd + 9, -15] call _put;
// guard towers in the corners
{ [["Land_Cargo_Patrol_V1_F", "Land_BagBunker_Tower_F"], (_x select 0) * (_hw - 5), (_x select 1) * (_hd - 5), [180, 0] select ((_x select 1) > 0), true] call _put } forEach [[-1, -1], [1, -1], [-1, 1], [1, 1]];
// tank traps outside the front corners
{ [["Land_CzechHedgehog_01_F", "Land_CzechHedgehog_01_new_F", "Land_CncBarrier_F"], _x select 0, _x select 1, random 90] call _put }
    forEach [[-_hw - 8, _hd + 4], [-_hw - 13, _hd + 8], [-_hw - 6, _hd + 11], [_hw + 8, _hd + 4], [_hw + 13, _hd + 8], [_hw + 6, _hd + 11]];

// back row of buildings, packed from the left, their back 4 m from the back wall
private _row = [
    ["Land_i_Shed_Ind_F", "Land_Shed_Big_F"],
    ["Land_MilOffices_V1_F", "Land_Cargo_HQ_V1_F"],
    ["Land_Cargo_HQ_V1_F", "Land_Cargo_House_V1_F"]
];
private _rowCls = (_row apply { [_x] call _pick }) select { _x != "" };
private _rowW = 0;
{ _rowW = _rowW + (([_x] call _dims) select 0) + 5 } forEach _rowCls;
while { _rowW - 5 > _W - 8 && { count _rowCls > 1 } } do {
    private _drop = _rowCls deleteAt (count _rowCls - 1);
    _rowW = _rowW - (([_drop] call _dims) select 0) - 5;
};
private _cx = -(_rowW - 5) / 2;
private _ops = objNull;
{
    ([_x] call _dims) params ["_bw", "_bl"];
    private _b = [[_x], _cx + _bw / 2, -_hd + 4 + _bl / 2, 0, true] call _put;
    if (_x find "Offices" > -1 || { isNull _ops && { _forEachIndex == 1 } }) then { _ops = _b };
    _cx = _cx + _bw + 5;
} forEach _rowCls;

// friendly commander in the HQ offices: if he dies, the mission is lost
private _fg = createGroup [west, true];
private _fp = [0, -_hd + 10] call _at;
if (!isNull _ops) then {
    private _bp = _ops buildingPos -1;
    if (_bp isNotEqualTo []) then { _fp = _bp select 0 };
};
CQ_friendlyCmd = _fg createUnit ["B_officer_F", _fp, [], 0, "CAN_COLLIDE"];
CQ_friendlyCmd setPosATL _fp;
CQ_friendlyCmd setDir (_d + 180);
CQ_friendlyCmd disableAI "PATH";
CQ_friendlyCmd setUnitPos "UP";
CQ_friendlyCmd setName "Colonel Harlan";
_fg setGroupIdGlobal ["CROSSROAD Actual"];
publicVariable "CQ_friendlyCmd";
CQ_friendlyCmd addEventHandler ["Killed", {
    if (!isNil "CQ_victory" || { !isNil "CQ_defeat" }) exitWith {};
    CQ_defeat = true;
    ["DEFEAT", "The friendly commander has been killed"] call CQ_fnc_announce;
    ["defeat", []] call CQ_fnc_say;
    [] spawn { sleep 12; "EveryoneLost" call BIS_fnc_endMissionServer };
}];

// courtyard: radar + watchtower (front left), flag, medical post (left), 4 squad boxes
[["Land_Radar_Small_F", "Land_TTowerSmall_2_F"], -22, _hd - 14, 0, true] call _put;
[["Land_Cargo_Patrol_V1_F"], -10, _hd - 10, 0, true] call _put;
[["Flag_NATO_F"], 0, 9, 0] call _put;
[["Land_Medevac_house_V1_F", "Land_Cargo_House_V1_F"], -_hw + 9, 2, 90, true] call _put;
CQ_arsenalBoxes = [];
private _boxCls = [["B_CargoNet_01_ammo_F", "B_supplyCrate_F"]] call _pick;
{
    private _p = [-10.5 + 7 * _forEachIndex, 0] call _at;
    private _b = createVehicle [_boxCls, _p, [], 0, "CAN_COLLIDE"];
    _b setDir _d;
    _b setPosATL _p;
    _b allowDamage false;
    [_b, 2, false] call CQ_fnc_crateFill;     // big squad box: not loadable
    _b setVariable ["CQ_squadBox", _x, true];
    CQ_arsenalBoxes pushBack _b;
} forEach ["Alpha", "Bravo", "Charlie", "Delta"];
publicVariable "CQ_arsenalBoxes";
private _sm = createMarker ["cq_sqboxes", [0, 0] call _at];
_sm setMarkerType "mil_box";
_sm setMarkerColor "ColorWEST";
_sm setMarkerSize [0.5, 0.5];
_sm setMarkerText "Equipment";
CQ_arsenalBox = CQ_arsenalBoxes select 0;
publicVariable "CQ_arsenalBox";

// supply corner (right side of the courtyard)
[["Land_Pallets_stack_F"], _hw - 7, -6, 0] call _put;
[["Land_CratesWooden_F"], _hw - 7, 2, 90] call _put;
[["Land_PaperBox_closed_F"], _hw - 10, 6, 15] call _put;
// lights
{ [["Land_PortableLight_double_F"], _x select 0, _x select 1, _x select 2] call _put } forEach [[-_hw + 3, _hd - 3, 225], [_hw - 3, _hd - 3, 135], [-_hw + 3, -_hd + 3, 315], [_hw - 3, -_hd + 3, 45]];

// ---------------------------------------------------------------- 2. vehicle rays
private _blockTypes = ["BUILDING", "HOUSE", "CHURCH", "CHAPEL", "FUELSTATION", "HOSPITAL", "LIGHTHOUSE", "POWER LINES", "TRANSMITTER", "WATERTOWER", "BUNKER", "FORTRESS", "VIEW-TOWER", "RUIN"];
private _softTypes = ["TREE", "SMALL TREE", "BUSH", "ROCK", "ROCKS", "FENCE", "WALL", "HIDE", "STACK", "FOREST BORDER", "FOREST TRIANGLE", "FOREST SQUARE"];
private _spotOk = {
    params ["_p", "_rad"];
    !surfaceIsWater _p
    && { (_p isFlatEmpty [-1, -1, 0.2, (_rad max 3) min 12, 0, false, objNull]) isNotEqualTo [] }
    && { (nearestTerrainObjects [_p, _blockTypes, _rad + 2, false, true]) isEqualTo [] }
    && { ((nearestObjects [_p, ["Building", "LandVehicle", "Air", "Thing", "StaticWeapon"], _rad + 2]) select { !(_x isKindOf "HeliH") && { !isObjectHidden _x } }) isEqualTo [] }
};
private _clearSoft = { params ["_p", "_rad"]; { hideObjectGlobal _x } forEach (nearestTerrainObjects [_p, _softTypes, _rad + 1, false, true]) };

// every vehicle with its footprint, shared out over the rays (largest types first so the
// big ones spread evenly), then each ray sorted from the smallest to the largest
private _isAir = { params ["_c"]; _c isKindOf "Air" };
private _all = [];
{
    _x params ["_cls", "_role", ["_k", 1]];
    ([_cls] call _dims) params ["_w", "_l"];
    for "_i" from 1 to _k do { _all pushBack [_cls, _role, _w, _l, _w * _l, [_cls] call _isAir] };
} forEach CQ_baseVehicles;
_all = [_all, [], { _x select 4 }, "DESCEND"] call BIS_fnc_sortBy;
private _nRays = count CQ_rayStarts;
private _rays = [];
for "_i" from 1 to _nRays do { _rays pushBack [] };
{
    private _best = 0;
    { if (count _x < count (_rays select _best)) then { _best = _forEachIndex } } forEach _rays;
    (_rays select _best) pushBack _x;
} forEach _all;
_rays = _rays apply { [_x, [], { _x select 4 }, "ASCEND"] call BIS_fnc_sortBy };

CQ_baseSpots = createHashMap;
CQ_loadZones = [];
CQ_crateSpots = [];
private _names = ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot"];
private _ang = _d;                               // rows run along the base axis
private _vd = _ang + 90;                         // vehicles parked perpendicular to the row
{
    private _ray = _x;
    private _ri = _forEachIndex;
    private _s0 = CQ_rayStarts param [_ri, [0, _hd + 8] call _at];
    _s0 = [_s0 select 0, _s0 select 1, 0];
    private _at2 = { params ["_r"]; private _p = _s0 getPos [_r, _ang]; [_p select 0, _p select 1, 0] };
    private _lbl = createMarker [format ["cq_row_%1", _ri + 1], _s0];
    _lbl setMarkerType "mil_start";
    _lbl setMarkerColor "ColorWEST";
    _lbl setMarkerSize [0.5, 0.5];
    _lbl setMarkerDir _ang;
    _lbl setMarkerText (_names select _ri);
    private _r = 0;
    {
        _x params ["_cls", "_role", "_w", "_l", "", "_air"];
        private _half = if (_air) then { (_w max _l) / 2 } else { _w / 2 };   // extent along the row
        private _rad = ((_w max _l) / 2) + 1;
        private _p = [];
        private _tries = 0;
        while { _p isEqualTo [] && { _tries < 40 } } do {
            private _c = [_r + _half] call _at2;
            if ([_c, _rad] call _spotOk) then { _p = _c } else { _r = _r + 2; _tries = _tries + 1 };
        };
        if (_p isEqualTo []) then { ["Base row %1: no spot for %2", [_ri + 1, _cls]] call CQ_fnc_log; continue };
        [_p, _rad] call _clearSoft;
        if (_air) then { (createVehicle ["Land_HelipadSquare_F", _p, [], 0, "CAN_COLLIDE"]) setDir _vd };
        CQ_baseSpots set [_role, (CQ_baseSpots getOrDefault [_role, []]) + [[_p, _vd]]];
        _r = _r + 2 * _half + CQ_raySpacing;
    } forEach _ray;
    // crate dispenser + loadout zone at the end of the row (drawn spot, or further if the
    // row is longer)
    private _dp = CQ_dispensers param [_ri, []];
    private _dDist = if (_dp isEqualTo []) then { 0 } else { (_s0 distance2D _dp) };
    _dDist = _dDist max (_r + CQ_loadZoneRadius);
    private _lz = [_dDist] call _at2;
    [_lz, CQ_loadZoneRadius + 5] call _clearSoft;
    CQ_loadZones pushBack _lz;
    { (createVehicle ["RoadCone_L_F", _lz getPos [CQ_loadZoneRadius - 1, _ang + _x], [], 0, "CAN_COLLIDE"]) allowDamage false } forEach [45, 135, 225, 315];
    for "_k" from 0 to CQ_dispenserCrates - 1 do {
        private _cp = (_lz getPos [CQ_loadZoneRadius + 2.5, _ang]) getPos [(_k - (CQ_dispenserCrates - 1) / 2) * 3, _vd];
        CQ_crateSpots pushBack [_cp select 0, _cp select 1, 0];
    };
    ["Base row %1: %2 m, %3, dispenser at %4 m", [_ri + 1, round _r, (_ray apply { _x select 0 }) joinString " < ", round _dDist]] call CQ_fnc_log;
} forEach _rays;
private _dm = createMarker ["cq_crates", (CQ_loadZones select 0)];
_dm setMarkerType "loc_rearm";
_dm setMarkerColor "ColorWEST";
_dm setMarkerText "Crates & loadout";
publicVariable "CQ_loadZones";

// repair stations
CQ_repairPoints = [];
{
    private _rp = [_x select 0, _x select 1, 0];
    [_rp, 8] call _clearSoft;
    // repair depot (free object, Tanks platform update) facing the runway centre line:
    // vehicles stop between the depot and the runway
    private _face = _ang;
    private _ils = getArray (configFile >> "CfgWorlds" >> worldName >> "ilsPosition");
    private _ilsDir = getArray (configFile >> "CfgWorlds" >> worldName >> "ilsDirection");
    if (count _ils >= 2 && { count _ilsDir >= 3 }) then {
        private _h = (_ilsDir select 0) atan2 (_ilsDir select 2);
        private _ip = [_ils select 0, _ils select 1, 0];
        private _rel = _rp vectorDiff _ip;
        private _t = (_rel select 0) * sin _h + (_rel select 1) * cos _h;
        _face = _rp getDir (_ip vectorAdd [_t * sin _h, _t * cos _h, 0]);
    };
    private _free = ["Land_RepairDepot_01_tan_F", "Land_RepairDepot_01_green_F", "Land_RepairDepot_01_civ_F"];
    private _st = [_free + ["B_Slingload_01_Repair_F", "Land_Cargo20_military_green_F"], _free] call _pick;
    if (_st != "") then {
        private _sp = _rp getPos [7, _face + 180];
        _sp = [_sp select 0, _sp select 1, 0];
        [_sp, 6] call _clearSoft;
        private _s = createVehicle [_st, _sp, [], 0, "CAN_COLLIDE"];
        _s setDir (_face + CQ_repairDepotRot);
        _s setPosATL _sp;
        _s setVectorUp surfaceNormal _sp;
        _s allowDamage false;
        ["Repair station %1: %2 facing %3 deg", [_forEachIndex + 1, _st, round _face]] call CQ_fnc_log;
    };
    { (createVehicle ["RoadCone_L_F", _rp getPos [CQ_repairRadius - 1, _ang + _x], [], 0, "CAN_COLLIDE"]) allowDamage false } forEach [45, 135, 225, 315];
    CQ_repairPoints pushBack _rp;
    private _rm = createMarker [format ["cq_repair_%1", _forEachIndex + 1], _rp];
    _rm setMarkerType "loc_repair";
    _rm setMarkerColor "ColorWEST";
} forEach CQ_repairSpots;
publicVariable "CQ_repairPoints";

// ---------------------------------------------------------------- vehicle shop
// LZ + terminal west of the compound (CQ_shopPos in the settings overrides the LZ spot)
private _lzWant = if (isNil "CQ_shopPos") then { [-_hw - 30, 8] call _at } else { [CQ_shopPos select 0, CQ_shopPos select 1, 0] };
CQ_shopLZ = [_lzWant, 9, 40] call CQ_fnc_clearPos;
if (CQ_shopLZ isEqualTo []) then { CQ_shopLZ = _lzWant };
CQ_shopLZ = [CQ_shopLZ select 0, CQ_shopLZ select 1, 0];
[CQ_shopLZ, 11] call _clearSoft;
CQ_shopDir = _d;
(createVehicle ["Land_HelipadCircle_F", CQ_shopLZ, [], 0, "CAN_COLLIDE"]) setDir _d;
{ (createVehicle ["RoadCone_L_F", CQ_shopLZ getPos [10, _d + _x], [], 0, "CAN_COLLIDE"]) allowDamage false } forEach [0, 90, 180, 270];
private _tp = CQ_shopLZ getPos [14, (_o getDir CQ_shopLZ) + 180];
_tp = [_tp select 0, _tp select 1, 0];
private _tblCls = [["Land_CampingTable_F"]] call _pick;
if (_tblCls != "") then {
    private _tb = createVehicle [_tblCls, _tp, [], 0, "CAN_COLLIDE"];
    _tb setDir (_tp getDir CQ_shopLZ);
    _tb allowDamage false;
};
private _termCls = [["Land_DataTerminal_01_F", "Land_Laptop_unfolded_F", "Land_SatellitePhone_F"]] call _pick;
CQ_shopTerminal = createVehicle [_termCls, _tp, [], 0, "CAN_COLLIDE"];
CQ_shopTerminal setDir ((_tp getDir CQ_shopLZ) + 180);
if (_termCls != "Land_DataTerminal_01_F" && { _tblCls != "" }) then { CQ_shopTerminal setPosATL [_tp select 0, _tp select 1, 0.82] };
CQ_shopTerminal allowDamage false;
CQ_shopTerminal enableSimulationGlobal false;
publicVariable "CQ_shopTerminal";
publicVariable "CQ_shopLZ";
private _shm = createMarker ["cq_shop", CQ_shopLZ];
_shm setMarkerType "c_car";
_shm setMarkerColor "ColorWEST";
_shm setMarkerText "Vehicle shop";
["Vehicle shop at %1 (terminal %2)", [mapGridPosition CQ_shopLZ, _termCls]] call CQ_fnc_log;

// ---------------------------------------------------------------- 3. defences, respawn, markers
CQ_baseDefs = [];
{
    private _ang = _d + _x;
    private _want = _o getPos [CQ_baseDefRadius, _ang];
    // keep off the runway: at least CQ_runwayClear m from its centre line (drones take off there)
    private _ils = getArray (configFile >> "CfgWorlds" >> worldName >> "ilsPosition");
    private _ilsDir = getArray (configFile >> "CfgWorlds" >> worldName >> "ilsDirection");
    if (count _ils >= 2 && { count _ilsDir >= 3 }) then {
        private _h = (_ilsDir select 0) atan2 (_ilsDir select 2);
        private _rel = _want vectorDiff [_ils select 0, _ils select 1, 0];
        private _off = (_rel select 0) * cos _h - (_rel select 1) * sin _h;      // signed distance to the centre line
        if (abs _off < CQ_runwayClear) then { _want = [] };    // too close to the runway, its taxiways and aprons: no spot here
    };
    if (_want isEqualTo []) then { ["Base defence spot %1 skipped: too close to the runway", [_forEachIndex + 1]] call CQ_fnc_log; continue };
    private _p = [_want, 7, 40] call CQ_fnc_clearPos;
    if (_p isEqualTo []) then { continue };
    if (count _ils >= 2 && { count _ilsDir >= 3 }) then {
        private _h2 = (_ilsDir select 0) atan2 (_ilsDir select 2);
        private _rel2 = _p vectorDiff [_ils select 0, _ils select 1, 0];
        if (abs ((_rel2 select 0) * cos _h2 - (_rel2 select 1) * sin _h2) < CQ_runwayClear) then {
            ["Base defence spot %1 skipped: still too close to the runway", [_forEachIndex + 1]] call CQ_fnc_log;
            _p = [];
        };
    };
    if (_p isEqualTo []) then { continue };
    CQ_baseDefs pushBack createHashMapFromArray [["pos", _p], ["dir", _ang], ["objs", []], ["lostT", -1]];
} forEach CQ_baseDefAngles;
{ [_x] call CQ_fnc_baseDefBuild } forEach CQ_baseDefs;

CQ_musterPos = [0, -6] call _at;
publicVariable "CQ_musterPos";
private _respawn = createMarker ["respawn_west", CQ_musterPos];
_respawn setMarkerType "Empty";
private _hq = createMarker ["cq_base", _o];
_hq setMarkerType "b_hq";
_hq setMarkerColor "ColorWEST";
_hq setMarkerText "Main base";
private _zone = createMarker ["cq_base_zone", _o];
_zone setMarkerShape "ELLIPSE";
_zone setMarkerSize [CQ_baseRadius, CQ_baseRadius];
_zone setMarkerBrush "Border";
_zone setMarkerColor "ColorWEST";

["Base built at %1 (front %2 deg): %3 pieces, %4 terrain objects hidden, %5 rows, %6 repair stations",
    [mapGridPosition _o, round _d, _placed, _hidden, _nRays, count CQ_repairPoints]] call CQ_fnc_log;
