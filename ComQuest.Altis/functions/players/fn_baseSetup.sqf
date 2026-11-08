/*
    CQ_fnc_baseSetup  (server)
    Builds the player base as a rural airfield at CQ_basePos, aligned with the runway
    (CfgWorlds ilsPosition / ilsDirection; CQ_baseDir if the map has none). Layout in metres,
    x = right, y = front:
      open camp (no wall): ops building, flag, arsenal + crates, briefing area under a camo
        net, medical post, supply corner, containers, windsock, lights, supply crate row
      vehicles parked ON THE RUNWAY: ground vehicles in two columns, helicopters in one
        centre column on pads, every spot 25 m+ apart and clear (fallback: 25 m grid)
      CQ_baseDefSpots defence spots around the perimeter: sandbagged AA + HMG, crewed
        (CQ_fnc_baseDefTick rebuilds a lost one)
    Every piece is spacing-checked (CQ_fnc_clearPos); a blocked piece is shifted a little or
    skipped and logged. Parking spots are left in CQ_baseSpots (role -> [[pos, dir]...]).
    Also: respawn marker on the muster area, map markers.
*/
if (!isServer) exitWith {};

private _o = CQ_basePos;
private _d = CQ_baseDir;
// Runway axis from the map config (main airfield)
private _ils = getArray (configFile >> "CfgWorlds" >> worldName >> "ilsPosition");
private _ilsDir = getArray (configFile >> "CfgWorlds" >> worldName >> "ilsDirection");
CQ_runway = [];
if (count _ils >= 2 && { count _ilsDir >= 3 }) then {
    private _h = (_ilsDir select 0) atan2 (_ilsDir select 2);
    CQ_runway = [[_ils select 0, _ils select 1, 0], _h];
    // camp front faces the runway (toward the nearest point of its centre line)
    private _ilsP = CQ_runway select 0;
    private _rel = _o vectorDiff _ilsP;
    private _t = (_rel select 0) * sin _h + (_rel select 1) * cos _h;
    private _near = _ilsP vectorAdd ([sin _h, cos _h, 0] vectorMultiply _t);
    _d = if (_o distance2D _near > 20) then { _o getDir _near } else { _h + 90 };
    CQ_baseDir = _d;
    publicVariable "CQ_baseDir";
};
private _at = {
    params ["_x0", "_y0"];
    private _p = _o getPos [sqrt (_x0 ^ 2 + _y0 ^ 2), _d + (_x0 atan2 _y0)];
    [_p select 0, _p select 1, 0]
};
private _placed = 0;
private _skipped = 0;
private _put = {
    params ["_cls", "_x0", "_y0", ["_rot", 0], ["_r", 1.5], ["_simple", true]];
    private _want = [_x0, _y0] call _at;
    private _p = [_want, _r, 4] call CQ_fnc_clearPos;
    if (_p isEqualTo []) exitWith { _skipped = _skipped + 1; objNull };
    private _obj = createVehicle [_cls, _p, [], 0, "CAN_COLLIDE"];
    _obj setDir (_d + _rot);
    _obj setVectorUp surfaceNormal _p;
    if (_simple) then { _obj allowDamage false };
    _placed = _placed + 1;
    _obj
};

// --- open airfield camp: no wall, a sandbag bunker by the entrance, containers, windsock
["Land_BagBunker_Small_F", -10, 24, 180, 3] call _put;
["Land_Cargo20_military_green_F", -34, -4, 90, 3.5] call _put;
["Land_Cargo20_military_green_F", -34, 4, 90, 3.5] call _put;
["Land_Cargo40_military_green_F", 34, -2, 90, 6] call _put;
["Windsock_01_F", 12, 40, 0, 0.6] call _put;
["Land_Sign_WarningMilitaryArea_F", 6, 26, 0, 0.5] call _put;
// --- core: command post, flag, arsenal
["Land_Cargo_House_V1_F", 0, 10, 180, 3.5] call _put;
["Flag_NATO_F", 0, -2, 0, 0.5] call _put;
private _boxPos = [5, -1] call _at;
private _box = createVehicle ["B_supplyCrate_F", _boxPos, [], 0, "NONE"];
_box setDir (_d + 90);
_box allowDamage false;
clearWeaponCargoGlobal _box; clearMagazineCargoGlobal _box; clearItemCargoGlobal _box; clearBackpackCargoGlobal _box;
missionNamespace setVariable ["CQ_arsenalBox", _box, true];
["Box_NATO_Ammo_F", 7.5, -1, 90, 0.6] call _put;
["Box_NATO_Wps_F", 9.5, -1, 90, 0.6] call _put;
["Box_NATO_Support_F", 7.5, 1, 90, 0.6] call _put;

