/*
    CQ_fnc_baseSetup  (server)  -  CAMP HARLAN v4 (drawn perimeter)
    The outer wall follows CQ_basePerimeter (corners drawn on the map, any shape), with the gates
    of CQ_baseGates; the ground inside is levelled first (CQ_baseLevel). Inside:
      the keep      inner wall (CQ_compoundSize, centred on CQ_basePos, facing CQ_baseDir: class
                    change / arsenal zone), keep gate toward the yard and the apron, side doors;
                    command post with the friendly commander (CQ_cmdPost), ops, medical, plaza +
                    flag, 4 squad bays (squad boxes), muster point, billboard
      motor pool    4 free-vehicle depots ("ground") against the runway-side wall + repair points,
                    vehicle shop LZ by the entry control point
      aviation      4 helipads along the runway-side wall: Falcon depots ("air"), repair points
      UAV field     MAGPIE's Darter pads (CQ_magPadPos / CQ_magPadDir, used by CQ_fnc_magInit)
      defences      sangars on the corners, watchtowers, floodlights, 4 crewed defence spots
    Zones are laid out in the base frame: u metres along the front edge (CQ_basePerimeter corner
    CQ_baseFrontStart to the next one, the runway side), v metres inward from it.
    Every class is checked (exists, no DLC); a missing one falls back or is skipped and logged.
*/
if (!isServer) exitWith {};

private _o = CQ_basePos;
private _d = CQ_baseDir;
publicVariable "CQ_basePos";
publicVariable "CQ_baseDir";

// keep frame: x right, y toward CQ_baseDir, origin = keep centre
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
// ================================================================= the perimeter
private _poly = CQ_basePerimeter apply { [_x select 0, _x select 1, 0] };
private _nP = count _poly;
private _area = 0;
for "_i" from 0 to _nP - 1 do {
    private _a = _poly select _i; private _b = _poly select ((_i + 1) mod _nP);
    _area = _area + (_a select 0) * (_b select 1) - (_b select 0) * (_a select 1);
};
private _inS = [90, -90] select (_area > 0);         // inward = edge heading + _inS (the inside is on the left of a counter-clockwise outline)
private _edge = { params ["_i"]; [_poly select _i, _poly select ((_i + 1) mod _nP)] };
// point _t m along edge _i, _in m inside the wall
private _onEdge = {
    params ["_i", "_t", ["_in", 0]];
    ([_i] call _edge) params ["_a", "_b"];
    private _h = _a getDir _b;
    private _p = (_a getPos [_t, _h]) getPos [_in, _h + _inS];
    [_p select 0, _p select 1, 0]
};
private _edgeOut = { params ["_i"]; ([_i] call _edge) params ["_a", "_b"]; (_a getDir _b) - _inS };   // outward heading of edge _i
// base frame: u along the front edge, v inward
private _fs = CQ_baseFrontStart;
private _bO = _poly select _fs;
private _uDir = _bO getDir (_poly select ((_fs + 1) mod _nP));
private _fDir = _uDir - _inS;                        // the front (runway side) faces this way
private _atB = {
    params ["_u", "_v"];
    private _p = (_bO getPos [_u, _uDir]) getPos [_v, _uDir + _inS];
    [_p select 0, _p select 1, 0]
};
private _distOut = {                                 // m outside the outline (0 inside)
    params ["_p"];
    if ([_p select 0, _p select 1, 0] inPolygon _poly) exitWith { 0 };
    private _m = 1e9;
    for "_i" from 0 to _nP - 1 do {
        ([_i] call _edge) params ["_a", "_b"];
        private _ab = _b vectorDiff _a;
        private _l2 = (_ab select 0) ^ 2 + (_ab select 1) ^ 2;
        private _t = ((((_p select 0) - (_a select 0)) * (_ab select 0) + ((_p select 1) - (_a select 1)) * (_ab select 1)) / (_l2 max 0.01)) max 0 min 1;
        _m = _m min ([_p select 0, _p select 1, 0] distance2D (_a vectorAdd (_ab vectorMultiply _t)));
    };
    _m
};
private _cx = 0; private _cy = 0;
{ _cx = _cx + (_x select 0) / _nP; _cy = _cy + (_x select 1) / _nP } forEach _poly;
private _ctr = [_cx, _cy, 0];
private _reach = selectMax (_poly apply { _x distance2D _ctr });

