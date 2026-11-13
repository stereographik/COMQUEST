/*
    CQ_fnc_hostageStart  (server)
    [] call CQ_fnc_hostageStart;   -> true (a site is always found)
    The hostage event: a civilian radio technician held by CSAT in a village house between the
    base and an enemy HQ. Places the hostage (sitting, hands tied, captive) and CQ_hstGuards
    holding the house (CQ_hstGuardsIn at the windows, the rest covering the approaches), and
    marks the house. CQ_fnc_hostageTick runs the rest. State: CQ_hstState hashmap
      phase (held, clear, extract, flight, done), pos, house, hostage, guards, heli, lz, guer,
      freer (player who downloaded the firmware), t0, stuckT, lastD, logT
    House search: villages within CQ_hstSearchR of a point between the base and an HQ; nothing
    fits -> the radius grows by CQ_hstSearchStep and the limits relax (player gap, house size);
    in the end any house on the island far enough from players and the base.
*/
if (!isServer) exitWith { false };
call CQ_fnc_hostageEnd;   // previous one out

private _hqs = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
private _types = ["NameVillage", "NameCity", "NameCityCapital", "NameLocal"];
private _pick = {
    params ["_c", "_r", "_gap", "_minBp"];
    private _found = objNull;
    {
        private _lp = locationPosition _x;
        private _houses = (nearestObjects [_lp, ["House"], 250]) select {
            alive _x && { count ((_x buildingPos -1) select { _x isNotEqualTo [0, 0, 0] }) >= _minBp }
            && { !isObjectHidden _x } && { _x distance2D CQ_basePos > CQ_hstBaseGap }
            && { (allPlayers findIf { alive _x && { _x distance2D _lp < _gap } }) == -1 }
            && { ((values CQ_hqs) findIf { (_x get "state") in CQ_activeStates && { (_x get "pos") distance2D _lp < CQ_hstHqGap } }) == -1 }
        };
        if (_houses isNotEqualTo []) exitWith { _found = selectRandom _houses };
    } forEach ((nearestLocations [_c, _types, _r]) call BIS_fnc_arrayShuffle);
    _found
};

private _house = objNull;
private _r = CQ_hstSearchR;
private _round = 0;
while { isNull _house && { _r < worldSize * 1.5 } } do {
    private _relax = _round >= 2;
    private _gap = [CQ_hstPlayerGap, CQ_hstPlayerGap / 2] select _relax;
    private _minBp = [CQ_hstMinBp, 2] select _relax;
    for "_try" from 1 to 4 do {
        private _c = if (_hqs isEqualTo []) then {
            CQ_basePos getPos [4000 + random 3000, (CQ_basePos getDir (missionNamespace getVariable ["CQ_carrierPos", CQ_basePos getPos [5000, random 360]])) - 30 + random 60]
        } else {
            private _h = selectRandom _hqs;
            private _f = (CQ_hstSiteFrac select 0) + random ((CQ_hstSiteFrac select 1) - (CQ_hstSiteFrac select 0));
            CQ_basePos vectorAdd (((_h get "pos") vectorDiff CQ_basePos) vectorMultiply _f)
        };
        _house = [_c, _r, _gap, _minBp] call _pick;
        if (!isNull _house) exitWith {};
    };
    if (isNull _house) then {
        ["Hostage event: no house within %1 m, widening the search", [_r]] call CQ_fnc_log;
        _r = _r + CQ_hstSearchStep; _round = _round + 1;
    };
};
// last resort: any house on the island, away from the base and the players
if (isNull _house) then {
    private _all = (nearestObjects [[worldSize / 2, worldSize / 2, 0], ["House"], worldSize]) select {
        private _b = _x;
        alive _b && { count (_b buildingPos -1) >= 2 } && { _b distance2D CQ_basePos > CQ_hstBaseGap }
        && { (allPlayers findIf { alive _x && { _x distance2D _b < 400 } }) == -1 }
    };
    if (_all isNotEqualTo []) then { _house = selectRandom _all };
};
if (isNull _house) exitWith { ["Hostage event: no house anywhere (!)"] call CQ_fnc_log; false };

