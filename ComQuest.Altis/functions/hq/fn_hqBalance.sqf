/*
    CQ_fnc_hqBalance  (server, director task)
    Keeps the infantry spread evenly over the HQ network. Runs every CQ_balanceInterval,
    and right after every reinforcement wave (CQ_balanceForceT, set by CQ_fnc_waveSend).
      Donors:    fully built HQs with a standing radio tower (orders go by radio), not in
                 contact the last CQ_balanceContactQuiet s; they keep CQ_minDefenders.
      Receivers: every HQ on the ground, also NEW ones still securing / building (they use
                 field radios until their tower is up). HQs under construction count
                 CQ_balanceNewBonus soldiers short, so they get help first.
    Several redeployments per pass (CQ_balanceMaxMoves), one per HQ at a time, fresh
    reinforcements leave first. Transport per squad: CQ_fnc_moveGroups.
*/
private _forced = CQ_balanceForceT > 0 && { time > CQ_balanceForceT };
if (!_forced && { time < CQ_balanceNext }) exitWith {};
CQ_balanceNext = time + CQ_balanceInterval;
CQ_balanceForceT = -1;

private _all = (values CQ_hqs) select {
    (_x get "state") in (CQ_activeStates - ["Inbound"])
    && { alive (_x get "radio") || { !(_x get "buildDone") } }
};
if (count _all < 2) exitWith {};

// Soldiers per HQ, squads already on their way included; HQs being set up "need" more
private _count = {
    params ["_h"];
    ([(_h get "infantry")] call CQ_fnc_aliveCount) + (_h getOrDefault ["incoming", 0])
};
private _need = {
    params ["_h"];
    ([_h] call _count) - ([CQ_balanceNewBonus, 0] select (_h get "buildDone"))
};
private _total = 0;
{ _total = _total + ([_x] call _count) } forEach _all;
private _avg = _total / count _all;

private _moves = 0;
private _used = [];
for "_k" from 1 to ([1, CQ_balanceMaxMoves] select _forced) do {
    private _free = _all select { !(_x getOrDefault ["transferBusy", false]) && { !((_x get "id") in _used) } };
    private _donors = _free select { (_x get "buildDone") && { time - (_x get "lastContactT") > CQ_balanceContactQuiet } };
    if (_donors isEqualTo [] || { count _free < 2 }) exitWith {};
    private _donor = ([_donors, [], { [_x] call _count }, "DESCEND"] call BIS_fnc_sortBy) select 0;
    private _recvs = _free - [_donor];
    private _recv = ([_recvs, [], { [_x] call _need }, "ASCEND"] call BIS_fnc_sortBy) select 0;

    private _dN = [_donor] call _count;
    private _rN = [_recv] call _need;
    if (_dN - _avg < CQ_balanceMargin || { _avg - _rN < CQ_balanceMargin }) exitWith {};

    // About the gap, whole squads, fresh reinforcements first, donor keeps its defenders
    private _want = (((_dN - _avg) min (_avg - _rN)) max 1) min (_dN - CQ_minDefenders);
    private _cands = (_donor get "infantry") select {
        (_x getVariable ["CQ_role", ""]) in ["patrol", "reinf"]
        && { ({ alive _x } count units _x) > 0 }
        && { ([_x] call CQ_fnc_infAmmo) >= CQ_minAmmoToAdvance }
    };
    _cands = [_cands, [], { [1, 0] select ((_x getVariable ["CQ_role", ""]) == "reinf") }, "ASCEND"] call BIS_fnc_sortBy;
    private _sel = [];
    private _n = 0;
    {
        private _s = { alive _x } count units _x;
        if (_n + _s > _want + 3) then { continue };
        _sel pushBack _x;
        _n = _n + _s;
    } forEach _cands;
    _used pushBack (_donor get "id");
    if (_sel isEqualTo []) then { continue };
    _used pushBack (_recv get "id");

    ["HQ balance%7: average %1 per HQ, HQ #%2 has %3, HQ #%4 has %5%8 -> %6 soldiers move",
        [round _avg, _donor get "id", _dN, _recv get "id", [_recv] call _count, _n,
         ["", " (after reinforcements)"] select _forced, ["", " (still setting up)"] select !(_recv get "buildDone")]] call CQ_fnc_log;
    [_sel, _donor, _recv, "balance"] spawn CQ_fnc_moveGroups;
    _moves = _moves + 1;
};