private _placed = 0;
private _mk = {                                      // create one piece at a world position, absolute direction
    params ["_list", "_p", "_dir", ["_upright", false]];
    private _cls = [_list] call _pick;
    if (_cls == "") exitWith { objNull };
    private _obj = createVehicle [_cls, _p, [], 0, "CAN_COLLIDE"];
    _obj setDir _dir;
    _obj setPosATL _p;
    if (_upright) then { _obj setVectorUp [0, 0, 1] } else { _obj setVectorUp surfaceNormal _p };
    _obj allowDamage false;
    _placed = _placed + 1;
    _obj
};
private _put = { params ["_list", "_x0", "_y0", ["_rot", 0], ["_upright", false]]; [_list, [_x0, _y0] call _at, _d + _rot, _upright] call _mk };      // keep frame
private _putB = { params ["_list", "_u", "_v", ["_rot", 0], ["_upright", true]]; [_list, [_u, _v] call _atB, _fDir + _rot, _upright] call _mk };  // base frame, rot 0 = facing the front
private _wallW = {                                   // straight wall from world point A to B
    params ["_list", "_a", "_b"];
    private _cls = [_list] call _pick;
    if (_cls == "") exitWith {};
    private _seg = (([_cls] call _dims) select 0) max 2;
    private _len = _a distance2D _b;
    if (_len < 1) exitWith {};
    private _n = ceil (_len / _seg);
    private _h = _a getDir _b;
    for "_i" from 0 to _n - 1 do { [[_cls], _a getPos [(_i + 0.5) * (_len / _n), _h], _h + 90] call _mk };
};
private _wall = {                                    // keep frame wall
    params ["_list", "_a", "_b"];
    [_list, _a call _at, _b call _at] call _wallW;
};

// ---- the ground: terrain objects inside hidden, then levelled
private _hidden = 0;
{
    if ([getPosATL _x] call _distOut < 6) then { hideObjectGlobal _x; _hidden = _hidden + 1 };
} forEach (nearestTerrainObjects [_ctr, [], _reach + 8, false, true]);
if (CQ_baseLevel) then {
    private _g = (getTerrainInfo select 3) max 1;
    private _blend = CQ_baseLevelBlend;
    private _r = _reach + _blend + 5;
    private _pts = [];
    private _sum = 0; private _n = 0;
    for "_gx" from (floor ((_cx - _r) / _g)) to (ceil ((_cx + _r) / _g)) do {
        for "_gy" from (floor ((_cy - _r) / _g)) to (ceil ((_cy + _r) / _g)) do {
            private _q = [_gx * _g, _gy * _g, 0];
            private _out = (([_q] call _distOut) - 4) max 0;
            if (_out < _blend) then {
                private _z = getTerrainHeight _q;
                _pts pushBack [_q select 0, _q select 1, _z, _out];
                if (_out == 0) then { _sum = _sum + _z; _n = _n + 1 };
            };
        };
    };
    if (_n > 0) then {
        private _flat = _sum / _n;
        setTerrainHeight [_pts apply {
            _x params ["_px", "_py", "_z", "_out"];
            private _w = 1 - (_out / _blend);
            _w = _w * _w * (3 - 2 * _w);
            [_px, _py, _z + (_flat - _z) * _w]
        }, true];
        ["Base: site levelled at %1 m (%2 grid points), %3 terrain objects hidden", [_flat toFixed 1, count _pts, _hidden]] call CQ_fnc_log;
    };
};
// how far the runway-side wall stands from the runway centre line (information)
private _ils = getArray (configFile >> "CfgWorlds" >> worldName >> "ilsPosition");
private _ilsDir = getArray (configFile >> "CfgWorlds" >> worldName >> "ilsDirection");
if (count _ils >= 2 && { count _ilsDir >= 3 }) then {
    private _h = (_ilsDir select 0) atan2 (_ilsDir select 2);
    private _ip = [_ils select 0, _ils select 1, 0];
    ["Base: nearest wall corner %1 m from the runway centre line", [round selectMin (_poly apply { private _r = _x vectorDiff _ip; abs ((_r select 0) * cos _h - (_r select 1) * sin _h) })]] call CQ_fnc_log;
};

