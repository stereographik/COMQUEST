/*
    CQ_fnc_rootTick  (server, director task)
    Launches a root insertion every CQ_rootInterval s (at once when the island is empty), CQ_maxRoots
    in total, free; then re-insertions paid from the carrier's supplies when the island is empty. The first one at the
    carrier site's paired first HQ position, the next ones 1.5-4 km inland from the coast facing the carrier (debug option: 1st one at the runway end). To launch the next one now, run on the
    server from the debug console:  CQ_nextRootTime = 0;
    HELP WAVE: while an HQ is unfinished, a wave first lands next to it and guards it (state
    Helping in CQ_fnc_hqTick), then founds its own HQ near it.
*/
// Two budgets: CQ_maxRoots free root insertions (the beachhead, then one every CQ_rootInterval s),
// and the carrier's supplies (CQ_carrierLeft) that only child HQs use. The island emptied by the
// players brings the next root at once; with no root left, a RE-INSERTION is paid from the
// supplies (CQ_reinsertDelay s after the island is empty). No root and no supplies: nothing more.
private _active = ((values CQ_hqs) findIf { (_x get "state") in CQ_activeStates }) > -1;
// La Lance: the Port is what counts (a fallen Port is re-landed, paid, even with the Relais / Tete still up)
if (CQ_lanceOn) then { _active = ((values CQ_hqs) findIf { (_x get "state") in CQ_activeStates && { (_x getOrDefault ["lRole", ""]) == "port" } }) > -1 };
if (_active) then { CQ_islandEmptyT = -1 } else { if ((missionNamespace getVariable ["CQ_islandEmptyT", -1]) < 0) then { CQ_islandEmptyT = serverTime } };
private _paid = false;
if (CQ_rootsLaunched >= CQ_maxRoots) then {
    _paid = true;
    if (_active || { (missionNamespace getVariable ["CQ_carrierLeft", 0]) <= ([0, (CQ_lanceCost get "rebuild") - 1] select CQ_lanceOn) } || { missionNamespace getVariable ["CQ_lanceAllIn", false] }) exitWith { _paid = false };
    if (serverTime - CQ_islandEmptyT < CQ_reinsertDelay) exitWith { _paid = false };
};
if (CQ_rootsLaunched >= CQ_maxRoots && { !_paid }) exitWith {};
if (!_paid && { serverTime < CQ_nextRootTime } && { _active || { CQ_rootsLaunched == 0 } || { serverTime - CQ_islandEmptyT < CQ_reinsertDelay } }) exitWith {};
// root insertions have their own allowance above the cap (HQ reinforcements alone can fill it)
if ((call CQ_fnc_enemyCount) > CQ_maxAI + CQ_rootCapBonus - 30) exitWith {
    CQ_nextRootTime = serverTime + 60;
    ["Root insertion postponed: AI cap (%1/%2)", [call CQ_fnc_enemyCount, CQ_maxAI + CQ_rootCapBonus]] call CQ_fnc_log;
};

if !([CQ_waveSize, "root insertion", CQ_rootCapBonus] call CQ_fnc_aiRoom) exitWith { CQ_nextRootTime = serverTime + 60 };

