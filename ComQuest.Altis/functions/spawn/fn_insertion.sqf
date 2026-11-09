/*
    CQ_fnc_insertion  (server, spawned: it runs as one sequence)
    [_site] spawn CQ_fnc_insertion;

    Root insertion, phase by phase (each phase is announced on screen):
      1 Inbound       2 Blackfish carrying a Zamak + an Ifrit, 2 Taru with 3 squads + commander,
                      escorted by 2 Orcas + 1 Kajman, coming from the side opposite the player base
      2 Drop/landing  Blackfish paradrop the vehicles over clear LZs and fly back to the carrier,
                      troop helis land on clear LZs and unload (teleport fallback)
      3 Fleet         3 s after its drop every heli flies to park near the main HQ (or this
                      site) and waits for orders; when the fleet is full it leaves instead
      4 Securing      hands over to CQ_fnc_hqTick as soon as every troop heli has unloaded
                      (secure, install, hold, reinforce, split); vehicles join the HQ when they
                      are down, even if securing has already started
*/
params ["_site", ["_siteLevel", 0]];

private _hq = [_site, -1] call CQ_fnc_hqNew;
_hq set ["siteLevel", _siteLevel];
_hq set ["stockInit", CQ_rootStartStock];
_hq set ["fuelInit", CQ_rootStartFuel];
private _id = _hq get "id";
private _hqDir = _hq get "dir";

// Helis take off from the carrier (fallback: from the side opposite the player base)
private _start = if (!isNil "CQ_carrierPos") then { CQ_carrierPos getPos [400, CQ_carrierPos getDir _site] }
    else { _site getPos [CQ_insertionSpawnDistance, (_site getDir CQ_basePos) + 180] };
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

["Enemy insertion inbound", format ["HQ #%1: CSAT heavy helicopters leaving the carrier, %2 km out, heading for grid %3",
    _id, round ((_start distance2D _site) / 100) / 10, mapGridPosition _site]] call CQ_fnc_announce;

if (CQ_debug) then {
    private _m = createMarker [format ["cq_dbg_site_%1", _id], _site];
    _m setMarkerType "mil_objective";
    _m setMarkerColor "ColorOPFOR";
    _m setMarkerText format ["DEBUG site HQ #%1", _id];
    (_hq get "markers") pushBack _m;
};

// ---------------------------------------------------------------- vehicle drop planes
// Each vehicle flies inside a Blackfish (vehicle transport, Vehicle-in-Vehicle) and is
// paradropped over its LZ. A vehicle too big for the cargo bay rides hidden and gets its
// own parachute at the drop. The Blackfish goes back to the carrier afterwards.
private _lifts = [];
{
    _x params ["_cargoClass", "_lat", "_lzDist", "_lzAng", "_label"];
    private _p = [_lat, 0] call _slot;
    private _heli = createVehicle [CQ_dropPlaneClass, [_p select 0, _p select 1, CQ_heightDrop], [], 0, "FLY"];
    _heli setPosASL [_p select 0, _p select 1, (getTerrainHeightASL _p max 0) + CQ_heightDrop];
    _heli setDir _heading;
    _heli setVelocityModelSpace [0, 60, 0];
    private _hg = [_heli] call CQ_fnc_crewVehicle;     // CSAT crew in the Blackfish
    _hg setBehaviourStrong "CARELESS";
    _hg setCombatMode "BLUE";
    _heli flyInHeight CQ_heightDrop;
    _heli setFuelConsumptionCoef CQ_fuelConsumption;

    private _cargo = objNull;
    private _viv = false;
    isNil {
        // Unscheduled: create and load in the same frame so the cargo never starts falling
        _cargo = createVehicle [_cargoClass, [0, 0, 1000], [], 0, "CAN_COLLIDE"];
        _cargo allowDamage false;
        if (((_heli canVehicleCargo _cargo) param [0, false])) then { _viv = _heli setVehicleCargo _cargo };
        if (!_viv) then {
            _cargo hideObjectGlobal true;
            _cargo enableSimulationGlobal false;
            _cargo attachTo [_heli, [0, 0, -6]];
        };
    };
    ["HQ #%1: Blackfish with %2 airborne (%3)", [_id, _label, ["too big for the bay, own parachute at the drop", "in the cargo bay"] select _viv]] call CQ_fnc_log;

    private _lz = [_lzDist, _lzAng] call _lzAt;
    // Paradrop LZ at least CQ_dropCoastGap from any water: pushed inland (away from the carrier) until safe
    private _away = _start getDir _lz;
    for "_k" from 1 to 12 do {
        if ([_lz, CQ_dropCoastGap] call CQ_fnc_coastSafe) exitWith {};
        _lz = _lz getPos [100, _away];
    };
    _heli doMove _lz;

    _lifts pushBack createHashMapFromArray [
        ["heli", _heli], ["grp", _hg], ["cargo", _cargo], ["mass", getMass _cargo], ["slung", _viv],
        ["lz", _lz], ["label", _label], ["state", "fly"], ["t", time]
    ];
} forEach [
    ["O_Truck_02_transport_F", -2 * CQ_formationGap, 55, 120, "Zamak truck"],
    ["O_MRAP_02_hmg_F",        -CQ_formationGap,     55, 240, "Ifrit HMG"]
];