// ---------------------------------------------------------------- outer wall and gates
private _hbBig = ["Land_HBarrier_Big_F", "Land_HBarrier_5_F", "Land_HBarrier_3_F"];
private _tower = ["Land_HBarrierTower_F", "Land_BagBunker_Tower_F"];
private _lamp = ["Land_LampHalogen_F", "Land_LampShabby_F"];
private _perim = 0;
for "_i" from 0 to _nP - 1 do {
    ([_i] call _edge) params ["_a", "_b"];
    private _len = _a distance2D _b;
    _perim = _perim + _len;
    private _gaps = (CQ_baseGates select { (_x select 0) == _i }) apply { [(_x select 1) - (_x select 2), (_x select 1) + (_x select 2)] };
    _gaps sort true;
    private _t0 = 0;
    { [_hbBig, [_i, _t0] call _onEdge, [_i, (_x select 0) max _t0] call _onEdge] call _wallW; _t0 = _x select 1 } forEach _gaps;
    [_hbBig, [_i, _t0] call _onEdge, _b] call _wallW;
};
// corner sangars, 6 m clear of both walls, facing out
for "_i" from 0 to _nP - 1 do {
    private _c = _poly select _i;
    private _va = vectorNormalized ((_poly select ((_i - 1 + _nP) mod _nP)) vectorDiff _c);
    private _vb = vectorNormalized ((_poly select ((_i + 1) mod _nP)) vectorDiff _c);
    private _bis = vectorNormalized (_va vectorAdd _vb);
    private _half = acos ((_va vectorDotProduct _vb) max -1 min 1) / 2;
    private _p = _c vectorAdd (_bis vectorMultiply (6 / (sin _half max 0.2)));
    [_tower, [_p select 0, _p select 1, 0], ((_bis select 0) atan2 (_bis select 1)) + 180, true] call _mk;
};
// gates: entry control point (towers, concrete chicane inside) or a plain gate (bar + sandbag posts)
{
    _x params ["_i", "_t", "_hw", "_kind"];
    private _out = [_i] call _edgeOut;
    if (_kind == "ecp") then {
        [_tower, [_i, _t - _hw - 4, 5] call _onEdge, _out, true] call _mk;
        [_tower, [_i, _t + _hw + 4, 5] call _onEdge, _out, true] call _mk;
        [["Land_CncBarrierMedium4_F", "Land_CncBarrier_F"], [_i, _t - 3, 9] call _onEdge, _out, true] call _mk;
        [["Land_CncBarrierMedium4_F", "Land_CncBarrier_F"], [_i, _t + 3, 16] call _onEdge, _out, true] call _mk;
        { [_lamp, [_i, _t + _x * (_hw + 2), 11] call _onEdge, _out, true] call _mk } forEach [-1, 1];
    } else {
        { [["Land_BagBunker_Small_F", "Land_BagFence_Round_F"], [_i, _t + _x * (_hw + 2.5), 3] call _onEdge, _out, true] call _mk } forEach [-1, 1];
    };
} forEach CQ_baseGates;
// watchtowers and floodlights along the walls ([edge, m along it, m inside])
{ [["Land_Cargo_Patrol_V1_F", "Land_BagBunker_Tower_F"], [_x select 0, _x select 1, 6] call _onEdge, [_x select 0] call _edgeOut, true] call _mk } forEach CQ_baseWatchtowers;
{ [_lamp, [_x select 0, _x select 1, 3] call _onEdge, [_x select 0] call _edgeOut, true] call _mk } forEach CQ_baseFloodlights;

// ---------------------------------------------------------------- the keep
CQ_compoundSize params ["_kW", "_kD"];
private _hw = _kW / 2;
private _hd = _kD / 2;
private _hbMid = ["Land_HBarrier_5_F", "Land_HBarrier_3_F", "Land_HBarrier_Big_F"];
private _kg = 8;                                     // half width of the keep gate (-y, toward the yard and the apron)
private _door = [-11, -6];                           // side doors (y from / to)
[_hbMid, [-_hw, _hd], [_hw, _hd]] call _wall;
[_hbMid, [-_hw, -_hd], [-_kg, -_hd]] call _wall;
[_hbMid, [_kg, -_hd], [_hw, -_hd]] call _wall;
{
    [_hbMid, [_x * _hw, -_hd], [_x * _hw, _door select 0]] call _wall;
    [_hbMid, [_x * _hw, _door select 1], [_x * _hw, _hd]] call _wall;
} forEach [-1, 1];
{ [["Land_BagBunker_Small_F", "Land_BagFence_Round_F"], _x * (_kg + 3), -_hd - 2.5, 180, true] call _put } forEach [-1, 1];

