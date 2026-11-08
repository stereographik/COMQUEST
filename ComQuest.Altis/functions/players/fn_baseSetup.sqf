/*
    CQ_fnc_baseSetup  (server)
    Builds the player base camp at CQ_basePos, oriented on CQ_baseDir (the camp "front",
    toward the heli line). Layout in metres, x = right, y = front:
      core camp 64 x 42 m inside H-barriers, gates front and back
        command post, flag, arsenal + ammo crates, briefing area under a camo net,
        medical post, supply corner (pallets, crates, water, toilets), lights
      parking: a 25 m grid of flat, clear cells close to the camp (helicopters on pads)
    Every piece is spacing-checked (CQ_fnc_clearPos); a blocked piece is shifted a little or
    skipped and logged. Parking spots are left in CQ_baseSpots (role -> [[pos, dir]...]).
    Also: respawn marker on the muster area, map markers.
*/
if (!isServer) exitWith {};

private _o = CQ_basePos;
private _d = CQ_baseDir;
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

// --- perimeter: H-barriers, gates at the front and the back (x -5..5)
private _seg = 5.6;
for "_x0" from -29 to 29 step _seg do {
    if (abs _x0 > 6) then {
        ["Land_HBarrier_5_F", _x0, 21, 0, 1] call _put;
        ["Land_HBarrier_5_F", _x0, -21, 0, 1] call _put;
    };
};
for "_y0" from -18 to 18 step _seg do {
    ["Land_HBarrier_5_F", -32, _y0, 90, 1] call _put;
    ["Land_HBarrier_5_F", 32, _y0, 90, 1] call _put;
};
["Land_Sign_WarningMilitaryArea_F", 8, 23, 0, 0.5] call _put;
["Land_Sign_WarningMilitaryArea_F", -8, -23, 180, 0.5] call _put;

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

// --- supply corner (back), lights in the corners
["Land_Pallets_stack_F", -26, -15, 0, 1] call _put;
["Land_CratesWooden_F", -21, -15, 0, 1] call _put;
["Land_PaperBox_closed_F", -16, -16, 15, 0.8] call _put;
["Land_WaterTank_F", 22, -15, 0, 1.2] call _put;
["Land_FieldToilet_F", 26, -12, 270, 0.8] call _put;
["Land_FieldToilet_F", 28, -12, 270, 0.8] call _put;
{ ["Land_PortableLight_double_F", _x select 0, _x select 1, _x select 2, 0.6] call _put } forEach [[-29, 18, 225], [29, 18, 135], [-29, -18, 315], [29, -18, 45]];

// --- parking: a 25 m grid (aligned with the camp) over flat, clear ground close to the camp.
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
};
private _cells = [];
private _n = ceil (CQ_parkSearch / CQ_parkGrid);
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
        if (_cells isEqualTo []) exitWith { ["Base parking: no free grid cell left for %1", [_role]] call CQ_fnc_log };
        private _p = _cells deleteAt 0;
        if (_pad) then { (createVehicle ["Land_HelipadSquare_F", _p, [], 0, "CAN_COLLIDE"]) setDir _d };
        CQ_baseSpots set [_role, (CQ_baseSpots getOrDefault [_role, []]) + [[_p, _d]]];
    };
};
private _isAir = { params ["_c"]; _c isKindOf "Air" || { getNumber (configFile >> "CfgVehicles" >> _c >> "isUav") == 1 } };
{ _x params ["_cls", "_role", ["_k", 1]]; if !([_cls] call _isAir) then { [_role, _k] call _take } } forEach CQ_baseVehicles;
{ _x params ["_cls", "_role", ["_k", 1]]; if ([_cls] call _isAir) then { [_role, _k, true] call _take } } forEach CQ_baseVehicles;
["Base parking: %1 free grid cells found within %2 m", [count _cells + ({ count _y } count CQ_baseSpots), CQ_parkSearch]] call CQ_fnc_log;

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
