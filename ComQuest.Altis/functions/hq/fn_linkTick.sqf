/*
    CQ_fnc_linkTick  (server, director task, every CQ_linkEvery s)
    Our data link: what MAGPIE sees only reaches the map through a chain of friendly nodes back to
    the base. Two nodes are linked when their range circles overlap (distance <= range A + range B);
    every path counts, the network is whatever is connected to the base.
      base                    CQ_netCoverBase       always linked
      relay vehicle           CQ_linkRelayVehR      sent by the base 1/3 of the way to the first HQ
      relays we hold          CQ_netCoverRelay      hacked towers, engineer relays
      friendly vehicle        CQ_linkVehR           any of ours, crewed or empty, until it despawns or blows up
      MAGPIE drone in the air CQ_linkDroneR         Sentinels and woken Darters
    A drone that is not linked flies on but reports nothing (CQ_fnc_magTick: "CQ_linked").
    Published for the map (CQ_fnc_magMapClient): CQ_linkPub = [[[pos, range, linked], ...], [[posA, posB], ...]]
    Also runs the relay vehicle: sent once the first enemy HQ is known, parked at
    CQ_linkRelayFrac of the way from the base to it, replaced CQ_linkRelayRespawn s after a loss.
*/
if (time < (missionNamespace getVariable ["CQ_linkNext", 0])) exitWith {};
CQ_linkNext = time + CQ_linkEvery;

// ---- relay vehicle
private _rv = missionNamespace getVariable ["CQ_linkRelayVeh", objNull];
if (!alive _rv && { time >= (missionNamespace getVariable ["CQ_linkRelayT", 0]) }) then {
    private _roots = ((values CQ_hqs) select { (_x getOrDefault ["parent", -1]) == -1 && { (_x get "state") in CQ_activeStates } });
    if (_roots isEqualTo []) exitWith {};
    private _root = ([_roots, [], { _x get "id" }] call BIS_fnc_sortBy) select 0;
    private _hp = _root get "pos";
    private _dest = CQ_basePos vectorAdd ((_hp vectorDiff CQ_basePos) vectorMultiply CQ_linkRelayFrac);
    private _road = [_dest, 300] call BIS_fnc_nearestRoad;
    if (!isNull _road) then { _dest = getPosATL _road };
    private _sp = (CQ_basePos getPos [60, CQ_basePos getDir _hp]) findEmptyPosition [0, 80, CQ_linkRelayClass];
    if (_sp isEqualTo []) then { _sp = CQ_basePos getPos [60, CQ_basePos getDir _hp] };
    _rv = createVehicle [CQ_linkRelayClass, _sp, [], 0, "NONE"];
    _rv setDir (CQ_basePos getDir _hp);
    _rv setVariable ["CQ_linkRelay", true, true];
    createVehicleCrew _rv;                        // a proper crew (driver + commander), then locked
    private _g = group driver _rv;
    _rv lock 2;                                   // the base's relay: not a ride
    _rv enableDynamicSimulation false;
    _g enableDynamicSimulation false;
    _g setBehaviour "CARELESS"; _g setCombatMode "BLUE"; _g setSpeedMode "FULL";
    { _x disableAI "AUTOCOMBAT"; _x disableAI "TARGET" } forEach units _g;
    _rv engineOn true;
    _g move _dest;
    (driver _rv) doMove _dest;
    _rv setVariable ["CQ_linkMoveT", time];
    _rv setVariable ["CQ_linkLastP", getPosATL _rv];
    _rv setVariable ["CQ_linkDest", _dest];
    _rv addEventHandler ["Killed", {
        CQ_linkRelayT = time + CQ_linkRelayRespawn;
        ["Relay vehicle lost", format ["The base's relay vehicle is destroyed at grid %1: another one leaves in %2 min", mapGridPosition (_this select 0), round (CQ_linkRelayRespawn / 60)]] call CQ_fnc_announce;
    }];
    CQ_linkRelayVeh = _rv;
    ["Relay vehicle", format ["The base sends a relay vehicle toward grid %1 (%2 m out), to stretch MAGPIE's data link", mapGridPosition _dest, round (_dest distance2D CQ_basePos)]] call CQ_fnc_announce;
};
if (alive _rv && { !(_rv getVariable ["CQ_linkParked", false]) }) then {
    private _dest = _rv getVariable ["CQ_linkDest", getPosATL _rv];
    // on the road: progress check every 30 s, a stuck drive gets a new order then a short hop
    if (time - (_rv getVariable ["CQ_linkMoveT", time]) > 30) then {
        private _moved = _rv distance2D (_rv getVariable ["CQ_linkLastP", getPosATL _rv]);
        ["Relay vehicle: %1 m from its spot (moved %2 m in 30 s)", [round (_rv distance2D _dest), round _moved]] call CQ_fnc_log;
        if (_moved < 10) then {
            if (_moved < 2 && { (_rv getVariable ["CQ_linkStuck", 0]) >= 1 }) then {
                private _p = (_rv getPos [25, _rv getDir _dest]) findEmptyPosition [0, 40, typeOf _rv];
                if (_p isNotEqualTo []) then { _rv setVelocity [0, 0, 0]; _rv setPosATL [_p select 0, _p select 1, 0.3] };
            };
            _rv setVariable ["CQ_linkStuck", (_rv getVariable ["CQ_linkStuck", 0]) + 1];
            _rv engineOn true;
            (group driver _rv) move _dest;
            (driver _rv) doMove _dest;
        } else { _rv setVariable ["CQ_linkStuck", 0] };
        _rv setVariable ["CQ_linkMoveT", time];
        _rv setVariable ["CQ_linkLastP", getPosATL _rv];
    };
    if (_rv distance2D _dest < 40 || { speed _rv < 1 && { _rv distance2D _dest < 200 } }) then {
        _rv setVariable ["CQ_linkParked", true];
        doStop (driver _rv);
        _rv engineOn false;
        ["Relay vehicle parked at grid %1 (%2 m from the base)", [mapGridPosition _rv, round (_rv distance2D CQ_basePos)]] call CQ_fnc_log;
    };
};

