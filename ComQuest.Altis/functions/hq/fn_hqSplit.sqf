/*
    CQ_fnc_hqSplit  (server, from CQ_fnc_hqTick when a wave has arrived)
    [_hq, _waveInfantry, _waveVehicles] call CQ_fnc_hqSplit;
    The wave joins the HQ, then the HQ splits: CQ_colonistShare of its infantry (fresh
    reinforcements first) leaves with the truck and the random vehicle, plus a new officer,
    to found a child HQ ~2 km away (CQ_fnc_colonise). The armour and the rest stay.
    No split when caps or numbers forbid it: the wave simply reinforces the garrison.
*/
params ["_hq", ["_waveInf", []], ["_waveVehs", []]];

private _id = _hq get "id";
private _c = _hq get "pos";

// Wave joins the HQ
(_hq get "infantry") append _waveInf;
(_hq get "vehicles") append _waveVehs;
{ _x enableDynamicSimulation true } forEach _waveInf;

_hq set ["state", "Holding"];
_hq set ["stateT", time];
_hq set ["nextWaveT", time + CQ_waveInterval];

private _inf = (_hq get "infantry") select { ({ alive _x } count units _x) > 0 };
private _total = [_inf] call CQ_fnc_aliveCount;

// --- can it expand?
private _reason = "";
if (([_waveInf] call CQ_fnc_aliveCount) == 0) then { _reason = "the reinforcements never arrived" };
private _active = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
if (_reason == "" && { count _active >= CQ_maxHqs }) then { _reason = format ["HQ limit %1 reached", CQ_maxHqs] };
if (_reason == "" && { _total < CQ_minInfantryToExpand }) then { _reason = format ["only %1 infantry", _total] };
if (_reason == "" && { !alive (_hq get "commander") }) then { _reason = "no commander to order it" };

private _site = [];
if (_reason == "") then {
    // Best of a few candidates: far from other HQs, slight pull toward the player base
    private _best = -1e9;
    for "_k" from 1 to 6 do {
        private _p = [_c, CQ_childDistance select 0, CQ_childDistance select 1, true, 25] call CQ_fnc_findSite;
        if (_p isNotEqualTo []) then {
            private _others = (_active apply { (_x get "pos") distance2D _p });
            private _score = (selectMin _others) - 0.2 * (_p distance2D CQ_basePos);
            if (_score > _best) then { _best = _score; _site = _p };
        };
    };
    if (_site isEqualTo []) then { _reason = "no valid site 2 km out" };
};

// Wave infantry not leaving -> patrols; armour always patrols the HQ
private _toPatrol = {
    params ["_groups"];
    {
        [_x] call CQ_fnc_clearWaypoints;
        _x setVariable ["CQ_role", "patrol"];
        [_x, _c, 300] call BIS_fnc_taskPatrol;
    } forEach _groups;
};
{
    private _vg = group effectiveCommander _x;
    if (!isNull _vg && { (_x getVariable ["CQ_pool", ""]) == "armour" }) then { [[_vg]] call _toPatrol };
} forEach _waveVehs;

if (_reason != "") exitWith {
    [_waveInf select { ({ alive _x } count units _x) > 0 }] call _toPatrol;
    { private _vg = group effectiveCommander _x; if (!isNull _vg && { (_x getVariable ["CQ_pool", ""]) != "armour" }) then { [[_vg]] call _toPatrol } } forEach _waveVehs;
    ["Reinforcements joined", format ["HQ #%1 now has %2 infantry. No expansion: %3", _id, _total, _reason]] call CQ_fnc_announce;
};

// --- pick the colonists: fresh reinforcements first, then patrols; defenders stay
private _target = ceil (_total * CQ_colonistShare) min (_total - CQ_minDefenders);
private _cands = _inf select { (_x getVariable ["CQ_role", ""]) in ["reinf", "patrol"] };
_cands = [_cands, [], { [1, 0] select ((_x getVariable ["CQ_role", ""]) == "reinf") }, "ASCEND"] call BIS_fnc_sortBy;
private _col = [];
private _n = 0;
{
    if (_n >= _target) exitWith {};
    _col pushBack _x;
    _n = _n + ({ alive _x } count units _x);
} forEach _cands;

if (_col isEqualTo []) exitWith {
    ["Reinforcements joined", format ["HQ #%1 now has %2 infantry. No expansion: no free squad", _id, _total]] call CQ_fnc_announce;
};

// Vehicles that go: the wave's truck and random vehicle
private _colVehs = _waveVehs select { alive _x && { (_x getVariable ["CQ_pool", ""]) in ["truck", "random"] } };

_hq set ["infantry", (_hq get "infantry") - _col];
_hq set ["vehicles", (_hq get "vehicles") - _colVehs];

// New officer for the child HQ, out of the parent's command building
private _cmdG = createGroup [east, true];
private _bld = _hq get "building";
private _from = if (isNull _bld) then { _c } else { getPosATL _bld };
_cmdG createUnit ["O_officer_F", _from getPos [6, random 360], [], 0, "NONE"];

private _child = [_site, _id] call CQ_fnc_hqNew;
["Enemy HQ splitting", format ["HQ #%1: %2 soldiers leave to found HQ #%3 near grid %4 (%5 m), %6 stay",
    _id, _n, _child get "id", mapGridPosition _site, round (_site distance2D _c), _total - _n]] call CQ_fnc_announce;

[_child, _col, _colVehs, _cmdG] spawn CQ_fnc_colonise;
