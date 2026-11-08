/*
    CQ_fnc_coastSafe
    [_pos, _gap] call CQ_fnc_coastSafe  ->  bool
    True when there is no water within _gap metres of _pos (16 directions, 3 rings).
*/
params ["_p", ["_gap", 350]];
if (surfaceIsWater _p) exitWith { false };
private _ok = true;
{
    private _r = _x;
    for "_a" from 0 to 337.5 step 22.5 do {
        if (surfaceIsWater (_p getPos [_r, _a])) exitWith { _ok = false };
    };
    if (!_ok) exitWith {};
} forEach [_gap / 3, _gap * 2 / 3, _gap];
_ok
