/*
    CQ_fnc_objSpot  (server, from CQ_fnc_linkTick)
    [_drones] call CQ_fnc_objSpot;   _drones: our flying UAVs (MAGPIE, WASP, players' own drones)
    Enemy HQ objectives (AA pits, HMG tower, radio tower, depot, fuel tanker) are no longer marked
    on the map by themselves: a UAV has to see one (within its sensor radius, line of sight), and
    the intel has to reach the base over the data link. A drone that sees one while cut off keeps
    it and sends it as soon as it is linked again. Once sent, the objective is known for good
    (CQ_spotted, public): CQ_fnc_hqStatusMarker marks it.
*/
params ["_drones"];
// a Darter sent to look is done after CQ_objLookTime s: back to the fleet's flight plans
{
    if ((_x getOrDefault ["lookUntil", 0]) > 0 && { time >= (_x get "lookUntil") }) then {
        _x set ["lookUntil", 0]; _x set ["planT", -1e6];
        ["MAGPIE: %1 done looking, back to the fleet", [_x get "name"]] call CQ_fnc_log;
    };
} forEach CQ_mag;

private _objs = [];
{
    { if (alive _x && { !(_x getVariable ["CQ_spotted", false]) }) then { _objs pushBack _x } } forEach (_x get "installations");
} forEach ((values CQ_hqs) select { (_x get "state") != "Destroyed" });
if (_objs isEqualTo []) exitWith {};
// a new objective spotted: the nearest awake Watcher Darter goes to look around it for
// CQ_objLookTime s (the HQ's other objectives are usually close), kept CQ_magAaAvoid m from a
// known Tigris and CQ_objLookAaR m from a known AA pit
private _look = {
    params ["_o"];
    private _p = getPosATL _o;
    private _free = CQ_mag select {
        (_x getOrDefault ["role", ""]) == "dormant" && { alive (_x get "veh") } && { (_x getOrDefault ["phase", ""]) == "air" }
        && { !(_x getOrDefault ["flee", false]) } && { time >= (_x getOrDefault ["lookUntil", 0]) }
    };
    if (_free isEqualTo []) exitWith {};
    private _m = ([_free, [], { (_x get "veh") distance2D _p }, "ASCEND"] call BIS_fnc_sortBy) select 0;
    private _aa = (((values CQ_magSeen) select { alive (_x select 0) && { time - (_x select 2) < CQ_magMemory } && { (typeOf (_x select 0)) in CQ_magAaClasses } }) apply { [_x select 3, CQ_magAaAvoid] })
        + ((flatten ((values CQ_hqs) apply { _x get "installations" })) select { alive _x && { _x getVariable ["CQ_spotted", false] } && { (_x getVariable ["CQ_objType", ""]) == "AA" } } apply { [getPosATL _x, CQ_objLookAaR] });
    private _t = _p;
    { _x params ["_ap", "_ar"]; if (_t distance2D _ap < _ar) then { _t = _ap getPos [_ar, _ap getDir ((_m get "veh") getPos [0, 0])] } } forEach _aa;
    private _v = _m get "veh";
    private _g = group effectiveCommander _v;
    [_g] call CQ_fnc_clearWaypoints;
    _v flyInHeight CQ_magDormantAlt;
    private _wp = _g addWaypoint [[_t select 0, _t select 1, 0], 0];
    _wp setWaypointType "LOITER";
    _wp setWaypointLoiterRadius 250;
    _g setCurrentWaypoint _wp;
    _m set ["lookUntil", time + CQ_objLookTime + ((_v distance2D _t) / 30)];   // + the flight there
    _m set ["target", []];
    ["MAGPIE: %1 goes to look around the %2 at grid %3 (%4 m from it)", [_m get "name", _o getVariable ["CQ_objType", "objective"], mapGridPosition _t, round (_t distance2D _p)]] call CQ_fnc_log;
};
CQ_magSensor params ["_r0", "_rk", "_rmax"];
{
    private _v = _x;
    private _alt = (getPosATL _v) select 2;
    if (_alt < 40) then { continue };
    private _r = (_r0 + _alt * _rk) min _rmax;
    if (_v isKindOf "UAV_01_base_F" && { time < (missionNamespace getVariable ["CQ_hstBoostUntil", -1]) }) then { _r = _r * CQ_hstBoost };
    private _eye = getPosASL _v vectorAdd [0, 0, -1.5];
    private _held = _v getVariable ["CQ_objHeld", []];
    {
        if (_x in _held) then { continue };
        if (_v distance2D _x > _r) then { continue };
        private _tp = (getPosASL _x) vectorAdd [0, 0, 2];
        if (terrainIntersectASL [_eye, _tp]) then { continue };
        _held pushBack _x;
    } forEach _objs;
    // linked: what it holds reaches the base
    if (_held isNotEqualTo [] && { _v getVariable ["CQ_linked", false] }) then {
        {
            if (alive _x && { !(_x getVariable ["CQ_spotted", false]) }) then {
                _x setVariable ["CQ_spotted", true, true];
                ["Objective spotted by %1: %2 at grid %3 (intel reached the base)", [_v getVariable ["CQ_magName", typeOf _v], _x getVariable ["CQ_objType", "objective"], mapGridPosition _x]] call CQ_fnc_log;
                [_x] call _look;
            };
        } forEach _held;
        _held = [];
    };
    _v setVariable ["CQ_objHeld", _held];
} forEach _drones;
