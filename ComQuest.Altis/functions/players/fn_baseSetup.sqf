/*
    CQ_fnc_baseSetup  (server)
    Builds the player base from the zones drawn on the map (cfg/settings.sqf):
    1. HQ compound at CQ_basePos, front toward CQ_baseDir (CQ_compoundSize), on ground levelled
       first (CQ_baseLevel), H-barrier walls, vehicle gate flanked by two H-barrier towers, a
       pedestrian door on the left (toward the shop), guard towers in the corners:
         back row     ops offices | cargo HQ (friendly commander inside, centred) | medical post
         centre       plaza with the flag and lamps, a clear boulevard to the gate (muster point)
         sides        4 squad bays (Alpha, Bravo left; Charlie, Delta right): camo net over the
                      squad equipment box (arsenal + squad resupply), table, chairs, light
         front        radar (left), supply stack (right), billboard right of the gate
       Terrain objects inside the compound are hidden.
    2. Vehicle zone: 4 parallel rows starting at CQ_rayStarts and running along CQ_baseDir,
       laid out as if the quota vehicles (CQ_baseVehicles) were parked there (no vehicle is
       placed any more: they come from the vehicle depots), only to place the dispensers.
    3. At the far end of each row a crate dispenser (CQ_dispensers, pushed further if the row
       is longer): CQ_dispenserCrates ready-filled loadable crates + a loadout zone.
    4. Repair stations at CQ_repairSpots (CQ_fnc_baseRepairTick), each one also a vehicle
       depot with its own helipad behind it (CQ_depots, CQ_fnc_depotUi / CQ_fnc_depotSpawn).
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

// ---------------------------------------------------------------- 1. compound (v2, "Camp Harlan")
// Layout in compound coordinates (x right, y toward the gate / CQ_baseDir), CQ_compoundSize:
//
//      tower ---- H-barrier ---- [gate tower] GATE [gate tower] ---- billboard - supply - tower
//        radar                         boulevard (lamps)
//   [ALPHA bay]                     muster / respawn                         [CHARLIE bay]
//  side door  ->                    plaza + flag (lamps)
//   [BRAVO bay]                                                              [DELTA bay]
//        MilOffices (ops)        Cargo HQ (commander)        Medical post
//      tower ------------------------- H-barrier ------------------------------- tower
//
// The ground of the compound is levelled first (setTerrainHeight, blended over CQ_baseLevelBlend
// m) so every building sits flush on a flat floor and the walls run straight.
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

// level the ground: every terrain grid point of the compound (+ the blend band) moved toward the
// compound's mean height, fully inside, fading out across CQ_baseLevelBlend m outside
if (CQ_baseLevel) then {
    private _g = (getTerrainInfo select 3) max 1;
    private _blend = CQ_baseLevelBlend;
    private _reach = sqrt ((_hw + _blend) ^ 2 + (_hd + _blend) ^ 2);
    private _pts = [];
    private _sum = 0; private _n = 0;
    for "_gx" from (floor (((_o select 0) - _reach) / _g)) to (ceil (((_o select 0) + _reach) / _g)) do {
        for "_gy" from (floor (((_o select 1) - _reach) / _g)) to (ceil (((_o select 1) + _reach) / _g)) do {
            private _px = _gx * _g; private _py = _gy * _g;
            private _dx = _px - (_o select 0); private _dy = _py - (_o select 1);
            private _lx = abs (_dx * cos _d - _dy * sin _d);
            private _ly = abs (_dx * sin _d + _dy * cos _d);
            private _out = ((_lx - _hw - 4) max 0) max ((_ly - _hd - 4) max 0);   // metres outside the walls (+4)
            if (_out < _blend) then {
                private _z = getTerrainHeight [_px, _py];
                _pts pushBack [_px, _py, _z, _out];
                if (_out == 0) then { _sum = _sum + _z; _n = _n + 1 };
            };
        };
    };
    if (_n > 0) then {
        private _flat = _sum / _n;
        private _new = _pts apply {
            _x params ["_px", "_py", "_z", "_out"];
            private _w = 1 - (_out / _blend);
            _w = _w * _w * (3 - 2 * _w);                  // smoothstep: no step at the edge of the band
            [_px, _py, _z + (_flat - _z) * _w]
        };
        setTerrainHeight [_new, true];
        ["Base: ground levelled at %1 m (%2 grid points, grid %3 m)", [_flat toFixed 1, count _new, _g]] call CQ_fnc_log;
    };
};

private _hb = ["Land_HBarrier_Big_F", "Land_HBarrier_5_F", "Land_HBarrier_3_F"];
private _gate = 10;                                 // half width of the vehicle gate
private _door = [4, 10];                            // pedestrian door in the left wall (y from / to), toward the shop
[_hb, [-_hw, -_hd], [_hw, -_hd]] call _wall;        // back
[_hb, [-_hw, -_hd], [-_hw, _door select 0]] call _wall;    // left, behind the door
[_hb, [-_hw, _door select 1], [-_hw, _hd]] call _wall;     // left, in front of the door
[_hb, [_hw, -_hd], [_hw, _hd]] call _wall;          // right
[_hb, [-_hw, _hd], [-_gate, _hd]] call _wall;       // front, left of the gate
[_hb, [_gate, _hd], [_hw, _hd]] call _wall;         // front, right of the gate
// gate: two H-barrier towers, a chicane of concrete blocks outside, bar gate lights
[["Land_HBarrierTower_F", "Land_BagBunker_Tower_F"], -_gate - 4, _hd + 1, 0, true] call _put;
[["Land_HBarrierTower_F", "Land_BagBunker_Tower_F"], _gate + 4, _hd + 1, 0, true] call _put;
[["Land_CncBarrierMedium4_F", "Land_CncBarrier_F"], -_gate - 10, _hd + 10, 15] call _put;
[["Land_CncBarrierMedium4_F", "Land_CncBarrier_F"], _gate + 10, _hd + 10, -15] call _put;
// side door: bag fence screen outside it
[["Land_BagFence_Long_F"], -_hw - 3, ((_door select 0) + (_door select 1)) / 2, 90] call _put;
[["Land_BagFence_Round_F"], -_hw - 2.2, (_door select 1) + 1.2, 135] call _put;
[["Land_BagFence_Round_F"], -_hw - 2.2, (_door select 0) - 1.2, 45] call _put;
// guard towers in the corners
{ [["Land_Cargo_Patrol_V1_F", "Land_BagBunker_Tower_F"], (_x select 0) * (_hw - 5), (_x select 1) * (_hd - 5), [180, 0] select ((_x select 1) > 0), true] call _put } forEach [[-1, -1], [1, -1], [-1, 1], [1, 1]];

// back row: ops offices | command post (the friendly commander's building, centred) | medical
private _cmdCls = [["Land_Cargo_HQ_V1_F", "Land_MilOffices_V1_F"]] call _pick;
private _opsCls = [["Land_MilOffices_V1_F", "Land_Cargo_House_V1_F"]] call _pick;
private _medCls = [["Land_Medevac_house_V1_F", "Land_Cargo_House_V1_F"]] call _pick;
private _ops = objNull;
if (_cmdCls != "") then {
    ([_cmdCls] call _dims) params ["_cw", "_cl"];
    _ops = [[_cmdCls], 0, -_hd + 5 + _cl / 2, 0, true] call _put;
    if (_opsCls != "") then {
        ([_opsCls] call _dims) params ["_ow", "_ol"];
        private _ox = -(_cw / 2) - 7 - (_ow / 2);
        if (_ox - _ow / 2 > -_hw + 4) then { [[_opsCls], _ox, -_hd + 5 + _ol / 2, 0, true] call _put };
    };
    if (_medCls != "") then {
        ([_medCls] call _dims) params ["_mw", "_ml"];
        private _mx = (_cw / 2) + 9 + (_mw / 2);
        if (_mx + _mw / 2 < _hw - 4) then { [[_medCls], _mx, -_hd + 5 + _ml / 2, 0, true] call _put };
    };
};

// friendly commander in the command post, standing in the middle of its floor: if he dies,
// the mission is lost. Only enemy fire can hurt him.
private _fg = createGroup [west, true];
private _fp = [0, -_hd + 10] call _at;
CQ_friendlyCmd = _fg createUnit ["B_officer_F", _fp, [], 0, "CAN_COLLIDE"];
CQ_friendlyCmd setPosATL _fp;
CQ_friendlyCmd setDir (_d + 180);
CQ_friendlyCmd disableAI "PATH";
CQ_friendlyCmd setUnitPos "UP";
CQ_friendlyCmd setName "Colonel Harlan";
_fg setGroupIdGlobal ["CROSSROAD Actual"];
publicVariable "CQ_friendlyCmd";
CQ_cmdPost = _ops;      // the enemy assault breaches this building (CQ_fnc_assaultTick)
// floor height = lowest building position (the roof ones are higher), then snapped onto the
// floor surface right under the building's centre, once the building's geometry is ready
if (!isNull _ops) then {
    [_ops, _d] spawn {
        params ["_b", "_d"];
        sleep 1;
        private _bps = (_b buildingPos -1) apply { AGLToASL _x };
        private _c = _b modelToWorldWorld [0, 0, 0];
        private _z = if (_bps isEqualTo []) then { (_c select 2) + 1 } else { selectMin (_bps apply { _x select 2 }) };
        private _hits = lineIntersectsSurfaces [[_c select 0, _c select 1, _z + 1.2], [_c select 0, _c select 1, _z - 1.5], CQ_friendlyCmd, objNull, true, 1, "GEOM", "FIRE"];
        if (_hits isNotEqualTo []) then { _z = ((_hits select 0) select 0) select 2 };
        CQ_friendlyCmd setPosASL [_c select 0, _c select 1, _z + 0.05];
        CQ_friendlyCmd setDir (_d + 180);
        ["Friendly commander in %1 at %2 (floor %3 m above ground)", [typeOf _b, mapGridPosition _b, ((ASLToATL [_c select 0, _c select 1, _z]) select 2) toFixed 2]] call CQ_fnc_log;
    };
};
CQ_friendlyCmd addEventHandler ["HandleDamage", {
    params ["_u", "_sel", "_dmg", "_src", "", "_idx", "_inst"];
    private _who = [_inst, _src] select (isNull _inst);
    if (!isNull _who && { !(_who isKindOf "CAManBase") }) then { _who = effectiveCommander _who };
    if (isNull _who || { (side group _who) getFriend west >= 0.6 }) then {
        if (_sel == "") then { damage _u } else { _u getHitIndex _idx }
    } else { _dmg }
}];
CQ_friendlyCmd addEventHandler ["Killed", {
    if (!isNil "CQ_victory" || { !isNil "CQ_defeat" }) exitWith {};
    CQ_defeat = true;
    ["DEFEAT", "The friendly commander has been killed"] call CQ_fnc_announce;
    ["defeat", []] call CQ_fnc_say;
    [] spawn { sleep 12; "EveryoneLost" call BIS_fnc_endMissionServer };
}];

// plaza in front of the command post: flag, four lamps; the boulevard to the gate is kept clear
[["Flag_NATO_F"], 0, 2, 0, true] call _put;
{ [["Land_LampHalogen_F", "Land_LampShabby_F"], _x select 0, _x select 1, _x select 2, true] call _put } forEach [[-10, -6, 45], [10, -6, -45], [-10, 12, 135], [10, 12, -135]];
{ [["Land_LampShabby_F", "Land_LampHalogen_F"], _x select 0, _x select 1, _x select 2, true] call _put } forEach [[-_gate + 1, _hd - 10, 90], [_gate - 1, _hd - 10, -90]];

// squad bays: Alpha / Bravo along the left wall, Charlie / Delta along the right one, each a
// camo net over its equipment box (arsenal + squad resupply), a briefing table, chairs, a light
// and a bag fence at its back; open toward the plaza
CQ_arsenalBoxes = [];
private _boxCls = [["B_CargoNet_01_ammo_F", "B_supplyCrate_F"]] call _pick;
private _bayX = _hw - 13;
{
    _x params ["_sq", "_side", "_by"];
    private _bx = _side * _bayX;
    private _in = -_side;                               // toward the plaza (x direction)
    private _face = [270, 90] select (_in > 0);         // facing the plaza
    [["CamoNet_BLUFOR_open_F", "CamoNet_BLUFOR_F"], _bx, _by, 90, true] call _put;
    private _p = [_bx + _in * 1.5, _by] call _at;
    private _b = createVehicle [_boxCls, _p, [], 0, "CAN_COLLIDE"];
    _b setDir (_d + _face);
    _b setPosATL _p;
    _b setVectorUp [0, 0, 1];
    _b allowDamage false;
    [_b, 2, false] call CQ_fnc_crateFill;     // big squad box: not loadable
    _b setVariable ["CQ_squadBox", _sq, true];
    CQ_arsenalBoxes pushBack _b;
    [["Land_CampingTable_F"], _bx - _in * 3, _by + 3.5, _face, true] call _put;
    { [["Land_CampingChair_V2_F", "Land_CampingChair_V1_F"], _bx - _in * (3 + (_x select 0)), _by + 3.5 + (_x select 1), _face + (_x select 2), true] call _put } forEach [[1.2, 0.6, 180], [1.2, -0.6, 180], [-1.2, 0, 0]];
    [["Land_PortableLight_single_F", "Land_PortableLight_double_F"], _bx - _in * 5.5, _by - 5, _face + 20, true] call _put;
    [["Land_BagFence_Long_F"], _bx - _in * 7.5, _by - 3, 90, true] call _put;
    [["Land_BagFence_Long_F"], _bx - _in * 7.5, _by + 3, 90, true] call _put;
    [["Land_Pallets_stack_F", "Land_Pallet_F"], _bx - _in * 5, _by + 6.5, 0, true] call _put;
    private _bm = createMarker [format ["cq_bay_%1", _sq], [_bx, _by] call _at];
    _bm setMarkerType "mil_box";
    _bm setMarkerColor "ColorWEST";
    _bm setMarkerSize [0.5, 0.5];
    _bm setMarkerText _sq;
} forEach [["Alpha", -1, 20], ["Bravo", -1, -7], ["Charlie", 1, 20], ["Delta", 1, -7]];
publicVariable "CQ_arsenalBoxes";
CQ_arsenalBox = CQ_arsenalBoxes select 0;
publicVariable "CQ_arsenalBox";

// front corners: radar (left), supply stack (right), between the bays and the front towers
[["Land_Radar_Small_F", "Land_TTowerSmall_2_F"], -_hw + 18, _hd - 8, 0, true] call _put;
[["Land_Pallets_stack_F"], _hw - 10, _hd - 7, 0, true] call _put;
[["Land_CratesWooden_F"], _hw - 16, _hd - 6, 90, true] call _put;
[["Land_PaperBox_closed_F"], _hw - 13, _hd - 10, 15, true] call _put;
// lights in the corners
{ [["Land_PortableLight_double_F"], _x select 0, _x select 1, _x select 2, true] call _put } forEach [[-_hw + 3, -_hd + 3, 315], [_hw - 3, -_hd + 3, 45]];

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
private _ang = _d;                               // rows run along the base axis
private _vd = _ang + 90;                         // vehicles parked perpendicular to the row
{
    private _ray = _x;
    private _ri = _forEachIndex;
    private _s0 = CQ_rayStarts param [_ri, [0, _hd + 8] call _at];
    _s0 = [_s0 select 0, _s0 select 1, 0];
    private _at2 = { params ["_r"]; private _p = _s0 getPos [_r, _ang]; [_p select 0, _p select 1, 0] };
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
        CQ_baseSpots set [_role, (CQ_baseSpots getOrDefault [_role, []]) + [[_p, _vd]]];
        _r = _r + 2 * _half + CQ_raySpacing;
    } forEach _ray;
    // no loading zone or crate dispenser any more: vehicles are kitted on the depot helipads
    // next to the repair depots (squad autofill, vehicle arsenal box)
    ["Base row %1: %2 m, %3", [_ri + 1, round _r, (_ray apply { _x select 0 }) joinString " < "]] call CQ_fnc_log;
} forEach _rays;
publicVariable "CQ_loadZones";   // empty: no loading zones

// repair stations
CQ_repairPoints = [];
CQ_depots = [];
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
        // vehicle depot: the station furniture is the terminal, its helipad stands behind it
        // (away from the runway); depot vehicles spawn there
        private _pw = _rp getPos [CQ_depotPadGap, _face + 180];
        private _pad = [[_pw select 0, _pw select 1, 0], 9, 30, [_s]] call CQ_fnc_clearPos;
        if (_pad isEqualTo []) then { _pad = _pw };
        _pad = [_pad select 0, _pad select 1, 0];
        [_pad, 11] call _clearSoft;
        (createVehicle ["Land_HelipadSquare_F", _pad, [], 0, "CAN_COLLIDE"]) setDir _face;
        CQ_depots pushBack [_s, _pad, _face];
        ["Vehicle depot %1: pad at %2", [_forEachIndex + 1, mapGridPosition _pad]] call CQ_fnc_log;
    };
    { (createVehicle ["RoadCone_L_F", _rp getPos [CQ_repairRadius - 1, _ang + _x], [], 0, "CAN_COLLIDE"]) allowDamage false } forEach [45, 135, 225, 315];
    CQ_repairPoints pushBack _rp;
    private _rm = createMarker [format ["cq_repair_%1", _forEachIndex + 1], _rp];
    _rm setMarkerType "loc_repair";
    _rm setMarkerColor "ColorWEST";
    _rm setMarkerText "Repair & vehicle depot";
} forEach CQ_repairSpots;

// No vehicle arsenal boxes any more: vehicles are kitted with the squad autofill on the depot
// helipads; players gear up at the squad boxes in the compound
CQ_vehBoxes = [];
publicVariable "CQ_vehBoxes";
CQ_vehBoxesDone = true; publicVariable "CQ_vehBoxesDone";

// Base defences from the layout drawn on the map picker (CQ_baseLayoutObjs, CQ_baseLayoutHesco)
private _nH = 0;
{
    _x params ["_hc", "_hl", "_pts"];
    for "_i" from 1 to (count _pts) - 1 do {
        private _a = (_pts select (_i - 1)) + [0]; private _b = (_pts select _i) + [0];
        private _len = _a distance2D _b;
        private _sd = _a getDir _b;
        private _n = ceil (_len / _hl);
        for "_k" from 0 to _n - 1 do {
            private _f = (_k + 0.5) / _n;
            private _p = [(_a select 0) + ((_b select 0) - (_a select 0)) * _f, (_a select 1) + ((_b select 1) - (_a select 1)) * _f, 0];
            [_p, 4] call _clearSoft;
            private _o = createVehicle [_hc, [0, 0, 0], [], 0, "CAN_COLLIDE"];
            _o setDir (_sd + 90);
            _o setPosATL _p;
            _o setVectorUp surfaceNormal _p;
            _o allowDamage false;
            _nH = _nH + 1;
        };
    };
} forEach CQ_baseLayoutHesco;
{
    _x params ["_oc", "_op", "_od"];
    private _p = [_op select 0, _op select 1, 0];
    [_p, 3] call _clearSoft;
    private _o = createVehicle [_oc, [0, 0, 0], [], 0, "CAN_COLLIDE"];
    _o setDir _od;
    _o setPosATL _p;
    if (_o isKindOf "StaticWeapon") then {
        createVehicleCrew _o;
        (group gunner _o) enableDynamicSimulation false;
        (group gunner _o) setBehaviour "AWARE";
        (group gunner _o) setCombatMode "RED";
    } else { _o allowDamage false };
} forEach CQ_baseLayoutObjs;
["Base layout: %1 Hesco pieces, %2 objects", [_nH, count CQ_baseLayoutObjs]] call CQ_fnc_log;

publicVariable "CQ_repairPoints";
publicVariable "CQ_depots";

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
publicVariable "CQ_shopDir";
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

// billboard with the mission visual, against the front wall just right of the gate (along the
// H-barriers), picture facing the courtyard
private _bbP = [_gate + 12, _hd - 3] call _at;
_bbP = [_bbP select 0, _bbP select 1, 0];
// a billboard model whose picture can be replaced (hiddenSelections), else a plain 10 m user
// texture panel standing upright
private _bbC = [["Land_Billboard_F", "Land_Billboard_02_blank_F"]] call _pick;
if (_bbC != "" && { (getArray (configFile >> "CfgVehicles" >> _bbC >> "hiddenSelections")) isEqualTo [] }) then { _bbC = "UserTexture10m_F" };
if (_bbC != "") then {
    { _x hideObjectGlobal true } forEach (nearestTerrainObjects [_bbP, ["TREE", "SMALL TREE", "BUSH", "ROCK", "HIDE", "FENCE", "WALL"], 5, false, true]);
    private _bb = createVehicle [_bbC, _bbP, [], 0, "CAN_COLLIDE"];
    _bb setDir (_d + ([0, 180] select CQ_billboardFlip));
    _bb setPosATL _bbP;
    _bb allowDamage false;
    _bb setObjectTextureGlobal [0, "media\billboard.jpg"];
    ["Billboard (%1) at %2", [_bbC, mapGridPosition _bb]] call CQ_fnc_log;
};

// muster point (start + respawn): open ground in the front half of the courtyard, right of the
// flag, never inside or against a building (nearest clear spot if something stands there)
private _mw = [0, 18] call _at;          // on the boulevard, between the plaza and the gate
CQ_musterPos = [_mw, 4, 24] call CQ_fnc_clearPos;
if (CQ_musterPos isEqualTo []) then { CQ_musterPos = _mw };
CQ_musterPos = [CQ_musterPos select 0, CQ_musterPos select 1, 0];
["Muster point (start + respawn) %1 m from the wanted spot", [round (CQ_musterPos distance2D _mw)]] call CQ_fnc_log;
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

// Map footprints: buildings created by script are not drawn on the map (only the terrain's own
// buildings are), so every base building and wall gets a filled rectangle marker of its real
// footprint, like the map's own buildings. Done once, a few seconds after the base is placed.
[] spawn {
    sleep 5;
    private _n = 0;
    {
        private _o = _x;
        if (getObjectType _o != 8) then { continue };                             // mission objects only
        if (!(_o isKindOf "Building") && { !(_o isKindOf "House") } && { !(_o isKindOf "Strategic") }) then { continue };
        if (_o isKindOf "AllVehicles" || { _o isKindOf "ReammoBox_F" } || { "helipad" in toLower typeOf _o } || { "light" in toLower typeOf _o }) then { continue };
        (boundingBoxReal _o) params ["_a", "_b"];
        private _w = ((_b select 0) - (_a select 0)) / 2;
        private _l = ((_b select 1) - (_a select 1)) / 2;
        if (_w < 0.6 && { _l < 0.6 }) then { continue };                          // signs, props
        if ((_b select 2) - (_a select 2) < 0.8) then { continue };              // flat things
        private _m = createMarker [format ["cq_bld_%1", _n], getPosATL _o];
        _m setMarkerShape "RECTANGLE";
        _m setMarkerSize [_w, _l];
        _m setMarkerDir getDir _o;
        _m setMarkerBrush "SolidFull";
        _m setMarkerColor "ColorBlack";
        _m setMarkerAlpha 0.55;
        _n = _n + 1;
    } forEach (CQ_basePos nearObjects ["All", CQ_baseRadius + 150]);
    ["Base map footprints: %1 buildings and walls drawn", [_n]] call CQ_fnc_log;
};
