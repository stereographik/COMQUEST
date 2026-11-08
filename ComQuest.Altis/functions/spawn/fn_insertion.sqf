/*
    CQ_fnc_insertion  (server, spawned: it runs as one sequence)
    [_site] spawn CQ_fnc_insertion;

    Root insertion, phase by phase (each phase is announced on screen):
      1 Inbound       2 Taru slinging a Zamak + an Ifrit, 2 Taru with 3 squads + commander,
                      optional Kajman escort, coming from the side opposite the player base
      2 Drop/landing  lifters release their cargo over clear LZs (parachute fallback),
                      troop helis land on clear LZs and unload (teleport fallback)
      3 Leaving       every heli flies back out and is deleted
      4 Establishing  troops move in, CQ_fnc_hqBuild builds the HQ in 4 stages
      5 Holding       CQ_fnc_hqGarrison sets the garrison, map markers appear
*/
params ["_site"];

private _hq = [_site, -1] call CQ_fnc_hqNew;
private _id = _hq get "id";
private _hqDir = _hq get "dir";

private _approach = _site getDir CQ_basePos;           // helis come from the far side
private _start = _site getPos [CQ_insertionSpawnDistance, _approach + 180];
private _heading = _start getDir _site;
private _exit = _start;

private _squadCfg = configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad";

// Spawn slot in the formation: [lateral m, behind m]
private _slot = {
    params ["_lat", "_back"];
    private _q = (_start getPos [_lat, _heading + 90]) getPos [_back, _heading + 180];
    [_q select 0, _q select 1, 0]
};
// Clear LZ near a wanted point (falls back to the point itself)
private _lzAt = {
    params ["_dist", "_ang"];
    private _want = _site getPos [_dist, _hqDir + _ang];
    private _lz = [_want, CQ_lzClearance, 45] call CQ_fnc_clearPos;
    if (_lz isEqualTo []) then {
        ["HQ #%1: no clear LZ near %2, using it anyway", [_id, mapGridPosition _want]] call CQ_fnc_log;
        _lz = _want;
    };
    _lz
};

["Enemy insertion inbound", format ["HQ #%1: CSAT heavy helicopters %2 km out, heading for grid %3",
    _id, round (CQ_insertionSpawnDistance / 100) / 10, mapGridPosition _site]] call CQ_fnc_announce;

if (CQ_debug) then {
    private _m = createMarker [format ["cq_dbg_site_%1", _id], _site];
    _m setMarkerType "mil_objective";
    _m setMarkerColor "ColorOPFOR";
    _m setMarkerText format ["DEBUG site HQ #%1", _id];
    (_hq get "markers") pushBack _m;
};

// ---------------------------------------------------------------- lifters
private _lifts = [];
{
    _x params ["_cargoClass", "_lat", "_lzDist", "_lzAng", "_label"];
    private _p = [_lat, 0] call _slot;
    ([ "O_Heli_Transport_04_F", _p, _heading] call CQ_fnc_spawnHeli) params ["_heli", "_hg"];

    private _cargo = objNull;
    private _mass = 0;
    private _slung = false;
    isNil {
        // Unscheduled: create, place and hook in the same frame so the cargo never starts falling
        _cargo = createVehicle [_cargoClass, [0, 0, 1000], [], 0, "CAN_COLLIDE"];
        _cargo allowDamage false;
        _cargo setPosASL ((getPosASL _heli) vectorAdd [0, 0, -14]);
        _mass = getMass _cargo;
        _cargo setMass (_mass min 4000);   // stay under the Taru's sling limit during the flight
        _slung = _heli setSlingLoad _cargo;
        if (!_slung) then {
            // Fallback: carry it hidden, parachute it over the LZ
            _cargo hideObjectGlobal true;
            _cargo enableSimulationGlobal false;
            _cargo attachTo [_heli, [0, 0, -6]];
        };
    };
    ["HQ #%1: Taru with %2 airborne (sling %3, cargo mass %4 kg)", [_id, _label, ["FAILED, parachute fallback", "OK"] select _slung, round _mass]] call CQ_fnc_log;

    private _lz = [_lzDist, _lzAng] call _lzAt;
    _heli doMove _lz;

    _lifts pushBack createHashMapFromArray [
        ["heli", _heli], ["grp", _hg], ["cargo", _cargo], ["mass", _mass], ["slung", _slung],
        ["lz", _lz], ["label", _label], ["state", "fly"], ["t", time]
    ];
} forEach [
    ["O_Truck_02_transport_F", -90, 55, 120, "Zamak truck"],
    ["O_MRAP_02_hmg_F",        -30, 55, 240, "Ifrit HMG"]
];

