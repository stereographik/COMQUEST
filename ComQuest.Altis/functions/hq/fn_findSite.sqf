/*
    CQ_fnc_findSite  (server)
    [_center, _rMin, _rMax, _strict, _tries] call CQ_fnc_findSite  ->  position or []

    Samples random points between _rMin and _rMax around _center and returns the first one
    that is on land, flat (isFlatEmpty over CQ_siteRadius) and clear over CQ_siteRadius
    (CQ_fnc_isClear: no rocks, trees, bushes, houses, walls or placed objects). With _strict it also enforces: far from the player base, no player close,
    away from other HQs, and a road within 300 m (needed for convoys).
*/
params ["_center", ["_rMin", 0], ["_rMax", 500], ["_strict", true], ["_tries", 40]];

private _result = [];

for "_i" from 1 to _tries do {
    private _p = _center getPos [_rMin + random (_rMax - _rMin), random 360];

    if (surfaceIsWater _p) then { continue };
    if ((_p isFlatEmpty [15, -1, CQ_siteMaxGradient, CQ_siteRadius, 0, false, objNull]) isEqualTo []) then { continue };
    if !([_p, CQ_siteRadius] call CQ_fnc_isClear) then { continue };   // rocks, trees, houses, placed objects

    if (_strict) then {
        if (_p distance2D CQ_basePos < CQ_baseNoSpawnRadius) then { continue };
        if ((allPlayers findIf { _x distance2D _p < CQ_siteNoPlayerRadius }) > -1) then { continue };
        if (((values CQ_hqs) findIf {
            (_x get "state") in ["Inbound", "Establishing", "Holding"] && { (_x get "pos") distance2D _p < CQ_siteMinHqSpacing }
        }) > -1) then { continue };
        if ((_p nearRoads 300) isEqualTo []) then { continue };
    };

    _result = _p;
    break;
};

_result
