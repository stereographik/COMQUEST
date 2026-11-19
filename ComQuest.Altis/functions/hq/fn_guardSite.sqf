/*
    CQ_fnc_guardSite  (server, from CQ_fnc_hqBuild)
    [_hq, _kind, _centre, _radius] call CQ_fnc_guardSite;
    Registers the guard posts of one site (an objective or the HQ centre): CQ_guardCount get _kind
    posts (scaled with CQ_scale, at least 1), the highest building positions of the site's
    buildings first (tower tops, roofs), then spots on the site's rim facing out.
    The men are only there while a player is near the HQ (CQ_fnc_guardTick).
*/
params ["_hq", "_kind", "_c", ["_rad", 15]];
private _n = round ((CQ_guardCount getOrDefault [_kind, 2]) * ((missionNamespace getVariable ["CQ_scale", 1]) max 0.5)) max 1;
private _c2 = [_c select 0, _c select 1, 0];
private _mine = _hq get "objects";

// building positions, highest of each building first, round-robin over the buildings
private _lists = [];
{
    private _bp = (_x buildingPos -1) select { _x isNotEqualTo [0, 0, 0] };
    if (_bp isNotEqualTo []) then { _lists pushBack ([_bp, [], { _x select 2 }, "DESCEND"] call BIS_fnc_sortBy) };
} forEach ((nearestObjects [_c2, ["House", "Building"], _rad + 2]) select { _x in _mine });
private _posts = [];
private _k = 0;
while { count _posts < _n && { (_lists findIf { _x isNotEqualTo [] }) > -1 } } do {
    private _l = _lists select (_k mod count _lists);
    if (_l isNotEqualTo []) then {
        private _p = _l deleteAt 0;
        _posts pushBack [_p, _c2 getDir _p, false];
    };
    _k = _k + 1;
};
// the rest on the rim, spread around, facing out
private _left = _n - count _posts;
private _a0 = random 360;
for "_i" from 0 to _left - 1 do {
    private _a = _a0 + _i * 360 / (_left max 1);
    private _p = _c2 getPos [((_rad * 0.8) max 6) min 30, _a];
    private _e = _p findEmptyPosition [0, 8, "O_Soldier_F"];
    if (_e isNotEqualTo []) then { _p = _e };
    _posts pushBack [[_p select 0, _p select 1, 0], _a, false];
};
// buildingPos gives AGL (= ATL on land): "high" = more than 1.5 m above the ground (tower top, roof)
{ _x set [2, ((_x select 0) select 2) > 1.5] } forEach _posts;

private _sites = _hq getOrDefault ["guardSites", []];
_sites pushBack createHashMapFromArray [["kind", _kind], ["pos", _c2], ["posts", _posts], ["dead", []], ["group", grpNull], ["free", false]];
_hq set ["guardSites", _sites];
["HQ #%1: %2 guard posts at the %3 (%4 high)", [_hq get "id", count _posts, _kind, { _x select 2 } count _posts]] call CQ_fnc_log;