// ---------------------------------------------------------------- troop helis
private _squads = [];
private _cmdGroup = createGroup [east, true];
private _troops = [];
{
    _x params ["_lat", "_lzDist", "_lzAng", "_nSquads", "_withCmd"];
    private _p = [_lat, 60] call _slot;
    ([ "O_Heli_Transport_04_covered_F", _p, _heading] call CQ_fnc_spawnHeli) params ["_heli", "_hg"];
    private _seats = _heli emptyPositions "cargo";
    private _lost = 0;

    for "_i" from 1 to _nSquads do {
        private _g = [_p, east, _squadCfg] call BIS_fnc_spawnGroup;
        { if !(_x moveInAny _heli) then { deleteVehicle _x; _lost = _lost + 1 } } forEach units _g;
        _squads pushBack _g;
    };
    if (_withCmd) then {
        { _cmdGroup createUnit [_x, _p, [], 0, "NONE"] } forEach ["O_officer_F", "O_Soldier_F", "O_Soldier_F", "O_Soldier_F", "O_Soldier_F"];
        { if !(_x moveInAny _heli) then { deleteVehicle _x; _lost = _lost + 1 } } forEach units _cmdGroup;
    };
    ["HQ #%1: troop Taru airborne, %2 cargo seats, %3 soldiers aboard, %4 did not fit",
        [_id, _seats, count ((crew _heli) select { group _x != _hg }), _lost]] call CQ_fnc_log;

    private _lz = [_lzDist, _lzAng] call _lzAt;
    private _pad = createVehicle ["Land_HelipadEmpty_F", _lz, [], 0, "CAN_COLLIDE"];
    _heli doMove _lz;

    _troops pushBack createHashMapFromArray [
        ["heli", _heli], ["grp", _hg], ["lz", _lz], ["pad", _pad], ["state", "fly"], ["t", time]
    ];
} forEach [
    [30, 85, 45, 2, false],
    [90, 85, 315, 1, true]
];

// ---------------------------------------------------------------- escort
private _escort = [];
if (CQ_insertionEscort) then {
    ([ "O_Heli_Attack_02_dynamicLoadout_F", [0, 160] call _slot, _heading, false] call CQ_fnc_spawnHeli) params ["_heli", "_hg"];
    private _wp = _hg addWaypoint [_site, 0];
    _wp setWaypointType "LOITER";
    _wp setWaypointLoiterRadius 400;
    _escort = [_heli, _hg];
};

["HQ #%1: insertion airborne, enemy AI on map: %2", [_id, call CQ_fnc_enemyCount]] call CQ_fnc_log;

// ---------------------------------------------------------------- flight loop
private _deleteHeli = {
    params ["_heli", "_grp"];
    { deleteVehicle _x } forEach crew _heli;
    deleteVehicle _heli;
    deleteGroup _grp;
};
private _dropped = [];
private _t0 = time;

