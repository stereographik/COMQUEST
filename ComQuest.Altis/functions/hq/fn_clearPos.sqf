/*
    CQ_fnc_clearPos
    [_pos, _radius, _maxShift, _ignore] call CQ_fnc_clearPos  ->  position or []
    Returns _pos if it is clear (CQ_fnc_isClear), else the nearest clear spot on rings
    every 3 m out to _maxShift, else [].
*/
params ["_pos", "_r", ["_maxShift", 6], ["_ignore", []]];

if (!surfaceIsWater _pos && { [_pos, _r, _ignore] call CQ_fnc_isClear }) exitWith { _pos };

private _res = [];
for "_d" from 3 to _maxShift step 3 do {
    for "_a" from 0 to 330 step 30 do {
        private _p = _pos getPos [_d, _a];
        if (!surfaceIsWater _p && { [_p, _r, _ignore] call CQ_fnc_isClear }) exitWith { _res = _p };
    };
    if (_res isNotEqualTo []) exitWith {};
};
_res
