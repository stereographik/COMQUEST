/*
    CQ_fnc_waveSend  (server, spawned)
    [_hq] spawn CQ_fnc_waveSend;
    One reinforcement wave: 1 truck + 1 armour + 1 random vehicle (CQ_wavePools) with
    CQ_waveSquads squads aboard, spawned on a road 1-1.5 km from the HQ with no player within
    CQ_waveNoPlayerRadius, driving in. On arrival (or loss / timeout) it writes
    _hq "waveResult" = [infantryGroups, vehicles] for CQ_fnc_hqTick.
*/
params ["_hq"];

private _id = _hq get "id";
private _c = _hq get "pos";
private _squadCfg = configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad";

// --- spawn point on a road
private _spawn = [];
for "_i" from 1 to 30 do {
    private _from = if (isNil "CQ_carrierPos") then { random 360 } else { (_c getDir CQ_carrierPos) - CQ_waveSpread + random (2 * CQ_waveSpread) };
    if (_i > 20) then { _from = random 360 };    // nothing on the carrier side: any road
    private _p = _c getPos [(CQ_waveSpawnDist select 0) + random ((CQ_waveSpawnDist select 1) - (CQ_waveSpawnDist select 0)), _from];
    private _roads = _p nearRoads 200;
    if (_roads isEqualTo []) then { continue };
    private _rp = getPosATL (selectRandom _roads);
    if (surfaceIsWater _rp) then { continue };
    if ((allPlayers findIf { _x distance2D _rp < CQ_waveNoPlayerRadius }) > -1) then { continue };
    _spawn = _rp;
    break;
};
if (_spawn isEqualTo []) exitWith {
    ["HQ #%1: no road spawn point for the wave, will retry", [_id]] call CQ_fnc_log;
    _hq set ["waveResult", [[], []]];
};

// --- vehicles, one per pool, 18 m apart along the way in, each spot spacing-checked
private _dir = _spawn getDir _c;
private _vehs = [];
{
    _x params ["_pool", "_classes"];
    private _cls = selectRandom _classes;
    private _want = _spawn getPos [18 * _forEachIndex, _dir + 180];
    private _p = [_want, 6, 24] call CQ_fnc_clearPos;
    if (_p isEqualTo []) then { _p = _want };
    private _v = createVehicle [_cls, _p, [], 0, "NONE"];
    _v setDir _dir;
    _v setVariable ["CQ_pool", _pool];
    private _cg = [_v] call CQ_fnc_crewVehicle;
    _cg setBehaviour "AWARE";
    [_v, CQ_vehSpawnAmmo] call CQ_fnc_vehAmmoInit;
    _vehs pushBack _v;
} forEach CQ_wavePools;

// --- infantry aboard (truck first, then armour, then the random vehicle)
private _inf = [];
private _lost = 0;
for "_i" from 1 to CQ_waveSquads do {
    private _g = [_spawn getPos [30, _dir + 90], east, _squadCfg] call BIS_fnc_spawnGroup;
    [units _g] call CQ_fnc_unitPrep;
    {
        private _u = _x;
        private _in = false;
        { if (!_in && { (_x emptyPositions "cargo") > 0 }) then { _u moveInCargo _x; _in = vehicle _u != _u } } forEach _vehs;
        if (!_in) then { deleteVehicle _u; _lost = _lost + 1 };
    } forEach units _g;
    _g setVariable ["CQ_role", "reinf"];
    _inf pushBack _g;
};

["Enemy reinforcements en route", format ["HQ #%1: %2 with %3 soldiers, %4 m out",
    _id, (_vehs apply { getText (configOf _x >> "displayName") }) joinString " + ",
    [_inf] call CQ_fnc_aliveCount, round (_spawn distance2D _c)]] call CQ_fnc_announce;
if (_lost > 0) then { ["HQ #%1: wave, %2 soldiers did not fit and were removed", [_id, _lost]] call CQ_fnc_log };

// --- drive in
private _dest = _c getPos [70, _dir + 180];
{ (group effectiveCommander _x) move _dest } forEach _vehs;

private _t0 = time;
private _arrived = false;
while { true } do {
    sleep 2;
    if (_hq get "waveSkip") exitWith {
        _hq set ["waveSkip", false];
        {
            if (alive _x) then {
                private _p = [_c getPos [70 + 15 * _forEachIndex, random 360], 6, 40] call CQ_fnc_clearPos;
                if (_p isEqualTo []) then { _p = _c getPos [80 + 15 * _forEachIndex, random 360] };
                _x setPosATL _p;
            };
        } forEach _vehs;
        _arrived = true;
        ["HQ #%1: DEBUG skip, wave convoy moved to the HQ", [_id]] call CQ_fnc_log;
    };
    private _alive = _vehs select { alive _x && { canMove _x } };
    if (_alive findIf { _x distance2D _c < 200 } > -1) exitWith { _arrived = true };
    if (_alive isEqualTo []) exitWith {};
    if (time - _t0 > 900) exitWith { ["HQ #%1: wave convoy timed out, dismounting where it is", [_id]] call CQ_fnc_log };
};

// --- dismount
{
    private _g = _x;
    { _g leaveVehicle _x } forEach _vehs;
    { if (vehicle _x != _x) then { unassignVehicle _x; moveOut _x } } forEach units _g;
    _g move (_c getPos [40, random 360]);
} forEach _inf;

private _infAlive = _inf select { ({ alive _x } count units _x) > 0 };
if (_arrived) then {
    ["Enemy reinforcements arrived", format ["HQ #%1 received %2 soldiers", _id, [_infAlive] call CQ_fnc_aliveCount]] call CQ_fnc_announce;
} else {
    ["Enemy convoy stopped", format ["HQ #%1: reinforcement convoy destroyed or stuck, %2 soldiers walking in", _id, [_infAlive] call CQ_fnc_aliveCount]] call CQ_fnc_announce;
};

_hq set ["waveResult", [_infAlive, _vehs select { alive _x }]];
CQ_balanceForceT = time + 10;   // redispatch over the network once the wave has joined (CQ_fnc_hqBalance)