// --- briefing area under a camo net (left), medical post (right)
["CamoNet_BLUFOR_big_F", -18, 8, 0, 1, true] call _put;
["Land_CampingTable_F", -18, 8, 90, 1] call _put;
{ ["Land_CampingChair_V2_F", -18 + (_x select 0), 8 + (_x select 1), _x select 2, 0.4] call _put } forEach [[-1.5, -1.6, 0], [1.5, -1.6, 0], [-1.5, 1.6, 180], [1.5, 1.6, 180]];
["Land_Medevac_house_V1_F", 19, 8, 180, 3] call _put;
["Land_Stretcher_01_F", 15, 3, 90, 0.5] call _put;

// --- supply crates row (inside the back wall, left of the gate): CQ_fnc_crateTick fills it
CQ_crateSpots = [];
for "_i" from 0 to CQ_crateCount - 1 do { CQ_crateSpots pushBack ([-27 + 2.6 * _i, -9] call _at) };

// --- supply corner (back), lights in the corners
["Land_Pallets_stack_F", -26, -15, 0, 1] call _put;
["Land_CratesWooden_F", -21, -15, 0, 1] call _put;
["Land_PaperBox_closed_F", -16, -16, 15, 0.8] call _put;
["Land_WaterTank_F", 22, -15, 0, 1.2] call _put;
["Land_FieldToilet_F", 26, -12, 270, 0.8] call _put;
["Land_FieldToilet_F", 28, -12, 270, 0.8] call _put;
{ ["Land_PortableLight_double_F", _x select 0, _x select 1, _x select 2, 0.6] call _put } forEach [[-29, 18, 225], [29, 18, 135], [-29, -18, 315], [29, -18, 45]];

// --- parking ON THE RUNWAY (2 columns of ground vehicles, 1 centre column of helicopters on
// pads), starting at the runway point nearest the camp and going along the runway toward
// the side with more clear ground. Spots 25 m+ apart, each flat and clear of objects.
private _runwaySpots = [];
private _runwayHeli = [];
private _nGround = 0; private _nAir = 0;
{ _x params ["_cls", "", ["_k", 1]]; if (_cls isKindOf "Air") then { _nAir = _nAir + _k } else { _nGround = _nGround + _k } } forEach CQ_baseVehicles;
if (CQ_runway isNotEqualTo []) then {
    CQ_runway params ["_ilsP", "_h"];
    private _ax = [sin _h, cos _h, 0];
    private _pp = [cos _h, -(sin _h), 0];
    private _rel = _o vectorDiff _ilsP;
    private _t = (_rel select 0) * (_ax select 0) + (_rel select 1) * (_ax select 1);
    private _p0 = _ilsP vectorAdd (_ax vectorMultiply _t);
    private _ok = {
        params ["_p"];
        !surfaceIsWater _p
        && { (_p isFlatEmpty [-1, -1, 0.08, 6, 0, false, objNull]) isNotEqualTo [] }
        && { ((nearestObjects [_p, [], 7]) select { !(_x isKindOf "CAManBase") && { !(_x isKindOf "Logic") } }) isEqualTo [] }
        && { (nearestTerrainObjects [_p, [], 6, false, true]) isEqualTo [] }
    };
    private _line = {
        params ["_sgn", "_lats", "_step", "_from", "_n"];
        private _out = [];
        private _k = 0;
        while { count _out < _n && { _k < 60 } } do {
            {
                private _p = (_p0 vectorAdd (_ax vectorMultiply (_sgn * (_from + _k * _step)))) vectorAdd (_pp vectorMultiply _x);
                _p set [2, 0];
                if (count _out < _n && { [_p] call _ok }) then { _out pushBack _p };
            } forEach _lats;
            _k = _k + 1;
        };
        _out
    };
    // pick the direction along the runway with more clear spots
    private _a = [1, [-12, 12], 25, 60, _nGround] call _line;
    private _b = [-1, [-12, 12], 25, 60, _nGround] call _line;
    private _sgn = [-1, 1] select (count _a >= count _b);
    _runwaySpots = [_a, _b] select (_sgn < 0);
    private _airFrom = 60 + 25 * ceil (_nGround / 2) + 40;
    _runwayHeli = [_sgn, [0], 32, _airFrom, _nAir] call _line;
    CQ_runwayDirSign = _sgn;
};

// fallback for what the runway could not take: a 25 m grid of flat, clear cells near the camp
 (aligned with the camp) over flat, clear ground close to the camp.
