/*
    CQ_fnc_infAmmo
    [_group] call CQ_fnc_infAmmo  ->  0..1, average share of a full rifle reload left
    (magazines carried + the loaded one) over the group's living soldiers.
*/
params ["_g"];

private _sum = 0;
private _n = 0;
{
    private _u = _x;
    private _t = _u getVariable ["CQ_magTarget", -1];
    if (_t < 0) then { continue };
    private _cls = _u getVariable ["CQ_magClass", ""];
    private _have = ({ _x == _cls } count (magazines _u)) + ([0, 1] select ((_u ammo primaryWeapon _u) > 0));
    _sum = _sum + ((_have / (_t + 1)) min 1);
    _n = _n + 1;
} forEach ((units _g) select { alive _x });

if (_n == 0) exitWith { 1 };
_sum / _n
