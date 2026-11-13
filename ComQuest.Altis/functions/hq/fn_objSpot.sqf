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
private _objs = [];
{
    { if (alive _x && { !(_x getVariable ["CQ_spotted", false]) }) then { _objs pushBack _x } } forEach (_x get "installations");
} forEach ((values CQ_hqs) select { (_x get "state") != "Destroyed" });
if (_objs isEqualTo []) exitWith {};
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
            };
        } forEach _held;
        _held = [];
    };
    _v setVariable ["CQ_objHeld", _held];
} forEach _drones;
