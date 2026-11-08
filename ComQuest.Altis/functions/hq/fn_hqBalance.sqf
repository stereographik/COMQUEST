/*
    CQ_fnc_hqBalance  (server, director task, every CQ_balanceInterval)
    Keeps the infantry spread evenly over every fully built HQ: when an HQ has more than
    the average (+ CQ_balanceMargin) and another has less (- CQ_balanceMargin), free squads
    (patrol / fresh reinforcements, enough ammo) are redeployed with CQ_fnc_moveGroups.
    Orders go by radio: both HQs need a standing radio tower. One redeployment per HQ at a
    time, none from an HQ in contact, the donor always keeps CQ_minDefenders.
*/
if (time < CQ_balanceNext) exitWith {};
CQ_balanceNext = time + CQ_balanceInterval;

private _built = (values CQ_hqs) select {
    (_x get "state") in CQ_activeStates && { _x get "buildDone" } && { alive (_x get "radio") }
};
if (count _built < 2) exitWith {};

// Infantry per HQ, counting squads already on their way to it
private _count = {
    params ["_h"];
    ([(_h get "infantry")] call CQ_fnc_aliveCount) + (_h getOrDefault ["incoming", 0])
};
private _total = 0;
{ _total = _total + ([_x] call _count) } forEach _built;
private _avg = _total / count _built;

private _sorted = [_built, [], { [_x] call _count }, "DESCEND"] call BIS_fnc_sortBy;
private _donor = _sorted select 0;
private _recv = _sorted select (count _sorted - 1);
if ((_donor getOrDefault ["transferBusy", false]) || { _recv getOrDefault ["transferBusy", false] }) exitWith {};

private _dN = [_donor] call _count;
private _rN = [_recv] call _count;
if (_dN - _avg < CQ_balanceMargin || { _avg - _rN < CQ_balanceMargin }) exitWith {};
if (time - (_donor get "lastContactT") < CQ_balanceContactQuiet) exitWith {};

// Move about half the gap, whole squads only, donor keeps its defenders
private _want = (((_dN - _avg) min (_avg - _rN)) max 1) min (_dN - CQ_minDefenders);
private _cands = (_donor get "infantry") select {
    (_x getVariable ["CQ_role", ""]) in ["patrol", "reinf"]
    && { ({ alive _x } count units _x) > 0 }
    && { ([_x] call CQ_fnc_infAmmo) >= CQ_minAmmoToAdvance }
};
_cands = [_cands, [], { { alive _x } count units _x }, "ASCEND"] call BIS_fnc_sortBy;
private _sel = [];
private _n = 0;
{
    private _s = { alive _x } count units _x;
    if (_n + _s > _want + 3) then { continue };
    _sel pushBack _x;
    _n = _n + _s;
} forEach _cands;
if (_sel isEqualTo []) exitWith {};

["HQ balance: average %1 per HQ, HQ #%2 has %3, HQ #%4 has %5 -> %6 soldiers move",
    [round _avg, _donor get "id", _dN, _recv get "id", _rN, _n]] call CQ_fnc_log;
[_sel, _donor, _recv, "balance"] spawn CQ_fnc_moveGroups;
