/*
    CQ_fnc_hqBuild  (server, scheduled: it sleeps between stages)
    [_hq] call CQ_fnc_hqBuild;
    Builds the HQ composition in 4 stages, CQ_hqBuildStageTime seconds apart, announcing each.
    Offsets are [right, forward] metres in the HQ's own frame (rotated by its "dir").
      1 command building   2 sandbag ring (gaps front and back)
      3 supply depot + radio tower   4 helipad + 3 AA pits
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
private _place = {
    params ["_cls", "_ox", "_oy", ["_rot", 0], ["_essential", false]];
    private _want = [_ox, _oy] call _at;
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
// Radio and depot only take damage from engineer demolition charges
private _engineerOnly = {
    params ["_obj"];
    _obj addEventHandler ["HandleDamage", {
        params ["_o", "", "_dmg", "_src", "_ammo", "", "_inst"];
        private _who = [_inst, _src] select (isNull _inst);
        if (_ammo in CQ_engineerCharges && { typeOf _who in CQ_engineerClasses }) then { _dmg } else { damage _o };
    }];
};
private _stage = {
    params ["_n", "_what"];
    ["Enemy HQ construction", format ["HQ #%1, stage %2/4: %3 (grid %4)", _id, _n, _what, mapGridPosition _c]] call CQ_fnc_announce;
};

// Stage 1 - command building
sleep CQ_hqBuildStageTime;
private _bld = ["Land_Cargo_HQ_V1_F", 0, 0, 0, true] call _place;
_hq set ["building", _bld];
[1, "command building"] call _stage;

// Stage 2 - sandbag ring, radius 13 m, gaps at the front (0) and back (180)
sleep CQ_hqBuildStageTime;
for "_a" from 15 to 345 step 15 do {
    if (_a != 180) then {
        ["Land_BagFence_Long_F", 13 * sin _a, 13 * cos _a, _a + 90] call _place;
    };
};
[2, "sandbag perimeter"] call _stage;

// Stage 3 - supply depot + ammo boxes, radio tower
sleep CQ_hqBuildStageTime;
private _depot = ["Land_Cargo_House_V1_F", -24, 0, 90, true] call _place;
{ ["Box_East_Ammo_F", _x, -6] call _place } forEach [-26, -24, -22];
private _radio = ["Land_TTowerBig_2_F", 0, 26, 0, true] call _place;
{ [_x] call _engineerOnly } forEach [_depot, _radio];

_depot addEventHandler ["Killed", {
    private _hq = CQ_hqs get ((_this select 0) getVariable ["CQ_hqId", -1]);
    if (isNil "_hq") exitWith {};
    ["Supply depot destroyed", format ["HQ #%1 lost its ammo stock", _hq get "id"]] call CQ_fnc_announce;
}];
_radio addEventHandler ["Killed", {
    private _hq = CQ_hqs get ((_this select 0) getVariable ["CQ_hqId", -1]);
    if (isNil "_hq") exitWith {};
    ["Radio tower destroyed", format ["HQ #%1 is cut off from the network", _hq get "id"]] call CQ_fnc_announce;
}];
_depot setVariable ["CQ_hqId", _id];
_radio setVariable ["CQ_hqId", _id];
_hq set ["depot", _depot];
_hq set ["radio", _radio];
[3, "supply depot and radio tower"] call _stage;

// Stage 4 - helipad + 3 AA pits (static Titan AA in a round sandbag ring)
sleep CQ_hqBuildStageTime;
["Land_HelipadSquare_F", 26, 0, 0, true] call _place;
private _aaGroup = createGroup [east, true];
{
    _x params ["_ox", "_oy"];
    private _aa = ["O_static_AA_F", _ox, _oy] call _place;
    if (!isNull _aa) then {
        { ["Land_BagFence_Round_F", _ox + 2.6 * sin _x, _oy + 2.6 * cos _x, _x + 180] call _place } forEach [0, 120, 240];
        createVehicleCrew _aa;
        (crew _aa) joinSilent _aaGroup;
    };
} forEach [[-20, 22], [20, 22], [0, -26]];
_aaGroup setBehaviour "AWARE";
_aaGroup setCombatMode "RED";
(_hq get "groups") pushBack _aaGroup;
[4, "helipad and 3 AA pits"] call _stage;