// ---- nodes
private _nodes = [[CQ_basePos, CQ_netCoverBase, objNull]];
{ if (alive (_x select 1)) then { _nodes pushBack [_x select 2, CQ_netCoverRelay, _x select 1] } } forEach (missionNamespace getVariable ["CQ_relays", []]);
if (alive _rv) then { _nodes pushBack [getPosATL _rv, CQ_linkRelayVehR, _rv] };
private _drones = [];
{
    private _v = _x get "veh";
    if (alive _v && { (_x getOrDefault ["phase", ""]) == "air" }) then { _drones pushBack _v; _nodes pushBack [getPosATL _v, CQ_linkDroneR, _v] };
} forEach (missionNamespace getVariable ["CQ_mag", []]);
{
    // ours, crewed or not (a parked empty vehicle relays until it despawns or blows up): a BLUFOR
    // model, or anything with our people inside
    if (alive _x && { _x != _rv } && { !(_x in _drones) } && { !(_x isKindOf "StaticWeapon") } && { !(_x isKindOf "ParachuteBase") }
        && { getNumber (configOf _x >> "side") == 1 || { (crew _x) isNotEqualTo [] && { side group effectiveCommander _x == west } } }) then {
        _nodes pushBack [getPosATL _x, CQ_linkVehR, _x];
    };
} forEach vehicles;

// ---- links: overlapping ranges, flood from the base
private _n = count _nodes;
private _ok = [true] + ((_nodes select [1]) apply { false });
private _edges = [];
private _grow = true;
while { _grow } do {
    _grow = false;
    for "_a" from 0 to _n - 1 do {
        if !(_ok select _a) then { continue };
        (_nodes select _a) params ["_pa", "_ra"];
        for "_b" from 0 to _n - 1 do {
            if (_ok select _b) then { continue };
            (_nodes select _b) params ["_pb", "_rb"];
            if (_pa distance2D _pb <= _ra + _rb) then { _ok set [_b, true]; _edges pushBack [_pa, _pb]; _grow = true };
        };
    };
};
{
    private _v = _x;
    private _l = _ok select (_nodes findIf { (_x select 2) == _v });
    if ((_v getVariable ["CQ_linked", -1]) isNotEqualTo _l) then { _v setVariable ["CQ_linked", _l, true] };   // public: the map shows a Darter only while linked
} forEach _drones;
if (alive _rv) then { _rv setVariable ["CQ_linked", true] };

private _pub = [_nodes apply { [_x select 0, _x select 1, false] }, _edges];
{ ((_pub select 0) select _forEachIndex) set [2, _x] } forEach _ok;
// a drone out of the network is not on our map at all (its range circle would give it away)
private _shown = [];
{ if ((_x select 2) || { !(((_nodes select _forEachIndex) select 2) in _drones) }) then { _shown pushBack _x } } forEach (_pub select 0);
_pub set [0, _shown];
CQ_linkPub = _pub;
publicVariable "CQ_linkPub";
if (CQ_debug || { time - (missionNamespace getVariable ["CQ_linkLogT", -1e6]) > 60 }) then {
    CQ_linkLogT = time;
    ["Data link: %1 nodes, %2 linked, drones linked %3/%4", [_n, { _x } count _ok, { _x getVariable ["CQ_linked", false] } count _drones, count _drones]] call CQ_fnc_log;
};