// back row (deep in the keep, +y): ops | command post (commander) | medical, facing the plaza
private _cmdCls = [["Land_Cargo_HQ_V1_F", "Land_MilOffices_V1_F"]] call _pick;
private _opsCls = [["Land_MilOffices_V1_F", "Land_Cargo_House_V1_F"]] call _pick;
private _medCls = [["Land_Medevac_house_V1_F", "Land_Cargo_House_V1_F"]] call _pick;
private _ops = objNull;
if (_cmdCls != "") then {
    ([_cmdCls] call _dims) params ["_cw", "_cl"];
    _ops = [[_cmdCls], 0, _hd - 5 - _cl / 2, 180, true] call _put;
    if (_opsCls != "") then {
        ([_opsCls] call _dims) params ["_ow", "_ol"];
        private _ox = -(_cw / 2) - 6 - (_ow / 2);
        if (_ox - _ow / 2 > -_hw + 3) then { [[_opsCls], _ox, _hd - 4 - _ol / 2, 180, true] call _put } else { ["Base: ops building does not fit in the keep, skipped", []] call CQ_fnc_log };
    };
    if (_medCls != "") then {
        ([_medCls] call _dims) params ["_mw", "_ml"];
        private _mx = (_cw / 2) + 8 + (_mw / 2);
        if (_mx + _mw / 2 < _hw - 3) then { [[_medCls], _mx, _hd - 4 - _ml / 2, 180, true] call _put } else { ["Base: medical building does not fit in the keep, skipped", []] call CQ_fnc_log };
    };
};

// friendly commander in the command post: if he dies, the mission is lost (only enemy fire hurts him)
private _fg = createGroup [west, true];
private _fp = [0, _hd - 10] call _at;
CQ_friendlyCmd = _fg createUnit ["B_officer_F", _fp, [], 0, "CAN_COLLIDE"];
CQ_friendlyCmd setPosATL _fp;
CQ_friendlyCmd setDir _d;
CQ_friendlyCmd disableAI "PATH";
CQ_friendlyCmd setUnitPos "UP";
CQ_friendlyCmd setName "Colonel Harlan";
_fg setGroupIdGlobal ["CROSSROAD Actual"];
publicVariable "CQ_friendlyCmd";
CQ_cmdPost = _ops;      // the enemy assault breaches this building (CQ_fnc_assaultTick)
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

// plaza: flag and lamps; the lane from the keep gate to the plaza stays clear (muster point on it)
[["Flag_NATO_F"], 0, 0, 0, true] call _put;
{ [["Land_LampHalogen_F", "Land_LampShabby_F"], _x select 0, _x select 1, _x select 2, true] call _put } forEach [[-10, -8, 135], [10, -8, -135], [-10, 8, 45], [10, 8, -45]];

// squad bays along the keep's side walls, open toward the plaza
CQ_arsenalBoxes = [];
private _boxCls = [["B_CargoNet_01_ammo_F", "B_supplyCrate_F"]] call _pick;
private _bayX = _hw - 13;
{
    _x params ["_sq", "_side", "_by"];
    private _bx = _side * _bayX;
    private _in = -_side;
    private _face = [270, 90] select (_in > 0);
    [["CamoNet_BLUFOR_open_F", "CamoNet_BLUFOR_F"], _bx, _by, 90, true] call _put;
    private _p = [_bx + _in * 1.5, _by] call _at;
    private _b = createVehicle [_boxCls, _p, [], 0, "CAN_COLLIDE"];
    _b setDir (_d + _face);
    _b setPosATL _p;
    _b setVectorUp [0, 0, 1];
    _b allowDamage false;
    [_b, 2, false] call CQ_fnc_crateFill;
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
} forEach [["Alpha", -1, 2], ["Bravo", -1, -18], ["Charlie", 1, 2], ["Delta", 1, -18]];
publicVariable "CQ_arsenalBoxes";
CQ_arsenalBox = CQ_arsenalBoxes select 0;
publicVariable "CQ_arsenalBox";

