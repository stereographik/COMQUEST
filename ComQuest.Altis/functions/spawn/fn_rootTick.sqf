/*
    CQ_fnc_rootTick  (server, director task)
    Launches a root insertion every CQ_rootInterval s, CQ_maxRoots in total: the first one at the
    carrier site's paired first HQ position, the next ones 1.5-4 km inland from the coast facing the carrier (debug option: 1st one at the runway end). To launch the next one now, run on the
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
    // TEST OVERRIDE: first HQ next to the town CQ_testFirstHqTown (looked up by name around
    // CQ_testFirstHqPos, which is also the fallback)
    private _loc = (nearestLocations [CQ_testFirstHqPos, ["NameCityCapital", "NameCity", "NameVillage", "NameLocal"], 4000]) select { text _x == CQ_testFirstHqTown };
    private _p = if (_loc isEqualTo []) then { CQ_testFirstHqPos } else { locationPosition (_loc select 0) };
    _p = [_p select 0, _p select 1, 0];
    private _s = [_p, 0, 700, true, 40] call CQ_fnc_findSite;
    ["TEST OVERRIDE: first HQ site %1 (%2 m from the base)", [if (_s isEqualTo []) then { "none" } else { mapGridPosition _s }, if (_s isEqualTo []) then { -1 } else { round (_s distance2D CQ_basePos) }]] call CQ_fnc_log;
    _s
} else {
    // allaroundisland: the very first HQ goes to the carrier site's paired position (CQ_firstHqPos);
    // later ones land inland from a coast point near the carrier's line to the island
    if (CQ_rootsLaunched == 0) then {
        private _s = [CQ_firstHqPos, CQ_firstRootInland select 0, CQ_firstRootInland select 1, true, 40] call CQ_fnc_findSite;
        if (_s isEqualTo []) then { _s = [CQ_firstHqPos, 0, 1200, true, 40] call CQ_fnc_findSite };
        if (_s isNotEqualTo []) then { ["Beachhead site %1 m from the planned first HQ position (grid %2)", [round (_s distance2D CQ_firstHqPos), mapGridPosition _s]] call CQ_fnc_log };
        _s
    } else {
        private _dir = CQ_carrierPos getDir CQ_coastPoint;
        private _start = CQ_carrierPos getPos [random (2 * CQ_rootCoastSpread) - CQ_rootCoastSpread, _dir + 90];
        private _coast = [];
        for "_d" from 0 to 12000 step 100 do {
            private _p = _start getPos [_d, _dir];
            if (getTerrainHeightASL _p > 0) exitWith { _coast = [_p select 0, _p select 1, 0] };
        };
        if (_coast isEqualTo []) then { _coast = CQ_coastPoint };
        [_coast, CQ_rootInland select 0, CQ_rootInland select 1, true, 40, _coast getDir CQ_basePos, 60] call CQ_fnc_findSite
    }
} };

if (_site isEqualTo []) exitWith {
    ["Root insertion: no land found this tick, retrying"] call CQ_fnc_log;
};
private _level = CQ_lastSiteLevel;

CQ_rootsLaunched = CQ_rootsLaunched + 1;
CQ_nextRootTime = serverTime + CQ_rootInterval;
["Root insertion %1/%2 launched", [CQ_rootsLaunched, CQ_maxRoots]] call CQ_fnc_log;

[_site, _level] spawn CQ_fnc_insertion;
if (CQ_rootsLaunched == 1 && { CQ_outpost }) then { [_site] spawn CQ_fnc_outpostBuild };   // the first HQ's corridor outpost
