/*
    CQ_fnc_baseSetup  (server)
    Builds the player base camp at CQ_basePos, oriented on CQ_baseDir (the camp "front",
    toward the heli line). Layout in metres, x = right, y = front:
      core camp 64 x 42 m inside H-barriers, gates front and back
        command post, flag, arsenal + ammo crates, briefing area under a camo net,
        medical post, supply corner (pallets, crates, water, toilets), lights
      vehicle park behind the camp: two rows, nose to the front
      heli line in front of the camp: one square pad per helicopter
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

// --- vehicle park behind the camp: 2 rows, 8 m apart side by side, nose to the front
CQ_baseSpots = createHashMap;
private _row = {
    params ["_role", "_y0", "_xs"];
    CQ_baseSpots set [_role, (CQ_baseSpots getOrDefault [_role, []]) + (_xs apply { [[_x, _y0] call _at, _d] })];
};
["hunter",  -34, [-28, -20, -12, -4]] call _row;
["strider", -34, [4, 12, 20, 28]] call _row;
["pickup",  -50, [-28, -20, -12, -4]] call _row;
["hemtt",   -52, [8, 22]] call _row;
// --- heli line in front: square pads
private _pads = {
    params ["_role", "_y0", "_xs"];
    {
        private _pos = [_x, _y0] call _at;
        private _pad = createVehicle ["Land_HelipadSquare_F", _pos, [], 0, "CAN_COLLIDE"];
        _pad setDir _d;
        CQ_baseSpots set [_role, (CQ_baseSpots getOrDefault [_role, []]) + [[_pos, _d]]];
    } forEach _xs;
};
["littlebird", 58, [-66, -46]] call _pads;
["ghosthawk", 58, [-18, 14]] call _pads;
["blackhawk", 58, [48]] call _pads;

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
