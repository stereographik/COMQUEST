/*
    CQ_fnc_grassCut  (client, once, from initPlayerLocal)
    No grass within CQ_grassCutRadius m of the base centre (CQ_basePos): at most
    CQ_grassCutMax big "splats" on a hexagonal grid, each a large clutter cutter enlarged
    CQ_grassCutScale times. Object scaling only works on local simple objects, so every
    player builds his own set (grass is drawn locally anyway).
*/
if (!hasInterface || { !CQ_grassCut } || { !isNil "CQ_grassCutDone" }) exitWith {};
CQ_grassCutDone = true;
private _r = CQ_grassCutRadius;
// spacing: the tightest hexagonal grid that fits in CQ_grassCutMax points
private _s = 0.75 * sqrt ((pi * _r ^ 2) / (0.866 * CQ_grassCutMax));
private _pts = [];
while { true } do {
    _pts = [];
    private _dy = _s * 0.866;
    for "_j" from -ceil (_r / _dy) to ceil (_r / _dy) do {
        for "_i" from -ceil (_r / _s) - 1 to ceil (_r / _s) + 1 do {
            private _x0 = (_i + 0.5 * (_j mod 2)) * _s;
            private _y0 = _j * _dy;
            if (sqrt (_x0 ^ 2 + _y0 ^ 2) <= _r - _s * 0.25) then { _pts pushBack [(CQ_basePos select 0) + _x0, (CQ_basePos select 1) + _y0, 0] };
        };
    };
    if (count _pts <= CQ_grassCutMax) exitWith {};
    _s = _s * 1.04;
};
{
    private _o = createSimpleObject ["Land_ClutterCutter_large_F", AGLToASL _x, true];
    if (!isNull _o) then { _o setObjectScale CQ_grassCutScale };
} forEach _pts;
["Grass cut: %1 splats, %2 m apart, scale %3, %4 m around the base", [count _pts, round _s, CQ_grassCutScale, _r]] call CQ_fnc_log;
