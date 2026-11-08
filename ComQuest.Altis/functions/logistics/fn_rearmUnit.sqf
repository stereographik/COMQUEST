/*
    CQ_fnc_rearmUnit  (server)
    [_unit, _stock, _below] call CQ_fnc_rearmUnit  ->  stock left
    Tops a soldier up to his loadout (CQ_fnc_unitPrep values), paying from _stock, but only
    when he holds fewer than _below x his magazines (1 = always top up). Missing rockets
    are always replaced.
*/
params ["_u", "_stock", ["_below", 1]];

private _t = _u getVariable ["CQ_magTarget", -1];
private _have = ({ _x == (_u getVariable ["CQ_magClass", ""]) } count (magazines _u));
if (_t >= 0 && { _have < _t * _below || { _below >= 1 } }) then {
    private _cls = _u getVariable ["CQ_magClass", ""];
    private _cost = _u getVariable ["CQ_magCost", CQ_costMag];
    private _need = _t - _have;
    private _n = floor (_stock / _cost) min _need;
    // One at a time and only if it fits: a full inventory silently refuses addMagazines,
    // and the depot was paying anyway (drained 300 ammo in 2 min)
    while { _n > 0 && { _u canAdd _cls } } do {
        _u addMagazine _cls;
        _stock = _stock - _cost;
        _n = _n - 1;
    };
};

private _rt = _u getVariable ["CQ_rktTarget", -1];
if (_rt >= 0) then {
    private _cls = _u getVariable ["CQ_rktClass", ""];
    private _need = _rt - ({ _x == _cls } count (magazines _u));
    private _n = floor (_stock / CQ_costRocket) min _need;
    while { _n > 0 && { _u canAdd _cls } } do {
        _u addMagazine _cls;
        _stock = _stock - CQ_costRocket;
        _n = _n - 1;
    };
};

_stock
