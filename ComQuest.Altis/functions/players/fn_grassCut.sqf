/*
    CQ_fnc_grassCut  (client, once, from initPlayerLocal)
    No grass within CQ_grassCutRadius m of the base centre (CQ_basePos): large clutter
    cutters at their normal size on a hexagonal grid CQ_grassCutSpacing m apart, created as
    local simple objects (grass is drawn locally; nothing goes over the network).
    Not enlarged: scaled cutters grow an invisible collision that made players fall in place.
*/
if (!hasInterface || { !CQ_grassCut } || { !isNil "CQ_grassCutDone" }) exitWith {};
CQ_grassCutDone = true;
private _r = CQ_grassCutRadius;
private _s = CQ_grassCutSpacing;
private _dy = _s * 0.866;
private _n = 0;
for "_j" from -ceil (_r / _dy) to ceil (_r / _dy) do {
    for "_i" from -ceil (_r / _s) - 1 to ceil (_r / _s) + 1 do {
        private _x0 = (_i + 0.5 * (_j mod 2)) * _s;
        private _y0 = _j * _dy;
        if (sqrt (_x0 ^ 2 + _y0 ^ 2) > _r) then { continue };
        private _p = [(CQ_basePos select 0) + _x0, (CQ_basePos select 1) + _y0, 0];
        if (!isNull (createSimpleObject ["Land_ClutterCutter_large_F", AGLToASL _p, true])) then { _n = _n + 1 };
    };
};
["Grass cut: %1 cutters, %2 m apart, %3 m around the base", [_n, _s, _r]] call CQ_fnc_log;
