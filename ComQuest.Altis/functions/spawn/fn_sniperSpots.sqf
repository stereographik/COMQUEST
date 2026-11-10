/*
    CQ_fnc_sniperSpots  (server)
    [_hqPos, _n] call CQ_fnc_sniperSpots  ->  up to _n positions
    Overwatch spots for an HQ: high ground CQ_sniperDist m from it, in the arc CQ_sniperArc
    (west side). Each candidate is scored by its height above the HQ plus its local prominence
    (higher than the ground 60 m around it), with a bonus when it has a clear line of sight
    600 m to the west. Picked greedily, at least CQ_sniperGap m apart.
*/
params ["_c", ["_n", 4]];
private _h0 = getTerrainHeightASL _c;
private _cands = [];
CQ_sniperArc params ["_a0", "_a1"];
CQ_sniperDist params ["_d0", "_d1"];
for "_a" from _a0 to _a1 step 8 do {
    for "_d" from _d0 to _d1 step 100 do {
        private _p = _c getPos [_d, _a];
        if (surfaceIsWater _p) then { continue };
        private _h = getTerrainHeightASL _p;
        private _around = 0;
        for "_k" from 0 to 315 step 45 do { _around = _around + getTerrainHeightASL (_p getPos [60, _k]) };
        private _prom = _h - _around / 8;
        if (_prom < 1) then { continue };                         // not a rise: skip
        private _eye = AGLToASL [_p select 0, _p select 1, 1.2];
        private _far = _p getPos [600, 270];
        private _see = !(terrainIntersectASL [_eye, AGLToASL [_far select 0, _far select 1, 2]]);
        _cands pushBack [(_h - _h0) + 3 * _prom + ([0, 25] select _see), _p];
    };
};
_cands sort false;
private _out = [];
{
    private _p = _x select 1;
    if ((_out findIf { _x distance2D _p < CQ_sniperGap }) > -1) then { continue };
    private _q = [_p, 1.5, 15] call CQ_fnc_clearPos;
    if (_q isEqualTo []) then { continue };
    _out pushBack _q;
    if (count _out >= _n) then { break };
} forEach _cands;
_out
