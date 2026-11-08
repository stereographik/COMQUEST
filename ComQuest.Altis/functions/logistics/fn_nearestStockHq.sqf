/*
    CQ_fnc_nearestStockHq
    [_pos, _minStock] call CQ_fnc_nearestStockHq  ->  HQ record, or an empty HashMap
    Nearest built HQ whose depot stands and holds at least _minStock ammo points.
*/
params ["_pos", ["_minStock", CQ_rearmMinStock]];

private _best = createHashMap;
private _bd = 1e9;
{
    private _h = _y;
    if ((_h get "state") in CQ_activeStates && { _h get "buildDone" } && { alive (_h get "depot") } && { (_h get "stock") >= _minStock }) then {
        private _d = (_h get "pos") distance2D _pos;
        if (_d < _bd) then { _bd = _d; _best = _h };
    };
} forEach CQ_hqs;

_best
