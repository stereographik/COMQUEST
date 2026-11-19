/*
    CQ_fnc_hqSplit  (server, from CQ_fnc_hqTick when a wave has arrived)
    [_hq, _waveInfantry, _waveVehicles] call CQ_fnc_hqSplit;
    The wave joins the HQ, then the HQ splits (GARRISON TARGET): once it has CQ_garrisonTarget +
    CQ_splitSize infantry, exactly CQ_splitSize of them (fresh reinforcements first) leave with the truck and the random vehicle, plus a new officer,
    to found a child HQ ~2 km away (CQ_fnc_colonise). The armour and the rest stay.
    No split when caps or numbers forbid it: the wave simply reinforces the garrison.
    Pacing: no split before CQ_splitAge s after the HQ was built, then once per CQ_splitGap s;
    no base assault before CQ_assaultAge s.
    Within CQ_assaultRange of the player base the colonists assault the base instead.
*/
params ["_hq", ["_waveInf", []], ["_waveVehs", []], ["_think", false]];
// _think (La Lance, CQ_fnc_hqTick every CQ_lanceThinkEvery s): no wave, the HQ only checks whether it
// may split / bond / assault with the men it has; nothing announced when it may not

private _id = _hq get "id";
private _c = _hq get "pos";

// Wave joins the HQ
(_hq get "infantry") append _waveInf;
(_hq get "vehicles") append _waveVehs;
{ _x enableDynamicSimulation CQ_dynSimGarrison } forEach _waveInf;

if (!_think) then {
_hq set ["state", "Holding"];
_hq set ["stateT", time];
_hq set ["nextWaveT", time + CQ_waveGap * ([1, 1 + (missionNamespace getVariable ["CQ_lanceTide", 0]) * CQ_lanceTideInterval] select CQ_lanceOn)];   // Maree: rarer waves
};

private _inf = (_hq get "infantry") select { ({ alive _x } count units _x) > 0 };
private _total = [_inf] call CQ_fnc_aliveCount;

// --- can it expand?
// Close to the player base: no new HQ, the split becomes an assault on the base
private _assault = (_c distance2D CQ_basePos) < CQ_assaultRange;

private _reason = "";
if (!_think && { ([_waveInf] call CQ_fnc_aliveCount) == 0 }) then { _reason = "the reinforcements never arrived" };
if (missionNamespace getVariable ["CQ_lanceAllIn", false]) then { _reason = "all-in: every group is already on the base" };
private _active = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
if (_reason == "" && { !_assault } && { count _active >= CQ_maxHqs }) then { _reason = format ["HQ limit %1 reached", CQ_maxHqs] };
if (_reason == "" && { !_assault } && { !CQ_lanceOn } && { (missionNamespace getVariable ["CQ_carrierLeft", 1]) <= 0 }) then { _reason = "the carrier has no supplies left for a new HQ" };
if (_reason == "" && { !alive (_hq get "commander") || { _hq get "cmdCaptured" } }) then { _reason = "no commander to order it" };
// pacing: a young HQ holds before it splits or assaults, and splits at most once per CQ_splitGap
private _age = time - (_hq getOrDefault ["builtT", time]);
if (_hq getOrDefault ["dbgSplit", false]) then { _hq set ["dbgSplit", false]; _age = 1e6; _hq set ["lastSplitT", -1e6]; _hq set ["dbgSkipQuiet", true] };   // debug "next wave": pacing skipped
private _assaultAge = if (CQ_lanceOn) then { (CQ_assaultAge - (missionNamespace getVariable ["CQ_lanceTide", 0]) * CQ_lanceTideAssault) max 300 } else { CQ_assaultAge };   // Maree: earlier assault
if (_reason == "" && { _assault } && { _age < _assaultAge }) then { _reason = format ["too new to assault the base (%1 / %2 min)", floor (_age / 60), round (_assaultAge / 60)] };
// a split needs CQ_splitAge s of calm: since the build ended AND since a player was last within CQ_secureRadius m (CQ_fnc_hqTick)
private _quiet = time - ((_hq getOrDefault ["builtT", time]) max (_hq getOrDefault ["lastNearT", -1e6]));
if (_hq getOrDefault ["dbgSkipQuiet", false]) then { _quiet = 1e6 };
if (_reason == "" && { !_assault } && { _quiet < CQ_splitAge }) then { _reason = format ["not calm enough (%1 / %2 s with no player within 1 km)", floor _quiet, CQ_splitAge] };
if (_reason == "" && { !_assault } && { time - (_hq getOrDefault ["lastSplitT", -1e6]) < CQ_splitGap }) then { _reason = format ["split %1 min ago (once per %2 min)", floor ((time - (_hq get "lastSplitT")) / 60), round (CQ_splitGap / 60)] };