// A cell is used only if it is dry, flat over 9 m, and has no rock, building, wall, tree or
// any other object (camp pieces included) within CQ_parkClear. Ground vehicles take the
// cells nearest to the park point behind the camp, helicopters the next ones (with a pad).
CQ_baseSpots = createHashMap;
private _anchor = [0, -60] call _at;
private _cellOk = {
    params ["_p"];
    !surfaceIsWater _p
    && { (_p isFlatEmpty [-1, -1, CQ_parkMaxGradient, 9, 0, false, objNull]) isNotEqualTo [] }
    && { (nearestTerrainObjects [_p, [], CQ_parkClear, false, true]) isEqualTo [] }
    && { ((nearestObjects [_p, [], CQ_parkClear]) select { !(_x isKindOf "CAManBase") && { !(_x isKindOf "Logic") } }) isEqualTo [] }
    // big objects (hangars, terminal, sheds): the cell must be outside their whole footprint,
    // not only 10 m from their centre
    && { ((nearestObjects [_p, [], 60]) + (nearestTerrainObjects [_p, ["BUILDING", "HOUSE", "HIDE", "WALL", "FENCE"], 60, false, true])) findIf {
        !(_x isKindOf "CAManBase") && { _x distance2D _p < ((boundingBoxReal _x) select 2) * 0.8 + 6 }
    } == -1 }
};
private _cells = [];
private _n = ceil (CQ_parkSearch / CQ_parkGrid);
if (count _runwaySpots >= _nGround && { count _runwayHeli >= _nAir }) then { _n = -1 };   // runway took everything
for "_i" from -_n to _n do {
    for "_j" from -_n to _n do {
        private _x0 = _i * CQ_parkGrid;
        private _y0 = -60 + _j * CQ_parkGrid;
        private _p = [_x0, _y0] call _at;
        if (_p distance2D _anchor > CQ_parkSearch) then { continue };
        if ([_p] call _cellOk) then { _cells pushBack _p };
    };
};
_cells = [_cells, [], { _x distance2D _anchor }, "ASCEND"] call BIS_fnc_sortBy;
private _take = {
    params ["_role", "_count", ["_pad", false]];
    for "_k" from 1 to _count do {
        private _p = [];
        if (_pad && { _runwayHeli isNotEqualTo [] }) then { _p = _runwayHeli deleteAt 0 };
        if (!_pad && { _runwaySpots isNotEqualTo [] }) then { _p = _runwaySpots deleteAt 0 };
        if (_p isEqualTo [] && { _cells isNotEqualTo [] }) then { _p = _cells deleteAt 0 };
        if (_p isEqualTo []) exitWith { ["Base parking: no free spot left for %1", [_role]] call CQ_fnc_log };
        private _vd = if (CQ_runway isNotEqualTo []) then { (CQ_runway select 1) + ([0, 180] select (CQ_runwayDirSign < 0)) } else { _d };
        if (_pad) then { (createVehicle ["Land_HelipadSquare_F", _p, [], 0, "CAN_COLLIDE"]) setDir _vd };
        CQ_baseSpots set [_role, (CQ_baseSpots getOrDefault [_role, []]) + [[_p, _vd]]];
        // small map marker per parking spot, so the motor pool is easy to find
        private _m = createMarker [format ["cq_park_%1_%2", _role, _k], _p];
        _m setMarkerType (["mil_dot", "c_air"] select _pad);
        _m setMarkerColor "ColorWEST";
        _m setMarkerSize [0.5, 0.5];
        _m setMarkerText _role;
    };
};
private _isAir = { params ["_c"]; _c isKindOf "Air" || { getNumber (configFile >> "CfgVehicles" >> _c >> "isUav") == 1 } };
{ _x params ["_cls", "_role", ["_k", 1]]; if !([_cls] call _isAir) then { [_role, _k] call _take } } forEach CQ_baseVehicles;
{ _x params ["_cls", "_role", ["_k", 1]]; if ([_cls] call _isAir) then { [_role, _k, true] call _take } } forEach CQ_baseVehicles;
private _used = 0;
{ _used = _used + count _y } forEach CQ_baseSpots;
["Base parking: %1 free grid cells within %2 m, %3 used, %4 left", [count _cells + _used, CQ_parkSearch, _used, count _cells]] call CQ_fnc_log;

// --- defence spots around the perimeter (off the runway): AA + HMG behind sandbags
CQ_baseDefs = [];
{
    private _ang = _d + _x;
    private _want = _o getPos [CQ_baseDefRadius, _ang];
    // keep off the runway strip
    if (CQ_runway isNotEqualTo []) then {
        CQ_runway params ["_ilsP", "_h"];
        private _rel = _want vectorDiff _ilsP;
        private _off = abs ((_rel select 0) * cos _h - (_rel select 1) * sin _h);
        if (_off < 70) then { _want = _want getPos [70 - _off + 10, _o getDir _want] };
    };
    private _p = [_want, 7, 40] call CQ_fnc_clearPos;
    if (_p isEqualTo []) then { continue };
    CQ_baseDefs pushBack createHashMapFromArray [["pos", _p], ["dir", _ang], ["objs", []], ["lostT", -1]];
} forEach CQ_baseDefAngles;
{ [_x] call CQ_fnc_baseDefBuild } forEach CQ_baseDefs;

// --- respawn on the muster area (between the flag and the back gate), map markers
CQ_musterPos = [0, -11] call _at;
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

["Base camp built at %1 (facing %2): %3 pieces, %4 skipped for spacing", [mapGridPosition _o, _d, _placed, _skipped]] call CQ_fnc_log;
