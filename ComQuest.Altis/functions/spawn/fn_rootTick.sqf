/*
    CQ_fnc_rootTick  (server, director task)
    Launches a root insertion every CQ_rootInterval s, CQ_maxRoots in total.
    Debug: the 1st one lands at the runway end. To launch the next one now, run on the
    server from the debug console:  CQ_nextRootTime = 0;
*/
if (CQ_rootsLaunched >= CQ_maxRoots) exitWith {};
if (serverTime < CQ_nextRootTime) exitWith {};

private _site = if (CQ_rootsLaunched == 0 && CQ_debugFirstAtRunway) then {
    call CQ_fnc_debugRunwaySite
} else {
    [[worldSize / 2, worldSize / 2, 0], 500, worldSize * 0.45, true, 60] call CQ_fnc_findSite
};

if (_site isEqualTo []) exitWith {
    ["Root insertion: no valid site this tick, retrying"] call CQ_fnc_log;
};

CQ_rootsLaunched = CQ_rootsLaunched + 1;
CQ_nextRootTime = serverTime + CQ_rootInterval;
["Root insertion %1/%2 launched", [CQ_rootsLaunched, CQ_maxRoots]] call CQ_fnc_log;

[_site] spawn CQ_fnc_insertion;
