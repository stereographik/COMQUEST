/*
    CQ_fnc_rearmUnit  (server)
    [_unit, _stock] call CQ_fnc_rearmUnit  ->  stock left
    Tops a soldier up to his loadout (CQ_fnc_unitPrep values), paying from _stock.
*/
params ["_u", "_stock"];

private _t = _u getVariable ["CQ_magTarget", -1];
if (_t >= 0) then {
    private _cls = _u getVariable ["CQ_magClass", ""];
    private _cost = _u getVariable ["CQ_magCost", CQ_costMag];
    private _need = _t - ({ _x == _cls } count (magazines _u));
    private _n = floor (_stock / _cost) min _need;
    if (_n > 0) then {
        _u addMagazines [_cls, _n];
        _stock = _stock - _n * _cost;
    };
};

private _rt = _u getVariable ["CQ_rktTarget", -1];
if (_rt >= 0) then {
    private _cls = _u getVariable ["CQ_rktClass", ""];
    private _need = _rt - ({ _x == _cls } count (magazines _u));
    private _n = floor (_stock / CQ_costRocket) min _need;
    if (_n > 0) then {
        _u addMagazines [_cls, _n];
        _stock = _stock - _n * CQ_costRocket;
    };
};

_stock