// ---------------------------------------------------------------- troop helis
private _squads = [];
private _cmdGroup = createGroup [east, true];
private _troops = [];
{
    _x params ["_lat", "_lzDist", "_lzAng", "_nSquads", "_withCmd"];
    private _p = [_lat, 120] call _slot;
    ([ CQ_troopHeliClass, _p, _heading, true, CQ_heightTroops] call CQ_fnc_spawnHeli) params ["_heli", "_hg"];
    private _seats = _heli emptyPositions "cargo";
    private _lost = 0;

    for "_i" from 1 to _nSquads do {
        private _g = [_p, east, _squadCfg] call BIS_fnc_spawnGroup;
        [units _g] call CQ_fnc_unitPrep;
        { if !(_x moveInAny _heli) then { deleteVehicle _x; _lost = _lost + 1 } } forEach units _g;
        _squads pushBack _g;
    };
    if (_withCmd) then {
        { _cmdGroup createUnit [_x, _p, [], 0, "NONE"] } forEach ["O_officer_F", "O_Soldier_F", "O_Soldier_F", "O_Soldier_F", "O_Soldier_F"];
        [units _cmdGroup] call CQ_fnc_unitPrep;
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
    [CQ_formationGap,     85, 45, 2, false],
    [2 * CQ_formationGap, 85, 315, 1, true]
];

// ---------------------------------------------------------------- escort: 2 Orcas + 1 Kajman
private _escorts = [_start, _heading, _site] call CQ_fnc_spawnEscorts;

["HQ #%1: insertion airborne, enemy AI on map: %2", [_id, call CQ_fnc_enemyCount]] call CQ_fnc_log;

// ---------------------------------------------------------------- flight loop
private _deleteHeli = {
    params ["_heli", "_grp"];
    { deleteVehicle _x } forEach crew _heli;
    deleteVehicle _heli;
    deleteGroup _grp;
};
private _toFleet = {
    params ["_e", "_kind"];
    private _heli = _e get "heli";
    if ([_heli, _e get "grp", _kind, _id, objNull, _site] call CQ_fnc_airRegister) then {
        _e set ["state", "fleet"];
    } else {
        _heli flyInHeight 100;
        _heli doMove _exit;
        _e set ["state", "leaving"];
        _e set ["t", time];
    };
};
private _handed = false;
private _handoff = {
    _handed = true;
    private _infantry = _squads select { ({ alive _x } count units _x) > 0 };
    if (_infantry isEqualTo [] && { ({ alive _x } count units _cmdGroup) == 0 }) exitWith {
        _hq set ["state", "Failed"];
        { deleteMarker _x } forEach (_hq get "markers");
        ["Enemy insertion failed", format ["HQ #%1: no troops made it to the ground", _id]] call CQ_fnc_announce;
    };
    _hq set ["infantry", _infantry];
    _hq set ["cmdGroup", _cmdGroup];
    _hq set ["state", "Securing"];          // CQ_fnc_hqTick takes over: secure -> install -> hold -> reinforce -> split
    _hq set ["stateT", time];
};
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
            ["CSAT transport shot down", format ["HQ #%1: the Blackfish carrying the %2 is down", _id, _e get "label"]] call CQ_fnc_announce;
            private _c = _e get "cargo";
            if (!(_e get "slung")) then { deleteVehicle _c };
            continue;
        };

        switch (_state) do {
            case "fly": {
                // Paradrop a little before the LZ: the load keeps drifting forward under its canopy
                private _d = _heli distance2D (_e get "lz");
                if (_d < 900) then { _heli limitSpeed 220 };
                // released only over safe ground: the plane CQ_dropCoastGap from any water (or right over the LZ)
                private _safe = [getPosATL _heli, CQ_dropCoastGap] call CQ_fnc_coastSafe;
                private _minD = _e getOrDefault ["minD", 1e9];
                if (_d < _minD) then { _e set ["minD", _d]; _minD = _d };
                private _passed = _minD < CQ_dropLead && { _d > _minD + 40 };   // overflew the LZ between two checks
                if ((_d < CQ_dropLead && _safe) || { _d < 80 } || { _passed && _safe } || { time - (_e get "t") > 400 && _safe }) then {
                    private _cargo = _e get "cargo";
                    if (_e get "slung") then {
                        _heli setVehicleCargo objNull;          // Vehicle-in-Vehicle unload in flight: own parachute
                    } else {
                        detach _cargo;
                        _cargo hideObjectGlobal false;
                        _cargo enableSimulationGlobal true;
                        _cargo setPosASL ((getPosASL _heli) vectorAdd [0, 0, -12]);
                        private _chute = createVehicle ["B_Parachute_02_F", [0, 0, 1000], [], 0, "FLY"];
                        _chute setPosASL (getPosASL _cargo);
                        _cargo attachTo [_chute, [0, 0, -1.5]];
                        [_cargo, _chute] spawn {
                            params ["_c", "_p"];
                            waitUntil { sleep 0.5; isNull _p || { (getPosATL _c select 2) < 4 } };
                            detach _c;
                            if (!isNull _p) then { deleteVehicle _p };
                        };
                    };
                    [_cargo] spawn { params ["_c"]; sleep 60; _c allowDamage true };
                    [_cargo, _hq, _id, _e get "label"] spawn {
                        params ["_c", "_hq", "_id", "_label"];
                        private _t = time;
                        waitUntil { sleep 1; !alive _c || { isTouchingGround _c && { speed _c < 3 } } || { time - _t > 120 } };
                        if (alive _c) then {
                            _c allowDamage true;
                            [_c] call CQ_fnc_crewVehicle;
                            [_c, CQ_vehSpawnAmmo] call CQ_fnc_vehAmmoInit;
                            (_hq get "vehicles") pushBack _c;
                            ["Enemy vehicle landed", format ["HQ #%1: %2 down at grid %3 (%4 m from the site)", _id, _label, mapGridPosition _c, round (_c distance2D (_hq get "pos"))]] call CQ_fnc_announce;
                        };
                    };
                    ["Enemy vehicle dropped", format ["HQ #%1: %2 paradropped at grid %3 (%4 m from its LZ)", _id, _e get "label", mapGridPosition _heli, round _d]] call CQ_fnc_announce;
                    if (isNil "CQ_firstDropT") then { CQ_firstDropT = time };   // the support teams follow 40 s later
                    _heli limitSpeed 500;
                    _e set ["state", "postDrop"];
                    _e set ["t", time];
                };
            };
            case "postDrop": {
                if (time - (_e get "t") >= 3) then {
                    _heli flyInHeight 200;
                    _heli doMove _exit;
                    _e set ["state", "leaving"];
                    _e set ["t", time];
                };
            };
            case "leaving": {
                if (!alive _heli || { _heli distance2D _exit < 600 } || { time - (_e get "t") > 240 }) then {
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
                private _alt = getPosATL _heli select 2;
                private _onGround = isTouchingGround _heli || { _alt < 2 }
                    || { _alt < 4 && { speed _heli < 5 } && { _heli distance2D (_e get "lz") < 80 } };   // low hover: jump out
                private _stuck = time - (_e get "t") > 150;
                if (!_onGround && { round (time - (_e get "t")) mod 30 == 0 }) then { _heli land "GET OUT" };   // re-issue the order
                if (_onGround || _stuck) then {
                    {
                        unassignVehicle _x;
                        moveOut _x;
                        if (_stuck && !_onGround) then { _x setPosATL ((_e get "lz") getPos [3 + random 12, random 360]) };
                    } forEach _pass;
                    if (_stuck && !_onGround) then { ["HQ #%1: troop Taru never touched down, teleport fallback used", [_id]] call CQ_fnc_log };
                    ["Enemy troops landed", format ["HQ #%1: %2 soldiers on the ground at grid %3 (%4 m from the site)", _id, count _pass, mapGridPosition _heli, round (_heli distance2D _site)]] call CQ_fnc_announce;
                    _e set ["state", "unloaded"];
                    _e set ["t", time];
                };
            };
            case "unloaded": {
                if (time - (_e get "t") >= 3) then {
                    deleteVehicle (_e get "pad");
                    [_e, "transport"] call _toFleet;
                };
            };
            case "leaving": {
                if (!alive _heli || { _heli distance2D _exit < 600 } || { time - (_e get "t") > 240 }) then {
                    [_heli, _e get "grp"] call _deleteHeli;
                    _e set ["state", "gone"];
                };
            };
        };
    } forEach _troops;

    if (!_handed && { (_troops findIf { (_x get "state") in ["fly", "landing"] }) == -1 }) then { call _handoff };

    private _pending = (_lifts + _troops) findIf { (_x get "state") in ["fly", "near", "landing", "postDrop", "unloaded", "leaving"] };
    if (_pending == -1) exitWith {};
    if (time - _t0 > 900) exitWith { ["HQ #%1: insertion timed out after 15 min", [_id]] call CQ_fnc_log };
};

// Escorts join the fleet once the drop is over (or leave when it is full)
{
    _x params ["_heli", "_hg"];
    if (alive _heli) then {
        if !([_heli, _hg, "armed", _id, objNull, _site] call CQ_fnc_airRegister) then {
            [_hg] call CQ_fnc_clearWaypoints;
            _heli doMove _exit;
            [_heli, _hg, _site, _deleteHeli] spawn {
                params ["_heli", "_hg", "_site", "_del"];
                private _t = time;
                waitUntil { sleep 5; !alive _heli || { _heli distance2D _exit < 600 } || { time - _t > 300 } };
                [_heli, _hg] call _del;
            };
        };
    };
} forEach _escorts;

// ---------------------------------------------------------------- securing
// Normally already handed off when the troops landed; here only after a timeout
if (!_handed) then { call _handoff };
