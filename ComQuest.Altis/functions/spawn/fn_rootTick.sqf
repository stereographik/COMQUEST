/*
    CQ_fnc_rootTick  (server, director task)
    Launches a root insertion every CQ_rootInterval s, CQ_maxRoots in total, landing on the
    east coast 1.5-4 km inland near the carrier (debug option: 1st one at the runway end). To launch the next one now, run on the
    server from the debug console:  CQ_nextRootTime = 0;
*/
if (CQ_rootsLaunched >= CQ_maxRoots) exitWith {};
if ((missionNamespace getVariable ["CQ_carrierLeft", 1]) <= 0) exitWith {};          // carrier empty
if (serverTime < CQ_nextRootTime) exitWith {};
if ((call CQ_fnc_enemyInfantry) > CQ_maxInfantry - 30) exitWith {
    CQ_nextRootTime = serverTime + 60;
    ["Root insertion postponed: infantry cap (%1/%2)", [call CQ_fnc_enemyInfantry, CQ_maxInfantry]] call CQ_fnc_log;
};

private _site = if (CQ_rootsLaunched == 0 && CQ_debugFirstAtRunway) then {
    call CQ_fnc_debugRunwaySite
} else { if (CQ_rootsLaunched == 0 && { missionNamespace getVariable ["CQ_testOverride", false] }) then {
    // TEST OVERRIDE: first HQ as far west as allowed, just outside the base no-spawn radius,
    // on the line from the base to the carrier
    private _p = CQ_basePos getPos [CQ_baseNoSpawnRadius + 700, CQ_basePos getDir CQ_carrierPos];
    private _s = [_p, 0, 900, true, 40] call CQ_fnc_findSite;
    ["TEST OVERRIDE: first HQ site %1 (%2 m from the base)", [if (_s isEqualTo []) then { "none" } else { mapGridPosition _s }, if (_s isEqualTo []) then { -1 } else { round (_s distance2D CQ_basePos) }]] call CQ_fnc_log;
    _s
} else {
    // The very first HQ is a beachhead: straight west of the carrier, close to the shore
    private _first = CQ_rootsLaunched == 0;
    private _inland = [CQ_rootInland, CQ_firstRootInland] select _first;
    // A coast point near the carrier's, then inland (westward cone) from it
    private _y = if (_first) then { CQ_coastPoint select 1 } else { (CQ_coastPoint select 1) - CQ_rootCoastSpread + random (2 * CQ_rootCoastSpread) };
    private _coast = [];
    for "_x" from (worldSize - 200) to (worldSize * 0.5) step -100 do {
        if (getTerrainHeightASL [_x, _y] > 0) exitWith { _coast = [_x, _y, 0] };
    };
    if (_coast isEqualTo []) then { _coast = CQ_coastPoint };
    private _s = [_coast, _inland select 0, _inland select 1, true, 40, _coast getDir CQ_basePos, [60, 75] select _first] call CQ_fnc_findSite;
    if (_first && { _s isNotEqualTo [] }) then { ["Beachhead site %1 m from the shore (grid %2)", [round (_s distance2D _coast), mapGridPosition _s]] call CQ_fnc_log };
    _s
} };

if (_site isEqualTo []) exitWith {
    ["Root insertion: no land found this tick, retrying"] call CQ_fnc_log;
};
private _level = CQ_lastSiteLevel;

CQ_rootsLaunched = CQ_rootsLaunched + 1;
CQ_nextRootTime = serverTime + CQ_rootInterval;
["Root insertion %1/%2 launched", [CQ_rootsLaunched, CQ_maxRoots]] call CQ_fnc_log;

[_site, _level] spawn CQ_fnc_insertion;