// ---------------------------------------------------------------- motor pool (base frame)
private _clearSoft = { params ["_p", "_rad"]; { hideObjectGlobal _x } forEach (nearestTerrainObjects [_p, ["TREE", "SMALL TREE", "BUSH", "ROCK", "ROCKS", "FENCE", "WALL", "HIDE", "STACK"], _rad + 1, false, true]) };
CQ_repairPoints = [];
CQ_depots = [];
private _free = ["Land_RepairDepot_01_tan_F", "Land_RepairDepot_01_green_F", "Land_RepairDepot_01_civ_F"];
private _stCls = [_free + ["B_Slingload_01_Repair_F", "Land_Cargo20_military_green_F"], _free] call _pick;
{
    _x params ["_u", "_vDepot", "_vPad", "_vRep"];
    private _rp = [_u, _vRep] call _atB;             // service spot
    private _pad = [_u, _vPad] call _atB;            // depot pad: new vehicles appear here, facing inward
    private _sp = [_u, _vDepot] call _atB;           // repair depot against the runway-side wall (the depot terminal)
    if (_stCls != "") then {
        private _s = createVehicle [_stCls, _sp, [], 0, "CAN_COLLIDE"];
        _s setDir (_fDir + 180 + CQ_repairDepotRot);
        _s setPosATL _sp;
        _s setVectorUp [0, 0, 1];
        _s allowDamage false;
        (createVehicle ["Land_HelipadSquare_F", _pad, [], 0, "CAN_COLLIDE"]) setDir (_fDir + 180);
        CQ_depots pushBack [_s, _pad, _fDir + 180, "ground"];
    };
    { (createVehicle ["RoadCone_L_F", _rp getPos [CQ_repairRadius - 1, _fDir + _x], [], 0, "CAN_COLLIDE"]) allowDamage false } forEach [45, 135, 225, 315];
    CQ_repairPoints pushBack _rp;
} forEach CQ_baseMotorPool;
private _mu = 0;
{ _mu = _mu + (_x select 0) / count CQ_baseMotorPool } forEach CQ_baseMotorPool;
private _mm = createMarker ["cq_motorpool", [_mu, 30] call _atB];
_mm setMarkerType "loc_repair"; _mm setMarkerColor "ColorWEST"; _mm setMarkerText "Motor pool: repair & vehicle depot";
// vehicle shop by the entry control point
CQ_shopLZ = (CQ_baseShopLZ select [0, 2]) call _atB;
CQ_shopDir = _fDir + (CQ_baseShopLZ select 2);
(createVehicle ["Land_HelipadCircle_F", CQ_shopLZ, [], 0, "CAN_COLLIDE"]) setDir CQ_shopDir;
{ (createVehicle ["RoadCone_L_F", CQ_shopLZ getPos [10, CQ_shopDir + _x], [], 0, "CAN_COLLIDE"]) allowDamage false } forEach [0, 90, 180, 270];
private _tp = [(CQ_baseShopLZ select 0) + 14, CQ_baseShopLZ select 1] call _atB;
private _tblCls = [["Land_CampingTable_F"]] call _pick;
if (_tblCls != "") then { private _tb = createVehicle [_tblCls, _tp, [], 0, "CAN_COLLIDE"]; _tb setDir (_tp getDir CQ_shopLZ); _tb allowDamage false };
private _termCls = [["Land_DataTerminal_01_F", "Land_Laptop_unfolded_F", "Land_SatellitePhone_F"]] call _pick;
CQ_shopTerminal = createVehicle [_termCls, _tp, [], 0, "CAN_COLLIDE"];
CQ_shopTerminal setDir ((_tp getDir CQ_shopLZ) + 180);
if (_termCls != "Land_DataTerminal_01_F" && { _tblCls != "" }) then { CQ_shopTerminal setPosATL [_tp select 0, _tp select 1, 0.82] };
CQ_shopTerminal allowDamage false;
CQ_shopTerminal enableSimulationGlobal false;
publicVariable "CQ_shopTerminal"; publicVariable "CQ_shopLZ"; publicVariable "CQ_shopDir";
private _shm = createMarker ["cq_shop", CQ_shopLZ];
_shm setMarkerType "c_car"; _shm setMarkerColor "ColorWEST"; _shm setMarkerText "Vehicle shop";
// radar, supply stacks
[["Land_Radar_Small_F", "Land_TTowerSmall_2_F"], CQ_baseRadar select 0, CQ_baseRadar select 1, 0] call _putB;
{ [_x select 0, _x select 1, _x select 2, _x select 3] call _putB } forEach [
    [["Land_Pallets_stack_F"], 70, 54, 0], [["Land_CratesWooden_F"], 78, 58, 90]];
CQ_linkRelaySpawn = CQ_baseRelaySpawn call _atB;     // the relay vehicle leaves from the yard, by the runway gate