while { true } do {
    sleep 1;

    // Lifters: fly -> near -> release -> leaving -> gone
    {
        private _e = _x;
        private _heli = _e get "heli";
        private _state = _e get "state";

        if (_state in ["fly", "near"] && { !alive _heli }) then {
            _e set ["state", "dead"];
            ["CSAT transport shot down", format ["HQ #%1: the Taru carrying the %2 is down", _id, _e get "label"]] call CQ_fnc_announce;
            private _c = _e get "cargo";
            if (!(_e get "slung")) then { deleteVehicle _c };
            continue;
        };

        switch (_state) do {
            case "fly": {
                if (_heli distance2D (_e get "lz") < 150) then {
                    _heli flyInHeight 22;
                    _heli limitSpeed 40;
                    _e set ["state", "near"];
                    _e set ["t", time];
                };
            };
            case "near": {
                private _d = _heli distance2D (_e get "lz");
                if ((_d < 40 && { speed _heli < 30 }) || { _d < 15 } || { time - (_e get "t") > 90 }) then {
                    private _cargo = _e get "cargo";
                    if (_e get "slung") then {
                        _heli setSlingLoad objNull;
                    } else {
                        detach _cargo;
                        _cargo hideObjectGlobal false;
                        _cargo enableSimulationGlobal true;
                        private _chute = createVehicle ["B_Parachute_02_F", [0, 0, 1000], [], 0, "FLY"];
                        _chute setPosASL ((getPosASL _heli) vectorAdd [0, 0, -10]);
                        _cargo attachTo [_chute, [0, 0, -1.5]];
                        [_cargo, _chute] spawn {
                            params ["_c", "_p"];
                            waitUntil { sleep 0.5; isNull _p || { (getPosATL _c select 2) < 4 } };
                            detach _c;
                            if (!isNull _p) then { deleteVehicle _p };
                        };
                    };
                    _cargo setMass (_e get "mass");
                    [_cargo] spawn { params ["_c"]; sleep 15; _c allowDamage true };
                    _dropped pushBack _cargo;
                    ["Enemy vehicle dropped", format ["HQ #%1: %2 released at grid %3", _id, _e get "label", mapGridPosition _heli]] call CQ_fnc_announce;

                    _heli limitSpeed 500;   // lift the limit again
                    _heli flyInHeight 100;
                    _heli doMove _exit;
                    _e set ["state", "leaving"];
                    _e set ["t", time];
                };
            };
            case "leaving": {
                if (!alive _heli || { _heli distance2D _site > CQ_insertionSpawnDistance * 0.8 } || { time - (_e get "t") > 240 }) then {
                    [_heli, _e get "grp"] call _deleteHeli;
                    _e set ["state", "gone"];
                };
            };
        };
    } forEach _lifts;

    // Troop helis: fly -> landing -> unloaded -> leaving -> gone
    {
        private _e = _x;
        private _heli = _e get "heli";
        private _state = _e get "state";
        private _pass = (crew _heli) select { group _x != (_e get "grp") };

        if (_state in ["fly", "landing"] && { !alive _heli }) then {
            _e set ["state", "dead"];
            ["CSAT transport shot down", format ["HQ #%1: a troop Taru is down", _id]] call CQ_fnc_announce;
            continue;
        };

        switch (_state) do {
            case "fly": {
                if (_heli distance2D (_e get "lz") < 500) then {
                    _heli land "GET OUT";
                    _e set ["state", "landing"];
                    _e set ["t", time];
                };
            };
            case "landing": {
                private _onGround = isTouchingGround _heli || { (getPosATL _heli select 2) < 2 };
                private _stuck = time - (_e get "t") > 150;
                if (_onGround || _stuck) then {
                    {
                        unassignVehicle _x;
                        moveOut _x;
                        if (_stuck && !_onGround) then { _x setPosATL ((_e get "lz") getPos [3 + random 12, random 360]) };
                    } forEach _pass;
                    if (_stuck && !_onGround) then { ["HQ #%1: troop Taru never touched down, teleport fallback used", [_id]] call CQ_fnc_log };
                    ["Enemy troops landed", format ["HQ #%1: %2 soldiers on the ground at grid %3", _id, count _pass, mapGridPosition (_e get "lz")]] call CQ_fnc_announce;
                    _e set ["state", "unloaded"];
                    _e set ["t", time];
                };
            };
            case "unloaded": {
                if (time - (_e get "t") > 5) then {
                    _heli flyInHeight 100;
                    _heli doMove _exit;
                    deleteVehicle (_e get "pad");
                    _e set ["state", "leaving"];
                    _e set ["t", time];
                };
            };
            case "leaving": {
                if (!alive _heli || { _heli distance2D _site > CQ_insertionSpawnDistance * 0.8 } || { time - (_e get "t") > 240 }) then {
                    [_heli, _e get "grp"] call _deleteHeli;
                    _e set ["state", "gone"];
                };
            };
        };
    } forEach _troops;

    private _pending = (_lifts + _troops) findIf { (_x get "state") in ["fly", "near", "landing"] };
    if (_pending == -1) exitWith {};
    if (time - _t0 > 900) exitWith { ["HQ #%1: insertion timed out after 15 min", [_id]] call CQ_fnc_log };
};

// Escort goes home once the drop is over
if (_escort isNotEqualTo []) then {
    _escort params ["_heli", "_hg"];
    if (alive _heli) then {
        while { (waypoints _hg) isNotEqualTo [] } do { deleteWaypoint ((waypoints _hg) select 0) };
        _heli doMove _exit;
        [_heli, _hg, _site, _deleteHeli] spawn {
            params ["_heli", "_hg", "_site", "_del"];
            private _t = time;
            waitUntil { sleep 5; !alive _heli || { _heli distance2D _site > CQ_insertionSpawnDistance * 0.8 } || { time - _t > 300 } };
            [_heli, _hg] call _del;
        };
    };
};

// ---------------------------------------------------------------- establishing
private _infantry = (_squads + [_cmdGroup]) select { ({ alive _x } count units _x) > 0 };
if (_infantry isEqualTo []) exitWith {
    _hq set ["state", "Failed"];
    { deleteMarker _x } forEach (_hq get "markers");
    ["Enemy insertion failed", format ["HQ #%1: no troops made it to the ground", _id]] call CQ_fnc_announce;
};

_hq set ["state", "Establishing"];
["Enemy establishing HQ", format ["HQ #%1: troops moving in to build at grid %2", _id, mapGridPosition _site]] call CQ_fnc_announce;

{ _x move (_site getPos [45, random 360]) } forEach (_squads select { (units _x) isNotEqualTo [] });
if ((units _cmdGroup) isNotEqualTo []) then { _cmdGroup move (_site getPos [20, _hqDir + 180]) };

// Crews for the dropped vehicles
private _vehicles = _dropped select { alive _x };
{ createVehicleCrew _x } forEach _vehicles;

[_hq] call CQ_fnc_hqBuild;
[_hq, _squads, _cmdGroup, _vehicles] call CQ_fnc_hqGarrison;

// ---------------------------------------------------------------- holding
_hq set ["state", "Holding"];
["Enemy HQ operational", format ["HQ #%1 is HOLDING near grid %2. Kill the commander and blow the depot (engineers). Enemy AI on map: %3",
    _id, mapGridPosition _site, call CQ_fnc_enemyCount]] call CQ_fnc_announce;