// HELP WAVE: an HQ still unfinished (active, build not done) gets this wave first: it lands next
// to the least built one (tie: nearest the carrier), guards it until its build is done
// (CQ_helpMaxTime cap), then founds its own HQ CQ_helpSiteDist m from it, away from our base
private _helpId = -1;
private _helpSite = [];
if (CQ_rootsLaunched > 0 && { CQ_helpWaves }) then {
    private _cands = (values CQ_hqs) select { (_x get "state") in CQ_activeStates && { !(_x get "buildDone") } && { (_x getOrDefault ["helpId", -1]) < 0 } && { (_x get "state") != "Inbound" } };
    if (_cands isNotEqualTo []) then {
        private _cp = missionNamespace getVariable ["CQ_carrierPos", CQ_basePos];
        _cands = [_cands, [], { (_x getOrDefault ["buildStage", 0]) * 100000 + ((_x get "pos") distance2D _cp) }] call BIS_fnc_sortBy;
        private _h = _cands select 0;
        private _hp = _h get "pos";
        _helpSite = [_hp, CQ_helpSiteDist select 0, CQ_helpSiteDist select 1, true, 40, CQ_basePos getDir _hp, 70] call CQ_fnc_findSite;
        if (_helpSite isNotEqualTo []) then { _helpId = _h get "id" };
    };
};
private _site = if (_helpId > -1) then { _helpSite } else { if (CQ_rootsLaunched == 0 && CQ_debugFirstAtRunway) then {
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
        // the corridor outpost has fallen (CQ_corridorLost): players hold that corridor, so the
        // wave picks, among a few coast points, the one farthest from it (at least CQ_corridorAvoid m)
        private _lost = (missionNamespace getVariable ["CQ_corridorLost", -1]) > -1 && { !isNil "CQ_outpostState" };
        private _opPos = if (_lost) then { CQ_outpostState get "pos" } else { [0, 0, 0] };
        private _coast = [];
        private _best = -1;
        for "_try" from 1 to ([1, 8] select _lost) do {
            private _start = CQ_carrierPos getPos [random (2 * CQ_rootCoastSpread) - CQ_rootCoastSpread, _dir + 90];
            private _c = [];
            for "_d" from 0 to 12000 step 100 do {
                private _p = _start getPos [_d, _dir];
                if (getTerrainHeightASL _p > 0) exitWith { _c = [_p select 0, _p select 1, 0] };
            };
            if (_c isEqualTo []) then { continue };
            private _sc = if (_lost) then { _c distance2D _opPos } else { 1 };
            if (_sc > _best) then { _best = _sc; _coast = _c };
            if (_lost && { _sc > CQ_corridorAvoid * 1.5 }) exitWith {};
        };
        if (_coast isEqualTo []) then { _coast = CQ_coastPoint };
        if (_lost) then { ["Root insertion: the corridor is lost, landing at coast %1, %2 m from the fallen outpost", [mapGridPosition _coast, round (_coast distance2D _opPos)]] call CQ_fnc_log };
        [_coast, CQ_rootInland select 0, CQ_rootInland select 1, true, 40, _coast getDir CQ_basePos, 60] call CQ_fnc_findSite
    }
} } };

// La Lance: a re-landed Port goes back to the beachhead
if (CQ_lanceOn && { CQ_rootsLaunched > 0 } && { !isNil "CQ_lanceA" }) then {
    _site = [CQ_lanceA, 0, 1200, true, 40] call CQ_fnc_findSite;
    ["Lance: the Port is re-landed at the beachhead (grid %1)", [if (_site isEqualTo []) then { "none" } else { mapGridPosition _site }]] call CQ_fnc_log;
};
if (!isNil "CQ_rootRetrySite") then {
    _site = CQ_rootRetrySite; CQ_rootRetrySite = nil;
    ["Root insertion: second attempt at the failed landing site %1", [mapGridPosition _site]] call CQ_fnc_log;
};
if (_site isEqualTo []) exitWith {
    ["Root insertion: no land found this tick, retrying"] call CQ_fnc_log;
};
private _level = CQ_lastSiteLevel;

if (_paid) then {
    CQ_rootPaidNext = true;          // CQ_fnc_hqNew: this root uses one of the carrier's supplies
    CQ_islandEmptyT = -1;
    ["Root RE-INSERTION launched: the island was empty, paid from the carrier's supplies (%1 left before it)", [missionNamespace getVariable ["CQ_carrierLeft", 0]]] call CQ_fnc_log;
} else {
    CQ_rootsLaunched = CQ_rootsLaunched + 1;
    CQ_nextRootTime = serverTime + CQ_rootInterval;
    ["Root insertion %1/%2 launched", [CQ_rootsLaunched, CQ_maxRoots]] call CQ_fnc_log;
};

if (_helpId > -1) then { ["Root insertion %1: HELP wave for HQ #%2 (build %3/6), then its own HQ at %4", [CQ_rootsLaunched, _helpId, (CQ_hqs get _helpId) getOrDefault ["buildStage", 0], mapGridPosition _site]] call CQ_fnc_log };
[_site, _level, _helpId] spawn CQ_fnc_insertion;
if (CQ_rootsLaunched == 1) then { "CQ_bossSupport" remoteExec ["playSound", 0] };   // the mission begins: the boss's radio message, for everyone
if (CQ_rootsLaunched == 1 && { CQ_outpost }) then { [_site] spawn CQ_fnc_outpostBuild };   // the first HQ's corridor outpost
