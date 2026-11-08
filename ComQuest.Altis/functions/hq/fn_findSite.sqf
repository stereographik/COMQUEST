/*
    CQ_fnc_findSite  (server)
    [_center, _rMin, _rMax, _strict, _tries] call CQ_fnc_findSite  ->  position ([] only if no land at all)

    Always finds a site: starts with the full requirements, then relaxes them one level at a
    time until a sample fits. The level used is left in CQ_lastSiteLevel (0 = perfect).

      level  clear radius  max gradient  terrain blockers           strict rules (if _strict)
        0       40 m           0.15      all but bushes             base / players / HQ spacing / road 300 m
        1       40 m           0.20      all but bushes             same, road 600 m
        2       34 m           0.25      all but bushes             no road, HQ spacing x0.75
        3       30 m           0.30      rocks, buildings, walls    players 500 m
        4       26 m           0.40      rocks, buildings           base x0.8, HQ spacing x0.5
        5       best land sample seen (fewest blockers, flattest); trees and bushes get cleared
    Rocks and buildings are never accepted inside the clear radius before level 5.
*/
params ["_center", ["_rMin", 0], ["_rMax", 500], ["_strict", true], ["_tries", 40]];

private _hard = ["ROCK", "ROCKS", "HOUSE", "BUILDING", "CHURCH", "CHAPEL", "FUELSTATION", "HOSPITAL",
    "LIGHTHOUSE", "POWER LINES", "TRANSMITTER", "WATERTOWER", "RUIN", "BUNKER", "FORTRESS", "QUAY"];
private _levels = [
    // [radius, gradient, blocker types, road (0 = none), hq spacing factor, player radius, base factor]
    [CQ_siteRadius, CQ_siteMaxGradient, CQ_siteBlockerTypes, 300, 1, CQ_siteNoPlayerRadius, 1],
    [CQ_siteRadius, 0.20, CQ_siteBlockerTypes, 600, 1, CQ_siteNoPlayerRadius, 1],
    [CQ_siteRadius - 6, 0.25, CQ_siteBlockerTypes, 0, 0.75, CQ_siteNoPlayerRadius, 1],
    [CQ_siteRadius - 10, 0.30, _hard + ["WALL", "FENCE"], 0, 0.75, 500, 1],
    [CQ_siteRadius - 14, 0.40, _hard, 0, 0.5, 500, 0.8]
];

private _result = [];
private _bestScore = 1e9;
private _best = [];
CQ_lastSiteLevel = -1;

{
    _x params ["_rad", "_grad", "_types", "_road", "_spacing", "_noPlayer", "_baseF"];
    private _level = _forEachIndex;

    for "_i" from 1 to _tries do {
        private _p = _center getPos [_rMin + random (_rMax - _rMin), random 360];
        if (surfaceIsWater _p) then { continue };

        // Remember the least bad land sample for the last resort
        private _nBlock = count (nearestTerrainObjects [_p, CQ_blockerTypes, CQ_siteRadius, false, true]);
        private _nHard = count (nearestTerrainObjects [_p, _hard, CQ_siteRadius, false, true]);
        private _slope = 1 - ((surfaceNormal _p) select 2);
        private _score = 10 * _nHard + _nBlock + 100 * _slope;
        if (_score < _bestScore) then { _bestScore = _score; _best = _p };

        if ((_p isFlatEmpty [-1, -1, _grad, _rad, 0, false, objNull]) isEqualTo []) then { continue };
        if !([_p, _rad, [], _types] call CQ_fnc_isClear) then { continue };

        if (_strict) then {
            if (_p distance2D CQ_basePos < CQ_baseNoSpawnRadius * _baseF) then { continue };
            if ((allPlayers findIf { _x distance2D _p < _noPlayer }) > -1) then { continue };
            if (((values CQ_hqs) findIf {
                (_x get "state") in CQ_activeStates && { (_x get "pos") distance2D _p < CQ_siteMinHqSpacing * _spacing }
            }) > -1) then { continue };
            if (_road > 0 && { (_p nearRoads _road) isEqualTo [] }) then { continue };
        };

        _result = _p;
        CQ_lastSiteLevel = _level;
        break;
    };
    if (_result isNotEqualTo []) exitWith {};
} forEach _levels;

// Level 5: nothing passed, take the best land sample seen
if (_result isEqualTo [] && { _best isNotEqualTo [] }) then {
    _result = _best;
    CQ_lastSiteLevel = 5;
};

if (CQ_lastSiteLevel > 0) then {
    ["Site search near %1: tolerance level %2 used -> %3", [mapGridPosition _center, CQ_lastSiteLevel, if (_result isEqualTo []) then { "no land" } else { mapGridPosition _result }]] call CQ_fnc_log;
};
_result
