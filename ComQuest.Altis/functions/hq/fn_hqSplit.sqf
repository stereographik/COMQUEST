/*
    CQ_fnc_hqSplit  (server, from CQ_fnc_hqTick when a wave has arrived)
    [_hq, _waveInfantry, _waveVehicles] call CQ_fnc_hqSplit;
    The wave joins the HQ, then the HQ splits: CQ_colonistShare of its infantry (fresh
    reinforcements first) leaves with the truck and the random vehicle, plus a new officer,
    to found a child HQ ~2 km away (CQ_fnc_colonise). The armour and the rest stay.
    No split when caps or numbers forbid it: the wave simply reinforces the garrison.
    Within CQ_assaultRange of the player base the colonists assault the base instead.
*/
params ["_hq", ["_waveInf", []], ["_waveVehs", []]];

private _id = _hq get "id";
private _c = _hq get "pos";

// Wave joins the HQ
(_hq get "infantry") append _waveInf;
(_hq get "vehicles") append _waveVehs;
{ _x enableDynamicSimulation CQ_dynSimGarrison } forEach _waveInf;

_hq set ["state", "Holding"];
_hq set ["stateT", time];
_hq set ["nextWaveT", time + CQ_waveInterval];

private _inf = (_hq get "infantry") select { ({ alive _x } count units _x) > 0 };
private _total = [_inf] call CQ_fnc_aliveCount;

// --- can it expand?
// Close to the player base: no new HQ, the split becomes an assault on the base
private _assault = (_c distance2D CQ_basePos) < CQ_assaultRange;

private _reason = "";
if (([_waveInf] call CQ_fnc_aliveCount) == 0) then { _reason = "the reinforcements never arrived" };
private _active = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
if (_reason == "" && { !_assault } && { count _active >= CQ_maxHqs }) then { _reason = format ["HQ limit %1 reached", CQ_maxHqs] };
if (_reason == "" && { _total < CQ_minInfantryToExpand }) then { _reason = format ["only %1 infantry", _total] };
if (_reason == "" && { !alive (_hq get "commander") }) then { _reason = "no commander to order it" };

private _site = [];
if (_reason == "" && { !_assault }) then {
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

if (_reason != "") exitWith {
    [_waveInf select { ({ alive _x } count units _x) > 0 }] call _toPatrol;
    { private _vg = group effectiveCommander _x; if (!isNull _vg && { (_x getVariable ["CQ_pool", ""]) != "armour" }) then { [[_vg]] call _toPatrol } } forEach _waveVehs;
    ["Reinforcements joined", format ["HQ #%1 now has %2 infantry. No expansion: %3", _id, _total, _reason]] call CQ_fnc_announce;
};

// --- pick the colonists: fresh reinforcements first, then patrols; defenders stay
private _target = ceil (_total * CQ_colonistShare) min (_total - CQ_minDefenders);
private _cands = _inf select { (_x getVariable ["CQ_role", ""]) in ["reinf", "patrol"] && { ([_x] call CQ_fnc_infAmmo) >= CQ_minAmmoToAdvance } };
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
        [_x] call CQ_fnc_clearWaypoints;
        _x setVariable ["CQ_role", "assault"];
        _x setBehaviour "AWARE";
        _x setSpeedMode "FULL";
        private _wp = _x addWaypoint [CQ_basePos, 150];
        _wp setWaypointType "SAD";
    } forEach (_col + (_colVehs apply { group effectiveCommander _x }) select { !isNull _x });
    ["ENEMY ASSAULT ON YOUR BASE", format ["HQ #%1 (%2 m from your base) sends %3 soldiers and %4 vehicles against the airport",
        _id, round (_c distance2D CQ_basePos), _n, count _colVehs]] call CQ_fnc_announce;
    ["assault", [[_id] call CQ_fnc_objName]] call CQ_fnc_say;
};

_hq set ["infantry", (_hq get "infantry") - _col];
_hq set ["vehicles", (_hq get "vehicles") - _colVehs];

// New officer for the child HQ, out of the parent's command building
private _cmdG = createGroup [east, true];
private _bld = _hq get "building";
private _from = if (isNull _bld) then { _c } else { getPosATL _bld };
_cmdG createUnit ["O_officer_F", _from getPos [6, random 360], [], 0, "NONE"];
[units _cmdG] call CQ_fnc_unitPrep;

private _child = [_site, _id] call CQ_fnc_hqNew;
_child set ["incomingCol", _n];     // colonists on the way count for the balancing (CQ_fnc_hqBalance)
_child set ["siteLevel", CQ_lastSiteLevel];
private _carry = floor (((_hq get "stock") * CQ_childCarryShare) min CQ_childCarryMax);
_hq set ["stock", (_hq get "stock") - _carry];
_child set ["stockInit", _carry];
private _carryFuel = floor (((_hq get "fuel") * CQ_childCarryShare) min CQ_childCarryMax);
_hq set ["fuel", (_hq get "fuel") - _carryFuel];
_child set ["fuelInit", _carryFuel];
["Enemy HQ splitting", format ["HQ #%1: %2 soldiers leave with %7 ammo to found HQ #%3 near grid %4 (%5 m), %6 stay",
    _id, _n, _child get "id", mapGridPosition _site, round (_site distance2D _c), _total - _n, _carry]] call CQ_fnc_announce;

[_child, _col, _colVehs, _cmdG] spawn CQ_fnc_colonise;
