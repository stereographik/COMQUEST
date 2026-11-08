/*
    CQ_fnc_nearestStockHq
    [_pos, _minStock, _key] call CQ_fnc_nearestStockHq  ->  HQ record, or an empty HashMap
    Nearest built HQ whose depot stands and holds at least _minStock of _key ("stock" = ammo, "fuel").
*/
params ["_pos", ["_minStock", CQ_rearmMinStock], ["_key", "stock"]];

private _best = createHashMap;
private _bd = 1e9;
{
    private _h = _y;
    if ((_h get "state") in CQ_activeStates && { _h get "buildDone" } && { alive (_h get "depot") } && { (_h get _key) >= _minStock }) then {
        private _d = (_h get "pos") distance2D _pos;
        if (_d < _bd) then { _bd = _d; _best = _h };
    };
} forEach CQ_hqs;

_best