private _site = getPosATL _house;
private _bps = ((_house buildingPos -1) select { _x isNotEqualTo [0, 0, 0] }) call BIS_fnc_arrayShuffle;

// ---- the hostage: sitting, hands tied, captive (nobody shoots him while he is held)
private _cg = createGroup [civilian, true];
private _hp = _bps deleteAt 0;
private _h = _cg createUnit [CQ_hstCivClass, _hp, [], 0, "CAN_COLLIDE"];
_h setPosATL _hp;
_h setCaptive true;
removeAllWeapons _h;
_h disableAI "MOVE"; _h disableAI "ANIM"; _h disableAI "FSM";
_h setVariable ["CQ_hostage", true, true];
_h allowFleeing 0;
[_h, CQ_hstSitAnim] remoteExec ["switchMove", 0, _h];
// tougher than a plain civilian: a stray round should not end it
_h addEventHandler ["HandleDamage", { params ["_u", "_sel", "_dmg", "", "", "_idx"];
    private _old = if (_idx < 0) then { damage _u } else { _u getHitIndex _idx };
    _old + (_dmg - _old) * CQ_hstDamageMul }];
[_h,
    "<t color='#918C3B'>Download firmware</t>",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_connect_ca.paa",
    "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_connect_ca.paa",
    "_this distance _target < 3 && { alive _this } && { alive _target } && { _target getVariable ['CQ_hstClear', false] } && { !(_target getVariable ['CQ_hstFw', false]) }",
    "_caller distance _target < 3 && { alive _target }",
    {}, {},
    { params ["_target", "_caller"]; [_caller] remoteExec ["CQ_fnc_hostageFirmware", 2] },
    {}, [], CQ_hstFwTime, 10, true, false
] remoteExec ["BIS_fnc_holdActionAdd", 0, _h];

// ---- the guards: CQ_hstGuardsIn hold the house at its windows, the rest cover the approaches
private _gi = createGroup [east, true];
private _go = createGroup [east, true];
{
    private _in = _forEachIndex < CQ_hstGuardsIn && { _bps isNotEqualTo [] };
    private _p = if (_in) then { _bps deleteAt 0 } else { _site getPos [8 + random 10, random 360] };
    private _u = [_go, _gi] select _in;
    _u = _u createUnit [_x, _p, [], 0, "CAN_COLLIDE"];
    if (_in) then { _u setPosATL _p; _u disableAI "PATH"; _u setUnitPos "UP" };
    _u setSkill CQ_hstSkill;
    _u setVariable ["CQ_hstGuard", true];
} forEach CQ_hstGuards;
[(units _gi) + (units _go)] call CQ_fnc_unitPrep;
{
    _x setBehaviour "AWARE"; _x setCombatMode "RED"; _x enableDynamicSimulation false;
} forEach [_gi, _go];
_gi setGroupIdGlobal ["Hostage guards"];
if (units _go isNotEqualTo []) then { [_go, _site, 30] call BIS_fnc_taskDefend };

// ---- marker: the exact house
private _m = createMarker ["cq_hst", _site];
_m setMarkerType "mil_objective";
_m setMarkerColor "ColorCIV";
_m setMarkerText "Hostage";

CQ_hstState = createHashMapFromArray [
    ["phase", "held"], ["pos", _site], ["house", _house], ["hostage", _h],
    ["guards", (units _gi) + (units _go)], ["heli", objNull], ["lz", []], ["guer", grpNull],
    ["freer", objNull], ["t0", time], ["stuckT", time], ["lastD", 1e6], ["logT", 0]
];
CQ_hstLastT = time;
CQ_hstPos = _site; publicVariable "CQ_hstPos";
private _town = (nearestLocations [_site, _types, 2000]) param [0, locationNull];
["Hostage event: technician held at %1 (%2, %3 m from the base, %4 guards, %5 positions in %6, search radius %7 m)",
    [mapGridPosition _site, if (isNull _town) then { "no town" } else { text _town }, round (_site distance2D CQ_basePos), count CQ_hstGuards, count (_house buildingPos -1), typeOf _house, _r]] call CQ_fnc_log;
["hstStart", [mapGridPosition _site]] call CQ_fnc_say;
true
