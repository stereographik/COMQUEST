/*
    CQ_fnc_compoPlace  (server)
    [_name, _keyPos, _keyDir, _objects] call CQ_fnc_compoPlace;   -> [[role, posATL, dir], ...]
    Puts up the decor of one of Django's Eden models (CQ_compos, cfg\compositions.sqf) around a key
    object already placed at _keyPos facing _keyDir. The key itself and the role rows (aa, term,
    pad) are NOT placed: their spots come back, the caller builds them.
    Trees, bushes, rocks, walls and fences under the model are hidden first. Every placed object
    is pushed into _objects (the HQ's object list, so it goes away with the HQ).
    Barriers and props run without simulation (CPU); buildings keep it (doors, building positions).
*/
params ["_name", "_kp", "_kd", "_objects"];
private _rows = CQ_compos getOrDefault [_name, []];
if (_rows isEqualTo []) exitWith { ["Compo: no model '%1'", [_name]] call CQ_fnc_log; [] };
private _kp2 = [_kp select 0, _kp select 1, 0];

// footprint: farthest object + a margin
private _rad = 4;
{ private _o = _x select 1; _rad = _rad max (sqrt (((_o select 0) ^ 2) + ((_o select 1) ^ 2)) + 4) } forEach _rows;
{ _x hideObjectGlobal true } forEach (nearestTerrainObjects [_kp2, CQ_compoClearTypes, _rad, false, true]);
// nothing of ours spawns inside walls: enemy men on foot and land vehicles step out to the rim first
{ _x setPosATL (_kp2 getPos [_rad + 4, _kp2 getDir _x]) } forEach ((_kp2 nearEntities [["CAManBase"], _rad]) select { side group _x == east && { vehicle _x == _x } });
{
    private _q = (_kp2 getPos [_rad + 8, _kp2 getDir _x]) findEmptyPosition [0, 40, typeOf _x];
    if (_q isNotEqualTo []) then { _x setVelocity [0, 0, 0]; _x setPosATL [_q select 0, _q select 1, 0.3] };
} forEach ((_kp2 nearEntities [["Car", "Tank"], _rad]) select { !(_x in _objects) && { !(_x isKindOf "StaticWeapon") } && { side _x == east || { (_x getVariable ["CQ_hqId", -1]) > -1 } } && { ((crew _x) findIf { isPlayer _x }) == -1 } });

private _spots = [];
private _n = 0;
{
    _x params ["_cls", "_off", "_dir", "_role"];
    _off params ["_ox", "_oy", "_oz"];
    private _p = _kp2 getPos [sqrt (_ox ^ 2 + _oy ^ 2), _kd + (_ox atan2 _oy)];
    if (_role == "") then {
        private _o = createVehicle [_cls, [0, 0, 0], [], 0, "CAN_COLLIDE"];
        _o setDir (_kd + _dir);
        _o setPosATL [_p select 0, _p select 1, _oz];
        if (_oz == 0) then { _o setVectorUp surfaceNormal _p };
        if ((CQ_compoLive findIf { (toLowerANSI _cls) find _x > -1 }) == -1) then { _o enableSimulationGlobal false };
        _objects pushBack _o;
        _n = _n + 1;
    } else {
        if (_role != "key") then { _spots pushBack [_role, [_p select 0, _p select 1, _oz], _kd + _dir] };
    };
} forEach _rows;
["Compo: %1 up at grid %2 (%3 objects, %4 m footprint)", [_name, mapGridPosition _kp2, _n, round _rad]] call CQ_fnc_log;
_spots
