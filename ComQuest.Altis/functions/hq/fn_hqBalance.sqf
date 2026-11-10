/*
    CQ_fnc_hqBalance  (server, director task)
    Every CQ_balanceInterval (and 10 s after each reinforcement wave) the infantry is
    spread over every declared HQ, new ones included (a site chosen and colonists on the
    way already counts):
      1 decide who moves: target = average per HQ; HQs above it (+CQ_balanceMargin) give
        whole squads to HQs below it, neediest first; HQs still being set up count
        CQ_balanceNewBonus soldiers short. Squads already travelling count for their target.
        Donors: built HQs whose radio tower stands, not in contact, keep CQ_minDefenders.
      2 movers call for transport (CQ_fnc_moveGroups): truck or Taru within
        CQ_transportPickRange, else on foot; one squad of each move always walks
      3 those who stay are redispatched around their own HQ (fresh patrol loops)
*/
private _forced = CQ_balanceForceT > 0 && { time > CQ_balanceForceT };
if (!_forced && { time < CQ_balanceNext }) exitWith {};
CQ_balanceNext = time + CQ_balanceInterval;
CQ_balanceForceT = -1;

private _all = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
if (count _all < 2) exitWith {};

private _count = {
    params ["_h"];
    ([(_h get "infantry")] call CQ_fnc_aliveCount) + (_h getOrDefault ["incoming", 0]) + (_h getOrDefault ["incomingCol", 0])
};
private _need = {
    params ["_h"];
    ([_h] call _count) - ([CQ_balanceNewBonus, 0] select (_h get "buildDone"))
};
private _total = 0;
{ _total = _total + ([_x] call _count) } forEach _all;
private _avg = _total / count _all;

// --- 1 who moves
private _hqLoadMap = createHashMap;      // live counts, updated as squads are assigned
{ _hqLoadMap set [_x get "id", [_x] call _need] } forEach _all;
private _donors = _all select {
    (_x get "buildDone") && { alive (_x get "radio") } && { time - (_x get "lastContactT") > CQ_balanceContactQuiet }
};
private _plan = [];                // [donor, receiver, groups]
{
    private _d = _x;
    private _did = _d get "id";
    private _real = [_d] call _count;
    private _cands = (_d get "infantry") select {
        (_x getVariable ["CQ_role", ""]) in ["patrol", "reinf"]
        && { ({ alive _x } count units _x) > 0 }
        && { ([_x] call CQ_fnc_infAmmo) >= CQ_minAmmoToAdvance }
    };
    _cands = [_cands, [], { [1, 0] select ((_x getVariable ["CQ_role", ""]) == "reinf") }, "ASCEND"] call BIS_fnc_sortBy;
    {
        private _g = _x;
        private _s = { alive _x } count units _g;
        if ((_hqLoadMap get _did) - _s < _avg - CQ_balanceMargin / 2 || { _real - _s < CQ_minDefenders }) then { continue };
        if ((_hqLoadMap get _did) - _avg < CQ_balanceMargin) exitWith {};
        private _recvs = _all select { (_x get "id") != _did && { (_hqLoadMap get (_x get "id")) < _avg - CQ_balanceMargin } };
        if (_recvs isEqualTo []) exitWith {};
        private _r = ([_recvs, [], { _hqLoadMap get (_x get "id") }, "ASCEND"] call BIS_fnc_sortBy) select 0;
        private _pi = _plan findIf { (_x select 0) isEqualTo _d && { (_x select 1) isEqualTo _r } };
        if (_pi > -1) then { ((_plan select _pi) select 2) pushBack _g } else { _plan pushBack [_d, _r, [_g]] };
        _hqLoadMap set [_did, (_hqLoadMap get _did) - _s];
        _hqLoadMap set [_r get "id", (_hqLoadMap get (_r get "id")) + _s];
        _real = _real - _s;
    } forEach _cands;
} forEach ([_donors, [], { [_x] call _count }, "DESCEND"] call BIS_fnc_sortBy);

if (_plan isEqualTo []) exitWith {};

// --- 2 movers go
{
    _x params ["_d", "_r", "_gs"];
    ["HQ balance%1: average %2 per HQ, HQ #%3 -> HQ #%4%5: %6", [["", " (after reinforcements)"] select _forced, round _avg,
        _d get "id", _r get "id", ["", " (still setting up)"] select !(_r get "buildDone"), (_gs apply { groupId _x }) joinString ", "]] call CQ_fnc_log;
    [_gs, _d, _r, "balance"] spawn CQ_fnc_moveGroups;
} forEach _plan;

// --- 3 those who stay: fresh patrol loops around their own HQ
{
    private _d = _x;
    if ((_plan findIf { (_x select 0) isEqualTo _d }) == -1) then { continue };
    private _movers = [];
    { if ((_x select 0) isEqualTo _d) then { _movers append (_x select 2) } } forEach _plan;
    private _stay = ((_d get "infantry") - _movers) select { (_x getVariable ["CQ_role", ""]) in ["patrol", "reinf"] && { ({ alive _x } count units _x) > 0 } };
    (CQ_nervPatrolR select (_d getOrDefault ["nerv", 1])) params ["_r0", "_r1"];   // radius of the HQ's nervousness
    {
        _x setVariable ["CQ_role", "patrol"];
        [_x, _d get "pos", _r0 + (_r1 - _r0) * (_forEachIndex / ((count _stay - 1) max 1))] call CQ_fnc_infPatrol;
    } forEach _stay;
    if (_stay isNotEqualTo []) then { ["HQ balance: HQ #%1 redispatched %2 squads around the HQ", [_d get "id", count _stay]] call CQ_fnc_log };
} forEach _donors;
