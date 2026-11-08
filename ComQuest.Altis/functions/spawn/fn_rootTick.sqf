/*
    CQ_fnc_rootTick  (server, director task)
    Launches a root insertion every CQ_rootInterval s, CQ_maxRoots in total, landing on the
    east coast 1.5-4 km inland near the carrier (debug option: 1st one at the runway end). To launch the next one now, run on the
    server from the debug console:  CQ_nextRootTime = 0;
*/
if (CQ_rootsLaunched >= CQ_maxRoots) exitWith {};
if (serverTime < CQ_nextRootTime) exitWith {};

private _site = if (CQ_rootsLaunched == 0 && CQ_debugFirstAtRunway) then {
    call CQ_fnc_debugRunwaySite
} else {
    // A coast point near the carrier's, then inland (westward cone) from it
    private _y = (CQ_coastPoint select 1) - CQ_rootCoastSpread + random (2 * CQ_rootCoastSpread);
    private _coast = [];
    for "_x" from (worldSize - 200) to (worldSize * 0.5) step -100 do {
        if (getTerrainHeightASL [_x, _y] > 0) exitWith { _coast = [_x, _y, 0] };
    };
    if (_coast isEqualTo []) then { _coast = CQ_coastPoint };
    [_coast, CQ_rootInland select 0, CQ_rootInland select 1, true, 40, _coast getDir CQ_basePos, 60] call CQ_fnc_findSite
};

if (_site isEqualTo []) exitWith {
    ["Root insertion: no land found this tick, retrying"] call CQ_fnc_log;
};
private _level = CQ_lastSiteLevel;

CQ_rootsLaunched = CQ_rootsLaunched + 1;
CQ_nextRootTime = serverTime + CQ_rootInterval;
["Root insertion %1/%2 launched", [CQ_rootsLaunched, CQ_maxRoots]] call CQ_fnc_log;

[_site, _level] spawn CQ_fnc_insertion;
