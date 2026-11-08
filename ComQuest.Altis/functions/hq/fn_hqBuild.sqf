/*
    CQ_fnc_hqBuild  (server, spawned by CQ_fnc_hqTick when the perimeter is secured)
    [_hq] spawn CQ_fnc_hqBuild;
    Builds the HQ composition in 4 stages, CQ_hqBuildStageTime seconds apart, announcing each.
    Offsets are [right, forward] metres in the HQ's own frame (rotated by its "dir").
      1 command building   2 sandbag ring (gaps front and back)
      3 supply depot + radio tower   4 helipad + parked QRF helicopter + 3 AA pits
    At the end the squads are recalled to garrison the HQ and "buildDone" is set.
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
// Stage wait: CQ_hqBuildStageTime, or until the debug panel skips it
private _wait = {
    private _t = time + CQ_hqBuildStageTime;
    waitUntil { sleep 1; time >= _t || { _hq get "skipStage" } };
    _hq set ["skipStage", false];
};

// Relaxed site (tolerance 3+): the troops clear trees and bushes from the footprint first
if ((_hq get "siteLevel") >= 3) then {
    private _veg = nearestTerrainObjects [_c, ["TREE", "SMALL TREE", "BUSH"], CQ_siteRadius, false, true];
    { _x hideObjectGlobal true } forEach _veg;
    ["HQ #%1: site tolerance %2, cleared %3 trees and bushes", [_id, _hq get "siteLevel", count _veg]] call CQ_fnc_log;
};

private _stage = {
    params ["_n", "_what"];
    ["Enemy HQ construction", format ["HQ #%1, stage %2/4: %3 (grid %4)", _id, _n, _what, mapGridPosition _c]] call CQ_fnc_announce;
};

// Stage 1 - command building
call _wait;
private _bld = ["Land_Cargo_HQ_V1_F", 0, 0, 0, true] call _place;
_hq set ["building", _bld];
[1, "command building"] call _stage;

// Stage 2 - sandbag ring, radius 13 m, gaps at the front (0) and back (180)
call _wait;
for "_a" from 15 to 345 step 15 do {
    if (_a != 180) then {
        ["Land_BagFence_Long_F", 13 * sin _a, 13 * cos _a, _a + 90] call _place;
    };
};
[2, "sandbag perimeter"] call _stage;

// Stage 3 - supply depot + ammo boxes, radio tower, fuel tanker, field resupply truck
call _wait;
private _depot = ["Land_Cargo_House_V1_F", -24, 0, 90, true] call _place;
{ ["Box_East_Ammo_F", _x, -6] call _place } forEach [-26, -24, -22];
private _radio = ["Land_TTowerBig_2_F", 0, 26, 0, true] call _place;
{ [_x] call _engineerOnly } forEach [_depot, _radio];

_depot addEventHandler ["Killed", {
    private _hq = CQ_hqs get ((_this select 0) getVariable ["CQ_hqId", -1]);
    if (isNil "_hq") exitWith {};
    ["Supply depot destroyed", format ["HQ #%1 lost its %2 ammo: no more rearming there", _hq get "id", round (_hq get "stock")]] call CQ_fnc_announce;
    _hq set ["stock", 0];
}];

// Fuel tanker: holds the HQ's fuel. Any weapon can destroy it.
private _tanker = [CQ_tankerClass, 18, -18, 90] call _place;
if (!isNull _tanker) then {
    _tanker setFuelCargo 0;           // players can't refuel from it
    _tanker lock 2;
    _tanker setVariable ["CQ_hqId", _id];
    _tanker addEventHandler ["Killed", {
        private _hq = CQ_hqs get ((_this select 0) getVariable ["CQ_hqId", -1]);
        if (isNil "_hq") exitWith {};
        ["Fuel tanker destroyed", format ["HQ #%1 lost its %2 fuel: no more refuelling there", _hq get "id", round (_hq get "fuel")]] call CQ_fnc_announce;
        _hq set ["fuel", 0];
    }];
};
_hq set ["tanker", _tanker];

// Field resupply truck: driven out to groups short of ammo (CQ_fnc_fieldResupply)
private _ftruck = [CQ_fieldTruckClass, -18, -20, 90] call _place;
if (!isNull _ftruck) then {
    _ftruck setAmmoCargo 0;
    _ftruck lock 2;
    _ftruck setVariable ["CQ_hqId", _id];
    _ftruck addEventHandler ["Killed", {
        private _hq = CQ_hqs get ((_this select 0) getVariable ["CQ_hqId", -1]);
        if (isNil "_hq") exitWith {};
        ["Field supply truck destroyed", format ["HQ #%1 can no longer resupply its squads in the field", _hq get "id"]] call CQ_fnc_announce;
    }];
    _hq set ["fieldTruckHome", getPosATL _ftruck];
};
_hq set ["fieldTruck", _ftruck];
_radio addEventHandler ["Killed", {
    private _hq = CQ_hqs get ((_this select 0) getVariable ["CQ_hqId", -1]);
    if (isNil "_hq") exitWith {};
    ["Radio tower destroyed", format ["HQ #%1 is cut off from the network", _hq get "id"]] call CQ_fnc_announce;
}];
_depot setVariable ["CQ_hqId", _id];
_radio setVariable ["CQ_hqId", _id];
_hq set ["depot", _depot];
_hq set ["radio", _radio];
_hq set ["stock", (_hq get "stockInit") min (_hq get "cap")];
_hq set ["fuel", (_hq get "fuelInit") min (_hq get "cap")];
if (isNull _tanker) then { _hq set ["fuel", 0] };
[3, format ["supply depot (%1 ammo), fuel tanker (%2 fuel), field supply truck, radio tower", round (_hq get "stock"), round (_hq get "fuel")]] call _stage;

// Stage 4 - helipad with the QRF helicopter parked on it + 3 AA pits
call _wait;
private _pad = ["Land_HelipadSquare_F", 26, 0, 0, true] call _place;
_hq set ["pad", _pad];
if (!isNull _pad) then {
    private _heli = createVehicle [CQ_hqHeliClass, getPosATL _pad, [], 0, "CAN_COLLIDE"];
    _heli setDir _d;
    private _hg = [_heli] call CQ_fnc_crewVehicle;
    _hg setBehaviour "SAFE";
    _heli engineOn false;
    [_heli] call CQ_fnc_airLoadout;
    [_heli, 1] call CQ_fnc_vehAmmoInit;
    [_heli, _hg, "armed", _id, _pad, [], true] call CQ_fnc_airRegister;
    (_hq get "support") pushBack _hg;
};

private _aaGroup = createGroup [east, true];
{
    _x params ["_ox", "_oy"];
    private _aa = ["O_static_AA_F", _ox, _oy] call _place;
    if (!isNull _aa) then {
        { ["Land_BagFence_Round_F", _ox + 2.6 * sin _x, _oy + 2.6 * cos _x, _x + 180] call _place } forEach [0, 120, 240];
        createVehicleCrew _aa;
        (crew _aa) joinSilent _aaGroup;
        [_aa, 1] call CQ_fnc_vehAmmoInit;
    };
} forEach [[-20, 22], [20, 22], [0, -26]];
_aaGroup setBehaviour "AWARE";
_aaGroup setCombatMode "RED";
(_hq get "support") pushBack _aaGroup;
[4, "helipad with QRF helicopter, 3 AA pits"] call _stage;

// Recall the perimeter squads and set the garrison
[_hq] call CQ_fnc_hqGarrison;
_hq set ["buildDone", true];
