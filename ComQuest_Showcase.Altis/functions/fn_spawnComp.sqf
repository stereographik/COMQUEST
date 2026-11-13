/*
    SC_fnc_spawnComp - [_index, _anchor, _dir] call SC_fnc_spawnComp -> [[object, row], ...]
    Places composition _index (validated rows, SC_rows) centred on _anchor (2D), turned _dir deg.
    Heights: offsets above the terrain height at the anchor (flat ground expected).
    ["move", [_pairs, _anchor, _dir]] call SC_fnc_spawnComp  re-places existing objects.
*/
private _put = {
    params ["_o", "_row", "_anchor", "_dir", "_z0"];
    _row params ["", "_off", "_yaw", "_pitch", "_bank"];
    _off params ["_dx", "_dy", "_dz"];
    private _wx = (_anchor select 0) + _dx * cos _dir + _dy * sin _dir;
    private _wy = (_anchor select 1) - _dx * sin _dir + _dy * cos _dir;
    _o setDir (_yaw + _dir);
    _o setPosASL [_wx, _wy, _z0 + _dz];
    if (_pitch != 0 || { _bank != 0 }) then { [_o, _pitch, _bank] call BIS_fnc_setPitchBank };
};
if (_this isEqualType [] && { (_this select 0) isEqualTo "move" }) exitWith {
    (_this select 1) params ["_pairs", "_anchor", "_dir"];
    private _z0 = getTerrainHeightASL _anchor;
    { _x params ["_o", "_row"]; [_o, _row, _anchor, _dir, _z0] call _put } forEach _pairs;
    _pairs
};
params ["_i", "_anchor", ["_dir", 0]];
private _z0 = getTerrainHeightASL _anchor;
private _pairs = [];
{
    private _row = _x;
    _row params ["_cls", "", "", "", "", "_simple", "_noSim"];
    private _o = if (_simple == 1) then { createSimpleObject [_cls, [0, 0, 0]] } else { createVehicle [_cls, [0, 0, 0], [], 0, "CAN_COLLIDE"] };
    if (!isNull _o) then {
        if (_simple == 0) then { _o allowDamage false; if (_noSim == 1) then { _o enableSimulationGlobal false } };
        [_o, _row, _anchor, _dir, _z0] call _put;
        _pairs pushBack [_o, _row];
    };
} forEach (SC_rows select _i);
_pairs
