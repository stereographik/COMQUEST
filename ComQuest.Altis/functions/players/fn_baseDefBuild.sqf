/*
    CQ_fnc_baseDefBuild  (server)
    [_spot] call CQ_fnc_baseDefBuild;
    One base defence spot: a Titan AA launcher and an HMG behind a ring of sandbags with a
    short H-barrier wall facing out, both crewed by NATO gunners. Old pieces are removed.
*/
params ["_s"];
{ if (!isNull _x) then { { deleteVehicle _x } forEach crew _x; deleteVehicle _x } } forEach (_s get "objs");
private _p = _s get "pos";
private _dir = _s get "dir";
private _objs = [];
private _mk = {
    params ["_cls", "_dist", "_ang", ["_rot", 0]];
    private _q = if (_dist > 0) then { _p getPos [_dist, _dir + _ang] } else { _p };
    private _o = createVehicle [_cls, _q, [], 0, "CAN_COLLIDE"];
    _o setDir (_dir + _rot);
    _o setVectorUp surfaceNormal _q;
    _objs pushBack _o;
    _o
};
{ ["Land_BagFence_Round_F", 4.2, _x, _x + 180] call _mk } forEach [-60, 0, 60, 180];
["Land_HBarrier_3_F", 6.5, 0, 0] call _mk;
private _g = createGroup [west, true];
{
    _x params ["_cls", "_ang"];
    private _w = [_cls, 1.6, _ang, 0] call _mk;
    createVehicleCrew _w;
    (crew _w) joinSilent _g;
} forEach [["B_static_AA_F", -90], ["B_HMG_01_high_F", 90]];
_g setBehaviour "AWARE";
_g setCombatMode "RED";
_s set ["objs", _objs];
_s set ["lostT", -1];
