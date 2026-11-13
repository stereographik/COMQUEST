/*
    CQ_fnc_baseSetup  (server)  -  CAMP HARLAN v3
    One outer wall (CQ_baseOuter) around everything the players use, kept CQ_baseRunwayGap m off
    the runway centre line (the whole site is moved inland if needed, CQ_basePos follows), the
    ground levelled first (CQ_baseLevel):
      outer wall    H-barriers, corner sangars, mid-side watchtowers, floodlights, an entry
                    control point with a concrete chicane (back) and an apron gate (front)
      the keep      inner wall (CQ_compoundSize: class change / arsenal zone), keep gate and side
                    doors; command post with the friendly commander (CQ_cmdPost), ops, medical,
                    plaza + flag, 4 squad bays (squad boxes), muster point, billboard
      motor pool    (left) 4 repair points + free-vehicle depots ("ground"), vehicle shop LZ
      aviation      (right) 4 helipads: Falcon depots ("air") and repair / refuel points
      defences      4 crewed defence spots in the corners (CQ_fnc_baseDefBuild)
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

// ================================================================= CAMP HARLAN v3
// One outer wall (CQ_baseOuter, H-barriers, corner sangars) around everything the players use,
// in compound coordinates (x right, y toward the runway / CQ_baseDir, origin = keep centre):
//
//   [sangar] ===== H-barrier ======================= APRON GATE ===== [sangar]   <- runway side
//   | MOTOR POOL        |   THE KEEP (inner wall)    |   AVIATION APRON       |
//   |  4 x repair +     |   command post (+y)        |   4 x helipad          |
//   |  free-depot pads  |   4 squad bays, plaza,     |   (Falcon depot,       |
//   |  vehicle shop LZ  |   muster, keep gate (-y)   |   repair + refuel)     |
//   [sangar] =================== ENTRY CONTROL POINT ======================== [sangar]
//
// The keep is CQ_compoundSize (class change, arsenal zone). The whole site is levelled first.
CQ_baseOuter params ["_OW", "_OD"];
private _ohw = _OW / 2;
private _ohd = _OD / 2;

// ---- keep the walls off the runway: shift the whole site inland if a corner is too close
private _ils = getArray (configFile >> "CfgWorlds" >> worldName >> "ilsPosition");
private _ilsDir = getArray (configFile >> "CfgWorlds" >> worldName >> "ilsDirection");
if (count _ils >= 2 && { count _ilsDir >= 3 }) then {
    private _h = (_ilsDir select 0) atan2 (_ilsDir select 2);
    private _ip = [_ils select 0, _ils select 1, 0];
    private _sd = { params ["_p"]; private _r = _p vectorDiff _ip; (_r select 0) * cos _h - (_r select 1) * sin _h };   // signed distance to the centre line
    private _side = [-1, 1] select (([_o] call _sd) >= 0);
    private _worst = selectMin ([[-_ohw, -_ohd], [_ohw, -_ohd], [-_ohw, _ohd], [_ohw, _ohd]] apply { _side * ([[_x select 0, _x select 1] call _at] call _sd) });
    if (_worst < CQ_baseRunwayGap) then {
        private _move = CQ_baseRunwayGap - _worst;
        private _nrm = [_side * cos _h, -_side * sin _h, 0];     // away from the runway
        _o = _o vectorAdd (_nrm vectorMultiply _move);
        _o set [2, 0];
        CQ_basePos = _o; publicVariable "CQ_basePos";
        ["Base: moved %1 m away from the runway (a wall corner was %2 m from its centre line)", [round _move, round _worst]] call CQ_fnc_log;
    } else {
        ["Base: nearest wall corner %1 m from the runway centre line", [round _worst]] call CQ_fnc_log;
    };
};

// ---- clear and level the ground of the whole site
private _hidden = 0;
{
    private _p = getPosATL _x;
    private _dx = (_p select 0) - (_o select 0);
    private _dy = (_p select 1) - (_o select 1);
    private _lx = _dx * cos _d - _dy * sin _d;
    private _ly = _dx * sin _d + _dy * cos _d;
    if (abs _lx < _ohw + 6 && { abs _ly < _ohd + 6 }) then { hideObjectGlobal _x; _hidden = _hidden + 1 };
} forEach (nearestTerrainObjects [_o, [], sqrt ((_ohw + 6) ^ 2 + (_ohd + 6) ^ 2), false, true]);
if (CQ_baseLevel) then {
    private _g = (getTerrainInfo select 3) max 1;
    private _blend = CQ_baseLevelBlend;
    private _reach = sqrt ((_ohw + _blend) ^ 2 + (_ohd + _blend) ^ 2);
    private _pts = [];
    private _sum = 0; private _n = 0;
    for "_gx" from (floor (((_o select 0) - _reach) / _g)) to (ceil (((_o select 0) + _reach) / _g)) do {
        for "_gy" from (floor (((_o select 1) - _reach) / _g)) to (ceil (((_o select 1) + _reach) / _g)) do {
            private _px = _gx * _g; private _py = _gy * _g;
            private _dx = _px - (_o select 0); private _dy = _py - (_o select 1);
            private _lx = abs (_dx * cos _d - _dy * sin _d);
            private _ly = abs (_dx * sin _d + _dy * cos _d);
            private _out = ((_lx - _ohw - 4) max 0) max ((_ly - _ohd - 4) max 0);
            if (_out < _blend) then {
                private _z = getTerrainHeight [_px, _py];
                _pts pushBack [_px, _py, _z, _out];
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

// ---------------------------------------------------------------- outer wall
private _hbBig = ["Land_HBarrier_Big_F", "Land_HBarrier_5_F", "Land_HBarrier_3_F"];
private _ecp = 10;                                   // half width of the entry control point (back)
private _apx = _ohw - 35; private _apg = 12;         // apron gate centre x and half width (front)
[_hbBig, [-_ohw, -_ohd], [-_ecp, -_ohd]] call _wall;
[_hbBig, [_ecp, -_ohd], [_ohw, -_ohd]] call _wall;
[_hbBig, [-_ohw, _ohd], [_apx - _apg, _ohd]] call _wall;
[_hbBig, [_apx + _apg, _ohd], [_ohw, _ohd]] call _wall;
[_hbBig, [-_ohw, -_ohd], [-_ohw, _ohd]] call _wall;
[_hbBig, [_ohw, -_ohd], [_ohw, _ohd]] call _wall;
// corner sangars (H-barrier towers) and watchtowers mid-side
{ [["Land_HBarrierTower_F", "Land_BagBunker_Tower_F"], (_x select 0) * (_ohw - 5), (_x select 1) * (_ohd - 5), [180, 0] select ((_x select 1) > 0), true] call _put } forEach [[-1, -1], [1, -1], [-1, 1], [1, 1]];
{ [["Land_Cargo_Patrol_V1_F", "Land_BagBunker_Tower_F"], _x select 0, _x select 1, _x select 2, true] call _put } forEach [[-_ohw + 5, 0, 270], [_ohw - 5, 0, 90], [-40, _ohd - 5, 0], [-40, -_ohd + 5, 180]];
// entry control point: two towers inside, a concrete chicane outside
[["Land_HBarrierTower_F", "Land_BagBunker_Tower_F"], -_ecp - 5, -_ohd + 4, 180, true] call _put;
[["Land_HBarrierTower_F", "Land_BagBunker_Tower_F"], _ecp + 5, -_ohd + 4, 180, true] call _put;
{ [["Land_CncBarrierMedium4_F", "Land_CncBarrier_F"], _x select 0, _x select 1, 0, true] call _put } forEach [[-5, -_ohd - 9], [5, -_ohd - 18], [-5, -_ohd - 27]];
// apron gate towers
{ [["Land_HBarrierTower_F", "Land_BagBunker_Tower_F"], _x, _ohd - 4, 0, true] call _put } forEach [_apx - _apg - 5, _apx + _apg + 5];
// floodlights along the inside of the wall
{ [["Land_LampHalogen_F", "Land_LampShabby_F"], _x select 0, _x select 1, _x select 2, true] call _put } forEach [
    [-_ohw + 3, -_ohd / 2, 270], [-_ohw + 3, _ohd / 2, 270], [_ohw - 3, -_ohd / 2, 90], [_ohw - 3, _ohd / 2, 90],
    [-_ohw / 2, _ohd - 3, 0], [0, _ohd - 3, 0], [-_ohw / 2, -_ohd + 3, 180], [_ohw / 2, -_ohd + 3, 180], [-_ecp - 2, -_ohd + 12, 180], [_ecp + 2, -_ohd + 12, 180]];

// ---------------------------------------------------------------- the keep
CQ_compoundSize params ["_W", "_D"];
private _hw = _W / 2;
private _hd = _D / 2;
private _hbMid = ["Land_HBarrier_5_F", "Land_HBarrier_3_F", "Land_HBarrier_Big_F"];
private _kg = 8;                                     // half width of the keep gate (back, toward the ECP)
private _door = [-11, -6];                           // side doors (y from / to), toward motor pool and apron
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
        private _ox = -(_cw / 2) - 7 - (_ow / 2);
        if (_ox - _ow / 2 > -_hw + 4) then { [[_opsCls], _ox, _hd - 5 - _ol / 2, 180, true] call _put };
    };
    if (_medCls != "") then {
        ([_medCls] call _dims) params ["_mw", "_ml"];
        private _mx = (_cw / 2) + 9 + (_mw / 2);
        if (_mx + _mw / 2 < _hw - 4) then { [[_medCls], _mx, _hd - 5 - _ml / 2, 180, true] call _put };
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
} forEach [["Alpha", -1, 6], ["Bravo", -1, -24], ["Charlie", 1, 6], ["Delta", 1, -24]];
publicVariable "CQ_arsenalBoxes";
CQ_arsenalBox = CQ_arsenalBoxes select 0;
publicVariable "CQ_arsenalBox";

// ---------------------------------------------------------------- motor pool (left band)
private _clearSoft = { params ["_p", "_rad"]; { hideObjectGlobal _x } forEach (nearestTerrainObjects [_p, ["TREE", "SMALL TREE", "BUSH", "ROCK", "ROCKS", "FENCE", "WALL", "HIDE", "STACK"], _rad + 1, false, true]) };
CQ_repairPoints = [];
CQ_depots = [];
private _mpX = -(_hw + _ohw) / 2;                    // middle of the band
private _free = ["Land_RepairDepot_01_tan_F", "Land_RepairDepot_01_green_F", "Land_RepairDepot_01_civ_F"];
private _stCls = [_free + ["B_Slingload_01_Repair_F", "Land_Cargo20_military_green_F"], _free] call _pick;
{
    private _y = _x;
    private _rp = [_mpX + 14, _y] call _at;          // service spot, by the ring road
    private _pad = [_mpX - 6, _y] call _at;          // depot pad: new vehicles appear here
    private _sp = [-_ohw + 9, _y] call _at;          // repair depot against the wall (the depot terminal)
    if (_stCls != "") then {
        private _s = createVehicle [_stCls, _sp, [], 0, "CAN_COLLIDE"];
        _s setDir (_d + 90 + CQ_repairDepotRot);
        _s setPosATL _sp;
        _s setVectorUp [0, 0, 1];
        _s allowDamage false;
        (createVehicle ["Land_HelipadSquare_F", _pad, [], 0, "CAN_COLLIDE"]) setDir (_d + 90);
        CQ_depots pushBack [_s, _pad, _d + 90, "ground"];
    };
    { (createVehicle ["RoadCone_L_F", _rp getPos [CQ_repairRadius - 1, _d + _x], [], 0, "CAN_COLLIDE"]) allowDamage false } forEach [45, 135, 225, 315];
    CQ_repairPoints pushBack _rp;
} forEach [_ohd - 24, _ohd - 56, _ohd - 88, _ohd - 120];
private _mm = createMarker ["cq_motorpool", [_mpX, 10] call _at];
_mm setMarkerType "loc_repair"; _mm setMarkerColor "ColorWEST"; _mm setMarkerText "Motor pool: repair & vehicle depot";
// vehicle shop at the back of the motor pool, by the entry control point
CQ_shopLZ = [_mpX, -_ohd + 20] call _at;
CQ_shopDir = _d;
(createVehicle ["Land_HelipadCircle_F", CQ_shopLZ, [], 0, "CAN_COLLIDE"]) setDir _d;
{ (createVehicle ["RoadCone_L_F", CQ_shopLZ getPos [10, _d + _x], [], 0, "CAN_COLLIDE"]) allowDamage false } forEach [0, 90, 180, 270];
private _tp = [_mpX + 18, -_ohd + 20] call _at;
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
// radar between the last depot and the shop; supply stacks at the front of the motor pool
[["Land_Radar_Small_F", "Land_TTowerSmall_2_F"], _mpX, -_ohd + 45, 0, true] call _put;
[["Land_Pallets_stack_F"], _mpX + 16, _ohd - 8, 0, true] call _put;
[["Land_CratesWooden_F"], _mpX + 20, _ohd - 12, 90, true] call _put;

// ---------------------------------------------------------------- aviation apron (right band)
private _avX = (_hw + _ohw) / 2;
private _termA = [["Land_DataTerminal_01_F", "Land_Laptop_unfolded_F"]] call _pick;
{
    private _y = _x;
    private _pad = [_avX + 6, _y] call _at;
    (createVehicle ["Land_HelipadSquare_F", _pad, [], 0, "CAN_COLLIDE"]) setDir (_d + 270);
    private _tp2 = [_hw + 8, _y] call _at;           // pilot terminal by the keep wall
    private _t = createVehicle [_termA, _tp2, [], 0, "CAN_COLLIDE"];
    _t setDir (_d + 90);
    _t setPosATL _tp2;
    _t allowDamage false;
    _t enableSimulationGlobal false;
    CQ_depots pushBack [_t, _pad, _d + 270, "air"];
    CQ_repairPoints pushBack _pad;                   // landed helicopters are repaired, refuelled, rearmed
} forEach [_ohd - 22, _ohd - 58, _ohd - 94, _ohd - 130];
private _am = createMarker ["cq_apron", [_avX, 0] call _at];
_am setMarkerType "b_air"; _am setMarkerColor "ColorWEST"; _am setMarkerText "Aviation apron (Falcon)";
CQ_linkRelaySpawn = [_avX, -_ohd + 14] call _at;     // the relay vehicle leaves from the back of the apron
publicVariable "CQ_repairPoints";
publicVariable "CQ_depots";
CQ_vehBoxes = []; publicVariable "CQ_vehBoxes";
CQ_vehBoxesDone = true; publicVariable "CQ_vehBoxesDone";
CQ_loadZones = []; publicVariable "CQ_loadZones";
CQ_crateSpots = [];

// ---------------------------------------------------------------- defences on the corners
CQ_baseDefs = [];
{
    private _p = [(_x select 0) * (_ohw - 16), (_x select 1) * (_ohd - 16)] call _at;
    CQ_baseDefs pushBack createHashMapFromArray [["pos", _p], ["dir", _d + (_x select 2)], ["objs", []], ["lostT", -1]];
} forEach [[-1, 1, -45], [1, 1, 45], [-1, -1, 225], [1, -1, 135]];
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
private _zone = createMarker ["cq_base_zone", _o];
_zone setMarkerShape "RECTANGLE";
_zone setMarkerSize [_ohw, _ohd];
_zone setMarkerDir _d;
_zone setMarkerBrush "Border";
_zone setMarkerColor "ColorWEST";
["Base built at %1 (front %2 deg): %3 pieces, outer wall %4 x %5 m, keep %6 x %7 m, %8 depots, %9 repair points",
    [mapGridPosition _o, round _d, _placed, _OW, _OD, _W, _D, count CQ_depots, count CQ_repairPoints]] call CQ_fnc_log;

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