_hq set ["dbgSkipQuiet", false];

// ---- LA LANCE: who may expand, and where (Port -> Relais -> Tete de pont, on the line beachhead -> base)
private _lNext = ""; private _lTarget = []; private _lParent = _id; private _lBond = false; private _lFree = true;
if (CQ_lanceOn && { !_assault }) then {
    private _lRole = _hq getOrDefault ["lRole", "port"];
    // Lance double: a Tete kept from moving by players (not calm) twice in a row takes a side corridor
    if (!_think && { _lRole == "head" } && { (_reason find "not calm") == 0 }) then {
        private _nb = (_hq getOrDefault ["bondBlocked", 0]) + 1;
        _hq set ["bondBlocked", _nb];
        if (_nb >= CQ_lanceBlockedMax && { (missionNamespace getVariable ["CQ_lanceSide", 0]) == 0 }) then {
            private _A = missionNamespace getVariable ["CQ_lanceA", _c];
            private _ax = _A getDir CQ_basePos;
            // the side with land and the fewest players
            private _score = { params ["_s"]; private _q = _c getPos [CQ_lanceDetour, _ax + 90 * _s]; ([0, -1e6] select (surfaceIsWater _q)) - 1000 * ({ _x distance2D _q < 2500 } count allPlayers) };
            CQ_lanceSide = [-1, 1] select (([1] call _score) > ([-1] call _score));
            _hq set ["bondBlocked", 0];
            ["CSAT is going around", format ["HQ #%1 is blocked on the main road: CSAT bypasses by the %2", _id,
                ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"] select ((round ((_ax + 90 * CQ_lanceSide) / 45)) mod 8)]] call CQ_fnc_announce;
        };
    };
    if (_reason == "") then {
        private _A = missionNamespace getVariable ["CQ_lanceA", _c];
        private _B = CQ_basePos;
        private _ax = _A getDir _B;
        private _act = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
        private _has = { params ["_r"]; (_act findIf { (_x getOrDefault ["lRole", ""]) == _r }) > -1 };
        private _lastFall = { params ["_r"]; private _d = (values CQ_hqs) select { (_x get "state") == "Destroyed" && { (_x getOrDefault ["lRole", ""]) == _r } };
            if (_d isEqualTo []) exitWith { createHashMap }; ([_d, [], { _x getOrDefault ["fallT", 0] }, "DESCEND"] call BIS_fnc_sortBy) select 0 };
        private _side = { params ["_p"]; private _s = missionNamespace getVariable ["CQ_lanceSide", 0]; if (_s == 0) then { _p } else { _p getPos [CQ_lanceDetour, _ax + 90 * _s] } };
        private _keepOut = { params ["_p"]; if (_p distance2D _B < CQ_assaultRange + 300) then { _B getPos [CQ_assaultRange + 300, _B getDir _p] } else { _p } };
        private _rebuild = {
            params ["_r"];
            private _f = [_r] call _lastFall;
            if (count _f == 0) exitWith { true };
            _lFree = false;
            if (time - (_f getOrDefault ["fallT", 0]) < CQ_lanceRebuildDelay) exitWith { _reason = format ["Lance: the %1 is rebuilt in %2 s", _r, round (CQ_lanceRebuildDelay - (time - (_f getOrDefault ["fallT", 0])))]; false };
            if ((missionNamespace getVariable ["CQ_carrierLeft", 0]) < (CQ_lanceCost get "rebuild")) exitWith { _reason = format ["Lance: the carrier cannot pay a rebuild (%1 / %2 pts)", round CQ_carrierLeft, CQ_lanceCost get "rebuild"]; false };
            true
        };
        switch (_lRole) do {
            case "port": {
                if (["relay"] call _has) exitWith { _reason = "Lance: the Relais stands (the Port only rebuilds it)" };
                if !(["relay"] call _rebuild) exitWith {};
                _lNext = "relay";
                _lTarget = _A getPos [(_A distance2D _B) * CQ_lanceRelayFrac, _ax];
            };
            case "relay": {
                if (["head"] call _has) exitWith { _reason = "Lance: the Tete de pont stands (the Relais only rebuilds it)" };
                if !(["head"] call _rebuild) exitWith {};
                _lNext = "head";
                private _f = ["head"] call _lastFall;
                _lTarget = if (count _f > 0) then { [((_c select 0) + ((_f get "pos") select 0)) / 2, ((_c select 1) + ((_f get "pos") select 1)) / 2, 0] }
                    else { [[_A getPos [(_A distance2D _B) * CQ_lanceHeadFrac, _ax]] call _side] call _keepOut };
            };
            case "head": {
                if ((_hq get "stock") < CQ_lanceBondStock * (_hq get "cap")) exitWith { _reason = format ["Lance: too little ammo to move forward (%1 / %2)", round (_hq get "stock"), round (CQ_lanceBondStock * (_hq get "cap"))] };
                // bond: a third of the way to the base, on the current corridor, the new Tete hangs off the Relais
                _lNext = "head"; _lBond = true; _lParent = _hq get "parent";
                private _d = _c distance2D _B;
                private _p = _c getPos [_d * CQ_lanceBondStep, _c getDir _B];
                if ((missionNamespace getVariable ["CQ_lanceSide", 0]) != 0) then {
                    // keep on the side corridor: the point the same distance from the base, off the main line
                    _p = [_B getPos [_p distance2D _B, _B getDir _A]] call _side;
                };
                _lTarget = _p;
                _hq set ["bondBlocked", 0];
            };
            default { _reason = "Lance: this HQ does not expand" };
        };
    };
};

private _site = [];
if (CQ_lanceOn && { _reason == "" } && { !_assault }) then {
    _site = [_lTarget, 0, CQ_lanceSnapR, true, 40] call CQ_fnc_findSite;
    if (_site isEqualTo [] || { CQ_lastSiteLevel == 5 }) then { _site = [_lTarget, 0, 2 * CQ_lanceSnapR, true, 40] call CQ_fnc_findSite };   // wider when nothing good (coast, rocks) near the point
    if (_site isEqualTo []) then { _reason = "Lance: no site near the planned point" };
};
if (!CQ_lanceOn && { _reason == "" } && { !_assault }) then {
    // ~2 km toward the player base, wandering +/- CQ_childSpread degrees; the search relaxes
    // its tolerance until it finds a place (CQ_fnc_findSite)
    private _toBase = _c getDir CQ_basePos;
    _site = [_c, CQ_childDistance select 0, CQ_childDistance select 1, true, 40, _toBase, CQ_childSpread] call CQ_fnc_findSite;
    if (_site isEqualTo []) then {
        _site = [_c, CQ_childDistance select 0, (CQ_childDistance select 1) + 1000, true, 40] call CQ_fnc_findSite;
    };
    if (_site isEqualTo []) then { _reason = "only sea around" };
};

// Wave infantry not leaving -> patrols; armour always patrols the HQ
private _toPatrol = {
    params ["_groups"];
    {
        [_x] call CQ_fnc_clearWaypoints;
        _x setVariable ["CQ_role", "patrol"];
        _x setVariable ["CQ_roamT", -1];   // vehicle groups: roaming route from CQ_fnc_vehRoamTick
        [_x, _c, CQ_patrolRadius select 0] call CQ_fnc_infPatrol;
    } forEach _groups;
};
{
    private _vg = group effectiveCommander _x;
    if (!isNull _vg && { (_x getVariable ["CQ_pool", ""]) == "armour" }) then { [[_vg]] call _toPatrol };
} forEach _waveVehs;

// GARRISON TARGET: it may go (nothing else stops it) -> it wants CQ_splitSize men on top of its
// CQ_garrisonTarget, and goes once it has them (the waves fill the gap, CQ_fnc_hqTick)
private _need = CQ_garrisonTarget + CQ_splitSize;
_hq set ["wantInf", [CQ_garrisonTarget, _need] select (_reason == "")];
if (_reason == "" && { _total < _need }) then { _reason = format ["%1 / %2 infantry (keeps %3, sends %4)", _total, _need, CQ_garrisonTarget, CQ_splitSize] };
if (_reason != "" && { _think }) exitWith { _hq set ["thinkWhy", _reason] };
if (_reason != "") exitWith {
    [_waveInf select { ({ alive _x } count units _x) > 0 }] call _toPatrol;
    { private _vg = group effectiveCommander _x; if (!isNull _vg && { (_x getVariable ["CQ_pool", ""]) != "armour" }) then { [[_vg]] call _toPatrol } } forEach _waveVehs;
    ["Reinforcements joined", format ["HQ #%1 now has %2 infantry. No expansion: %3", _id, _total, _reason]] call CQ_fnc_announce;
};

// --- pick the colonists: fresh reinforcements first, then patrols; defenders stay
private _target = CQ_splitSize;
private _cands = _inf select { (_x getVariable ["CQ_role", ""]) in ["reinf", "patrol"] && { ([_x] call CQ_fnc_infAmmo) >= CQ_minAmmoToAdvance } };
_cands = [_cands, [], { [1, 0] select ((_x getVariable ["CQ_role", ""]) == "reinf") }, "ASCEND"] call BIS_fnc_sortBy;
private _col = [];
private _n = 0;
{
    if (_n >= _target) exitWith {};
    private _k = { alive _x } count units _x;
    if (_total - (_n + _k) < CQ_garrisonTarget - 2) then { continue };   // whole squads: the HQ keeps its garrison (2 men of slack for odd squad sizes)
    _col pushBack _x;
    _n = _n + _k;
} forEach _cands;

if (_col isEqualTo [] && { _think }) exitWith { _hq set ["thinkWhy", "no free squad"] };
if (_col isEqualTo []) exitWith {
    ["Reinforcements joined", format ["HQ #%1 now has %2 infantry. No expansion: no free squad", _id, _total]] call CQ_fnc_announce;
};

// Wave squads that stay behind patrol the HQ (they would otherwise stand where they dismounted)
[(_waveInf - _col) select { ({ alive _x } count units _x) > 0 }] call _toPatrol;

// Vehicles that go: the wave's truck and random vehicle; the wave's armour escorts the
// column when the HQ keeps another armed vehicle; free troop trucks of the HQ carry the
// colonists who have no seat yet
private _colVehs = _waveVehs select { alive _x && { (_x getVariable ["CQ_pool", ""]) in ["truck", "random"] } };
private _armour = _waveVehs select { alive _x && { canMove _x } && { (_x getVariable ["CQ_pool", ""]) == "armour" } };
private _keeps = ((_hq get "vehicles") - _waveVehs) select { alive _x && { canMove _x } && { !(_x isKindOf "Truck_F") } };
if (_armour isNotEqualTo [] && { _keeps isNotEqualTo [] }) then { _colVehs append _armour };
private _seats = 0;
{ _seats = _seats + (_x emptyPositions "cargo") } forEach _colVehs;
{
    if (_seats >= _n) exitWith {};
    if (alive _x && { _x isKindOf "Truck_F" } && { canMove _x } && { alive driver _x } && { !(_x getVariable ["CQ_busy", false]) }
        && { getAmmoCargo _x <= 0 } && { getFuelCargo _x <= 0 } && { getRepairCargo _x <= 0 }
        && { (_x emptyPositions "cargo") >= 4 } && { _x distance2D _c < 1500 }) then {
        _colVehs pushBack _x;
        _seats = _seats + (_x emptyPositions "cargo");
    };
} forEach ((_hq get "vehicles") - _waveVehs);

if (_assault) exitWith {
    {
        // orders from CQ_fnc_assaultTick: approach, sweep, then breach the command post
        [_x] call CQ_fnc_clearWaypoints;
        _x setVariable ["CQ_role", "assault"];
        _x setVariable ["CQ_aHq", _id];
        _x setVariable ["CQ_aStage", ""];
    } forEach (_col + (_colVehs apply { group effectiveCommander _x }) select { !isNull _x });
    ["ENEMY ASSAULT ON YOUR BASE", format ["HQ #%1 (%2 m from your base) sends %3 soldiers and %4 vehicles against the airport",
        _id, round (_c distance2D CQ_basePos), _n, count _colVehs]] call CQ_fnc_announce;
    ["assault", [[_id] call CQ_fnc_objName]] call CQ_fnc_say;
};

// La Lance: the carrier pays for the new position (a rebuild costs more); not enough points: no split
if (CQ_lanceOn && { !([["position", "rebuild"] select !_lFree, format ["HQ #%1 founds a new %2", _id, _lNext]] call CQ_fnc_carrierSpend) }) exitWith {
    _hq set ["thinkWhy", "the carrier cannot pay the new position"];
    if (!_think) then { [_col] call _toPatrol };
};
_hq set ["thinkWhy", ""];
if (_think) then { ["HQ #%1: Lance, expands on its own (no wave)", [_id]] call CQ_fnc_log };
_hq set ["infantry", (_hq get "infantry") - _col];
_hq set ["vehicles", (_hq get "vehicles") - _colVehs];

// New officer for the child HQ, out of the parent's command building
private _cmdG = createGroup [east, true];
private _bld = _hq get "building";
private _from = if (isNull _bld) then { _c } else { getPosATL _bld };
_cmdG createUnit ["O_officer_F", _from getPos [6, random 360], [], 0, "NONE"];
[units _cmdG] call CQ_fnc_unitPrep;

_hq set ["lastSplitT", time];
if (CQ_lanceOn) then { CQ_lanceRoleNext = _lNext; CQ_lanceFreeNext = _lFree };
private _child = [_site, [_id, _lParent] select CQ_lanceOn] call CQ_fnc_hqNew;
if (CQ_lanceOn && { _lBond }) then {
    _hq set ["lRole", "headOld"];   // it packs up once the new Tete is built (CQ_fnc_lanceTick)
    ["CSAT moves forward", format ["HQ #%1 sends its spearhead forward: a new position near grid %2, %3 m closer to your base", _id, mapGridPosition _site, round ((_c distance2D CQ_basePos) - (_site distance2D CQ_basePos))]] call CQ_fnc_announce;
};
_child set ["incomingCol", _n];     // colonists on the way count for the balancing (CQ_fnc_hqBalance)
_child set ["siteLevel", CQ_lastSiteLevel];
private _carry = floor (((_hq get "stock") * CQ_childCarryShare) min CQ_childCarryMax);
_hq set ["stock", (_hq get "stock") - _carry];
_child set ["stockInit", _carry max CQ_childStartStock];      // the carrier tops it up (with the build truck drop)
private _carryFuel = floor (((_hq get "fuel") * CQ_childCarryShare) min CQ_childCarryMax);
_hq set ["fuel", (_hq get "fuel") - _carryFuel];
_child set ["fuelInit", _carryFuel max CQ_childStartFuel];
["Enemy HQ splitting", format ["HQ #%1: %2 soldiers leave with %7 ammo to found HQ #%3 near grid %4 (%5 m), %6 stay (it starts with %8 ammo, %9 fuel)",
    _id, _n, _child get "id", mapGridPosition _site, round (_site distance2D _c), _total - _n, _carry, _child get "stockInit", _child get "fuelInit"]] call CQ_fnc_announce;

[_child, _col, _colVehs, _cmdG] spawn CQ_fnc_colonise;

// The parent's build truck (and its squad) leaves to build the child; the carrier sends the
// parent a new one for its own next split (CQ_fnc_buildTruck, counts in CQ_btMaxDrops)
private _bt = _hq getOrDefault ["buildTruck", objNull];
if (alive _bt && { canMove _bt } && { alive driver _bt }) then {
    private _sg = _hq getOrDefault ["btSquad", grpNull];
    _hq set ["buildTruck", objNull];
    _hq set ["btSquad", grpNull];
    ["assign", [_child, _bt, _sg]] call CQ_fnc_buildTruck;
    // the trip to the new site, with the colonists: same safety nets as a build leg (stuck -> new
    // route, then a hop onto free ground; too long -> put near the site). The build (CQ_fnc_hqBuild)
    // takes the truck over as soon as it starts.
    [_child, _site] spawn {
        params ["_child", "_site"];
        private _cid = _child get "id";
        ["board", [_child]] call CQ_fnc_buildTruck;
        private _tr = _child getOrDefault ["buildTruck", objNull];
        if (!alive _tr) exitWith {};
        private _dest = _site getPos [40, _site getDir _tr];
        private _dg = group driver _tr;
        [_dg] call CQ_fnc_clearWaypoints;
        _dg setBehaviour "SAFE"; _dg setSpeedMode "NORMAL";
        _dg move _dest;
        private _t0 = time; private _moveT = time; private _lastP = getPosATL _tr; private _stuckN = 0;
        waitUntil {
            sleep 2;
            _tr = _child getOrDefault ["buildTruck", objNull];
            if (!alive _tr || { !alive driver _tr } || { _child getOrDefault ["buildStarted", false] } || { !((_child get "state") in CQ_activeStates) }) exitWith { true };
            if (_tr distance2D _site < 150) exitWith { ["HQ #%1: build truck arrived with the colonists (%2 s)", [_cid, round (time - _t0)]] call CQ_fnc_log; true };
            if (_tr distance2D _lastP > 5) then { _lastP = getPosATL _tr; _moveT = time };
            if (time - _moveT > CQ_btStuck) then {
                if (_stuckN == 0) then {
                    ["HQ #%1: build truck stuck at grid %2 on its way, new route", [_cid, mapGridPosition _tr]] call CQ_fnc_log;
                } else {
                    private _p = (_tr getPos [25, _tr getDir _dest]) findEmptyPosition [0, 40, typeOf _tr];
                    if (_p isNotEqualTo []) then { _tr setVelocity [0, 0, 0]; _tr setPosATL [_p select 0, _p select 1, 0.3] };
                    ["HQ #%1: build truck still stuck on its way, moved onto free ground at grid %2", [_cid, mapGridPosition _tr]] call CQ_fnc_log;
                };
                (group driver _tr) move _dest;
                _stuckN = _stuckN + 1; _moveT = time; _lastP = getPosATL _tr;
            };
            if (time - _t0 > CQ_btTripMax) exitWith {
                private _p = _dest findEmptyPosition [0, 60, typeOf _tr];
                if (_p isEqualTo []) then { _p = _dest };
                _tr setVelocity [0, 0, 0]; _tr setPosATL [_p select 0, _p select 1, 0.3];
                ["HQ #%1: build truck trip over %2 s, put near the site", [_cid, CQ_btTripMax]] call CQ_fnc_log;
                true
            };
            false
        };
    };
    ["HQ #%1: build truck leaves for HQ #%2", [_id, _child get "id"]] call CQ_fnc_log;
};
["request", [_hq]] spawn CQ_fnc_buildTruck;