// ---------------------------------------------------------------- aviation apron (base frame)
private _termA = [["Land_DataTerminal_01_F", "Land_Laptop_unfolded_F"]] call _pick;
{
    _x params ["_u", "_vPad", "_vTerm"];
    private _pad = [_u, _vPad] call _atB;
    (createVehicle ["Land_HelipadSquare_F", _pad, [], 0, "CAN_COLLIDE"]) setDir _fDir;
    private _tp2 = [_u, _vTerm] call _atB;           // pilot terminal behind the pad, facing it
    private _t = createVehicle [_termA, _tp2, [], 0, "CAN_COLLIDE"];
    _t setDir _fDir;
    _t setPosATL _tp2;
    _t allowDamage false;
    _t enableSimulationGlobal false;
    CQ_depots pushBack [_t, _pad, _fDir, "air"];
    CQ_repairPoints pushBack _pad;                   // landed helicopters are repaired, refuelled, rearmed
} forEach CQ_baseHelipads;
private _au = 0;
{ _au = _au + (_x select 0) / count CQ_baseHelipads } forEach CQ_baseHelipads;
private _am = createMarker ["cq_apron", [_au, 45] call _atB];
_am setMarkerType "b_air"; _am setMarkerColor "ColorWEST"; _am setMarkerText "Aviation apron (Falcon)";
// MAGPIE's Darter pads (built by CQ_fnc_magInit)
CQ_magPadPos = (CQ_baseUavField select [0, 2]) call _atB;
CQ_magPadDir = _uDir + _inS + (CQ_baseUavField select 2);
publicVariable "CQ_repairPoints";
publicVariable "CQ_depots";
CQ_vehBoxes = []; publicVariable "CQ_vehBoxes";
CQ_vehBoxesDone = true; publicVariable "CQ_vehBoxesDone";
CQ_loadZones = []; publicVariable "CQ_loadZones";
CQ_crateSpots = [];

// ---------------------------------------------------------------- crewed defence spots (base frame), facing away from the keep
CQ_baseDefs = [];
{
    private _p = _x call _atB;
    CQ_baseDefs pushBack createHashMapFromArray [["pos", _p], ["dir", _o getDir _p], ["objs", []], ["lostT", -1]];
} forEach CQ_baseDefSpots;
{ [_x] call CQ_fnc_baseDefBuild } forEach CQ_baseDefs;

// billboard inside the keep, on its back wall right of the keep gate, picture toward the plaza
private _bbP = [_kg + 12, -_hd + 3] call _at;
private _bbC = [["Land_Billboard_F", "Land_Billboard_02_blank_F"]] call _pick;
if (_bbC != "" && { (getArray (configFile >> "CfgVehicles" >> _bbC >> "hiddenSelections")) isEqualTo [] }) then { _bbC = "UserTexture10m_F" };
if (_bbC != "") then {
    private _bb = createVehicle [_bbC, _bbP, [], 0, "CAN_COLLIDE"];
    _bb setDir (_d + ([180, 0] select CQ_billboardFlip));
    _bb setPosATL _bbP;
    _bb allowDamage false;
    _bb setObjectTextureGlobal [0, "media\billboard.jpg"];
};

// muster point (start + respawn): on the keep's lane, between the keep gate and the plaza
CQ_musterPos = [0, -_hd + 16] call _at;
publicVariable "CQ_musterPos";
private _respawn = createMarker ["respawn_west", CQ_musterPos];
_respawn setMarkerType "Empty";
private _hq = createMarker ["cq_base", _o];
_hq setMarkerType "b_hq"; _hq setMarkerColor "ColorWEST"; _hq setMarkerText "Camp Harlan";
for "_i" from 0 to _nP - 1 do {
    ([_i] call _edge) params ["_a", "_b"];
    private _zm = createMarker [format ["cq_base_zone_%1", _i], (_a vectorAdd _b) vectorMultiply 0.5];
    _zm setMarkerShape "RECTANGLE";
    _zm setMarkerSize [1.5, (_a distance2D _b) / 2];
    _zm setMarkerDir (_a getDir _b);
    _zm setMarkerBrush "SolidFull";
    _zm setMarkerColor "ColorWEST";
};
["Base built at %1 (keep facing %2 deg, front %3 deg): %4 pieces, outer wall %5 corners / %6 m, %7 gates, keep %8 x %9 m, %10 depots, %11 repair points",
    [mapGridPosition _o, round _d, round _fDir, _placed, _nP, round _perim, count CQ_baseGates, _kW, _kD, count CQ_depots, count CQ_repairPoints]] call CQ_fnc_log;

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
